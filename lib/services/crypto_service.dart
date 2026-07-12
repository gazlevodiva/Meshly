import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Encryption for Meshly messages — end-to-end for direct messages, and a
/// group AEAD for channels (see the channel section below). Both share one
/// symmetric core and envelope; only key derivation differs.
///
/// Identity: an X25519 keypair generated on first run. The private key lives
/// only in the OS keychain/keystore (`flutter_secure_storage`); the public
/// key is handed out via QR so contacts can encrypt messages to us.
///
/// Message encryption: static ECDH (X25519(myPrivate, peerPublic)) derives a
/// shared secret, then XChaCha20-Poly1305 AEAD with a fresh random 24-byte
/// nonce per message authenticates and encrypts the plaintext. No forward
/// secrecy (no ratchet) — a deliberate tradeoff for an unreliable, unordered
/// LoRa transport.
///
/// Envelope layout: `[version:1 = 0x01][nonce:24][ciphertext+MAC]`.
///
/// The crypto primitives below (`encryptFor`/`decryptFrom`/`generateKeyPair`)
/// are pure functions of key bytes so they can be unit-tested without
/// touching secure storage. `CryptoService` layers the identity (secure
/// storage-backed) on top.
class CryptoService {
  CryptoService._();
  static final instance = CryptoService._();

  static const _envelopeVersion = 0x01;
  static const _nonceLength = 24;

  static const _storageKeyPrivate = 'meshly_identity_priv_v1';

  final _x25519 = X25519();
  final _cipher = Xchacha20.poly1305Aead();
  final _secureStorage = const FlutterSecureStorage();

  Uint8List? _cachedPrivateKey;
  Uint8List? _cachedPublicKey;

  /// Ensures an identity keypair exists, generating and persisting one on
  /// first run. Safe to call multiple times (idempotent) and safe to call
  /// repeatedly across app starts — the private key is read back from
  /// secure storage rather than regenerated.
  Future<void> ensureIdentity() async {
    if (_cachedPrivateKey != null && _cachedPublicKey != null) {
      return;
    }

    final storedHex = await _secureStorage.read(key: _storageKeyPrivate);
    if (storedHex != null) {
      final privateKey = _hexDecode(storedHex);
      final publicKey = await _derivePublicKey(privateKey);
      _cachedPrivateKey = privateKey;
      _cachedPublicKey = publicKey;
      return;
    }

    final (privateKey, publicKey) = await generateKeyPair();
    await _secureStorage.write(
      key: _storageKeyPrivate,
      value: _hexEncode(privateKey),
    );
    _cachedPrivateKey = privateKey;
    _cachedPublicKey = publicKey;
  }

  /// This device's identity public key (32 bytes). Call [ensureIdentity]
  /// first; throws [StateError] if the identity has not been established.
  Uint8List myPublicKey() {
    final key = _cachedPublicKey;
    if (key == null) {
      throw StateError(
        'CryptoService.ensureIdentity() must complete before myPublicKey()',
      );
    }
    return key;
  }

  /// This device's identity private key. Internal — never leaves the device.
  Uint8List _myPrivateKey() {
    final key = _cachedPrivateKey;
    if (key == null) {
      throw StateError(
        'CryptoService.ensureIdentity() must complete before myPrivateKey()',
      );
    }
    return key;
  }

  /// Encrypts [plaintext] for the contact whose identity public key is
  /// [peerPublicKey], using this device's stored identity.
  Future<Uint8List> encryptToContact({
    required List<int> peerPublicKey,
    required String plaintext,
  }) {
    return encryptFor(
      myPrivateKey: _myPrivateKey(),
      peerPublicKey: peerPublicKey,
      plaintext: plaintext,
    );
  }

  /// Decrypts an [envelope] received from the contact whose identity public
  /// key is [senderPublicKey], using this device's stored identity. Returns
  /// null if the envelope cannot be authenticated (wrong key, corruption) or
  /// has an unsupported version.
  Future<String?> decryptFromContact({
    required List<int> senderPublicKey,
    required Uint8List envelope,
  }) {
    return decryptFrom(
      myPrivateKey: _myPrivateKey(),
      senderPublicKey: senderPublicKey,
      envelope: envelope,
    );
  }

