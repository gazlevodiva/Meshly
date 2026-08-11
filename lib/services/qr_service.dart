import 'dart:convert';
import 'dart:typed_data';

import 'package:meshly/models/contact.dart';
import 'package:meshly/models/mesh_channel.dart';

// URL схема:
// mesh://contact/!1f8e42c9?name=Dentro&emoji=👩
// mesh://channel/gazchannel?psk=base64&slot=2&emoji=🏕️

class QrService {
  static const _scheme = 'mesh';

  /// X25519 public keys are exactly this long. A QR claiming any other length
  /// is malformed or hostile: the crypto library answers a wrong-sized key
  /// with an [ArgumentError] — an [Error], not an [Exception] — which sails
  /// straight through the `on Exception` handlers on the radio and send
  /// paths and takes the whole loop down. Rejected here, at the only place
  /// key bytes enter the app.
  static const int _publicKeyLength = 32;

  /// Channel PSK sizes accepted by the AEAD key derivation (AES-128/AES-256
  /// sized secrets). Same reasoning as [_publicKeyLength].
  static const Set<int> _pskLengths = {16, 32};

  // ── Encode ────────────────────────────────────────────────

  static String encodeContact(Contact c, {String? myNodeId}) {
    final nodeId = myNodeId ?? c.nodeId;
    final params = {'name': c.displayName};
    if (c.avatarEmoji != null) params['emoji'] = c.avatarEmoji!;
    if (c.publicKey != null) params['pk'] = base64Url.encode(c.publicKey!);
    return Uri(
      scheme: _scheme,
      host: 'contact',
      path: '/$nodeId',
      queryParameters: params,
    ).toString();
  }

  static String encodeChannel(MeshChannel ch) {
    return Uri(
      scheme: _scheme,
      host: 'channel',
      path: '/${Uri.encodeComponent(ch.name)}',
      queryParameters: {
        'psk': base64Url.encode(ch.psk),
        'slot': ch.slotIndex.toString(),
        if (ch.avatarEmoji != null) 'emoji': ch.avatarEmoji,
      },
    ).toString();
  }

  // ── Decode ────────────────────────────────────────────────

  static ContactQrData? decodeContact(String raw) {
    try {
      final uri = Uri.parse(raw);
      if (uri.scheme != _scheme || uri.host != 'contact') return null;
      final nodeId = uri.pathSegments.isNotEmpty
          ? uri.pathSegments.first
          : null;
      if (nodeId == null || !nodeId.startsWith('!')) return null;
      final pkStr = uri.queryParameters['pk'];
      Uint8List? publicKey;
      if (pkStr != null) {
        publicKey = base64Url.decode(pkStr);
        // A QR that carries a key at all must carry a usable one: silently
        // dropping just the key would store the contact as "no key yet" and
        // hide a corrupted/hostile code behind a confusing UX.
        if (publicKey.length != _publicKeyLength) return null;
      }
      return ContactQrData(
        nodeId: nodeId,
        displayName: uri.queryParameters['name'] ?? nodeId,
        avatarEmoji: uri.queryParameters['emoji'],
        publicKey: publicKey,
      );
      // Also catches Error: base64Url.decode raises FormatException, but the
      // length guard above is the only thing standing between a QR and the
      // crypto library's ArgumentError, so nothing here may escape.
      // ignore: avoid_catches_without_on_clauses
    } catch (_) {
      return null;
    }
  }

  static ChannelQrData? decodeChannel(String raw) {
    try {
      final uri = Uri.parse(raw);
      if (uri.scheme != _scheme || uri.host != 'channel') return null;
      final name = uri.pathSegments.isNotEmpty ? uri.pathSegments.first : null;
      final pskStr = uri.queryParameters['psk'];
      final slotStr = uri.queryParameters['slot'];
      if (name == null || pskStr == null || slotStr == null) return null;
      final slotIndex = int.tryParse(slotStr);
      if (slotIndex == null || slotIndex < 1 || slotIndex > 7) return null;
      final psk = base64Url.decode(pskStr);
      if (!_pskLengths.contains(psk.length)) return null;
      return ChannelQrData(
        name: name,
        psk: psk,
        slotIndex: slotIndex,
        avatarEmoji: uri.queryParameters['emoji'],
      );
      // See decodeContact: nothing from a QR may escape, Error included.
      // ignore: avoid_catches_without_on_clauses
    } catch (_) {
      return null;
    }
  }

  // Определяем тип QR по содержимому
  static QrType? detectType(String raw) {
    try {
      final uri = Uri.parse(raw);
      if (uri.scheme != _scheme) return null;
      if (uri.host == 'contact') return QrType.contact;
      if (uri.host == 'channel') return QrType.channel;
      return null;
    } on Exception catch (_) {
      return null;
    }
  }
}

enum QrType { contact, channel }

class ContactQrData {
  const ContactQrData({
    required this.nodeId,
    required this.displayName,
    this.avatarEmoji,
    this.publicKey,
  });

  final String nodeId;
  final String displayName;
  final String? avatarEmoji;
  final Uint8List? publicKey;
}

class ChannelQrData {
  const ChannelQrData({
    required this.name,
    required this.psk,
    required this.slotIndex,
    this.avatarEmoji,
  });

  final String name;
  final Uint8List psk;
  final int slotIndex;
  final String? avatarEmoji;
}