  /// Resets cached identity state. Intended for tests; does not touch
  /// secure storage on its own (call together with clearing storage if a
  /// full reset is needed).
  void resetForTesting() {
    _cachedPrivateKey = null;
    _cachedPublicKey = null;
  }

  // ---------------------------------------------------------------------
  // Pure crypto — no secure storage, fully unit-testable.
  // ---------------------------------------------------------------------

  /// Generates a fresh X25519 identity keypair. Returns
  /// (privateKeyBytes, publicKeyBytes), both 32 bytes.
  Future<(Uint8List, Uint8List)> generateKeyPair() async {
    final keyPair = await _x25519.newKeyPair();
    final privateKey = await keyPair.extractPrivateKeyBytes();
    final publicKey = await keyPair.extractPublicKey();
    return (
      Uint8List.fromList(privateKey),
      Uint8List.fromList(publicKey.bytes),
    );
  }

  /// Encrypts [plaintext] from [myPrivateKey] to [peerPublicKey] via static
  /// X25519 ECDH + XChaCha20-Poly1305 with a random nonce. Returns the
  /// envelope: `[version:1][nonce:24][ciphertext+MAC]`.
  Future<Uint8List> encryptFor({
    required List<int> myPrivateKey,
    required List<int> peerPublicKey,
    required String plaintext,
  }) async {
    final sharedSecret = await _sharedSecretKey(
      privateKey: myPrivateKey,
      remotePublicKey: peerPublicKey,
    );
    return _encryptSymmetric(key: sharedSecret, plaintext: plaintext);
  }

  /// Decrypts an [envelope] produced by [encryptFor] using [myPrivateKey]
  /// and the sender's [senderPublicKey]. Returns null (never throws) on
  /// version mismatch, malformed envelope, or authentication failure.
  Future<String?> decryptFrom({
    required List<int> myPrivateKey,
    required List<int> senderPublicKey,
    required Uint8List envelope,
  }) async {
    final SecretKey sharedSecret;
    try {
      sharedSecret = await _sharedSecretKey(
        privateKey: myPrivateKey,
        remotePublicKey: senderPublicKey,
      );
    } on Exception {
      return null;
    }
    return _decryptSymmetric(key: sharedSecret, envelope: envelope);
  }

  // ---------------------------------------------------------------------
  // Channel encryption (Meshly-AEAD "level 2").
  //
  // Group channels reuse the same AEAD core as DMs, but the symmetric key is
  // derived from the channel PSK (already stored / shared via the channel QR)
  // rather than an ECDH shared secret. HKDF-SHA256 with a fixed info string
  // gives domain separation from the raw Meshtastic firmware PSK, so the
  // Meshly key never coincides with the key the firmware would use.
  //
  // Same envelope layout (`[0x01][nonce:24][ct+mac]`) and cipher as DMs.
  // Limitations: one shared key for the whole group — any member can forge a
  // message as any other (no in-group sender authentication), no forward
  // secrecy, and no member revocation without rotating the PSK.
  // ---------------------------------------------------------------------

  /// Derives the symmetric channel key from a channel [psk] via HKDF-SHA256.
  /// Deterministic: the same PSK always yields the same key.
  Future<SecretKey> deriveChannelKey(List<int> psk) async {
    final hkdf = Hkdf(hmac: Hmac.sha256(), outputLength: 32);
    return hkdf.deriveKey(
      secretKey: SecretKey(psk),
      info: utf8.encode('meshly-channel-v1'),
    );
  }

  /// Encrypts [plaintext] for the channel whose pre-shared key is [psk].
  /// Returns the envelope `[version:1][nonce:24][ciphertext+MAC]`.
  Future<Uint8List> encryptForChannel({
    required List<int> psk,
    required String plaintext,
  }) async {
    final key = await deriveChannelKey(psk);
    return _encryptSymmetric(key: key, plaintext: plaintext);
  }

  /// Decrypts a channel [envelope] using the channel's [psk]. Returns null
  /// (never throws) on version mismatch, malformed envelope, or auth failure.
  Future<String?> decryptForChannel({
    required List<int> psk,
    required Uint8List envelope,
  }) async {
    final key = await deriveChannelKey(psk);
    return _decryptSymmetric(key: key, envelope: envelope);
  }

  // ---------------------------------------------------------------------
  // Symmetric AEAD core — shared by DM (ECDH key) and channel (HKDF key).
  // ---------------------------------------------------------------------

  /// Encrypts [plaintext] under a symmetric [key] with a fresh random nonce.
  /// Returns the envelope `[version:1][nonce:24][ciphertext+MAC]`.
  Future<Uint8List> _encryptSymmetric({
    required SecretKey key,
    required String plaintext,
  }) async {
    final nonce = _randomNonce();
    final secretBox = await _cipher.encrypt(
      utf8.encode(plaintext),
      secretKey: key,
      nonce: nonce,
    );

    final cipherAndMac = secretBox.cipherText + secretBox.mac.bytes;
    final envelope = BytesBuilder()
      ..addByte(_envelopeVersion)
      ..add(nonce)
      ..add(cipherAndMac);
    return envelope.toBytes();
  }

  /// Decrypts an [envelope] under a symmetric [key]. Returns null (never
  /// throws) on version mismatch, short/malformed envelope, or auth failure.
  Future<String?> _decryptSymmetric({
    required SecretKey key,
    required Uint8List envelope,
  }) async {
    const macLength = 16;
    const minLength = 1 + _nonceLength + macLength;
    if (envelope.length < minLength) {
      return null;
    }
    if (envelope[0] != _envelopeVersion) {
      return null;
    }

    final nonce = envelope.sublist(1, 1 + _nonceLength);
    final rest = envelope.sublist(1 + _nonceLength);
    final macBytes = rest.sublist(rest.length - macLength);
    final cipherText = rest.sublist(0, rest.length - macLength);

    try {
      final secretBox = SecretBox(
        cipherText,
        nonce: nonce,
        mac: Mac(macBytes),
      );
      final clearTextBytes = await _cipher.decrypt(
        secretBox,
        secretKey: key,
      );
      return utf8.decode(clearTextBytes);
    } on Exception {
      // Any failure (auth failure, malformed input) -> unreadable message.
      return null;
    }
  }

  Future<SecretKey> _sharedSecretKey({
    required List<int> privateKey,
    required List<int> remotePublicKey,
  }) async {
    final keyPair = await _x25519.newKeyPairFromSeed(privateKey);
    final remote = SimplePublicKey(remotePublicKey, type: KeyPairType.x25519);
    return _x25519.sharedSecretKey(
      keyPair: keyPair,
      remotePublicKey: remote,
    );
  }

  Future<Uint8List> _derivePublicKey(List<int> privateKey) async {
    final keyPair = await _x25519.newKeyPairFromSeed(privateKey);
    final publicKey = await keyPair.extractPublicKey();
    return Uint8List.fromList(publicKey.bytes);
  }

  Uint8List _randomNonce() {
    final random = Random.secure();
    return Uint8List.fromList(
      List<int>.generate(_nonceLength, (_) => random.nextInt(256)),
    );
  }

  String _hexEncode(List<int> bytes) {
    final buffer = StringBuffer();
    for (final byte in bytes) {
      buffer.write(byte.toRadixString(16).padLeft(2, '0'));
    }
    return buffer.toString();
  }

  Uint8List _hexDecode(String hex) {
    final bytes = Uint8List(hex.length ~/ 2);
    for (var i = 0; i < bytes.length; i++) {
      bytes[i] = int.parse(hex.substring(i * 2, i * 2 + 2), radix: 16);
    }
    return bytes;
  }
}
