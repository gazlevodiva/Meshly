import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:meshly/services/crypto_service.dart';

void main() {
  final crypto = CryptoService.instance;

  Future<(Uint8List, Uint8List)> keyPair() => crypto.generateKeyPair();

  group('CryptoService pure crypto', () {
    test(
      'roundtrip: Alice encrypts to Bob, Bob decrypts (unicode + emoji)',
      () async {
        final (alicePriv, alicePub) = await keyPair();
        final (bobPriv, bobPub) = await keyPair();

        const plaintext = 'Привіт, world! 🔒🚀 – tab\ttest';

        final envelope = await crypto.encryptFor(
          myPrivateKey: alicePriv,
          peerPublicKey: bobPub,
          plaintext: plaintext,
        );

        final decrypted = await crypto.decryptFrom(
          myPrivateKey: bobPriv,
          senderPublicKey: alicePub,
          envelope: envelope,
        );

        expect(decrypted, plaintext);
      },
    );

    test('shared secret is symmetric: works Bob -> Alice too', () async {
      final (alicePriv, alicePub) = await keyPair();
      final (bobPriv, bobPub) = await keyPair();

      const plaintext = 'reply from bob';

      final envelope = await crypto.encryptFor(
        myPrivateKey: bobPriv,
        peerPublicKey: alicePub,
        plaintext: plaintext,
      );

      final decrypted = await crypto.decryptFrom(
        myPrivateKey: alicePriv,
        senderPublicKey: bobPub,
        envelope: envelope,
      );

      expect(decrypted, plaintext);
    });

    test('wrong key: Carol cannot decrypt Alice -> Bob envelope', () async {
      final (alicePriv, _) = await keyPair();
      final (_, bobPub) = await keyPair();
      final (carolPriv, _) = await keyPair();

      final envelope = await crypto.encryptFor(
        myPrivateKey: alicePriv,
        peerPublicKey: bobPub,
        plaintext: 'secret for bob only',
      );

      final decrypted = await crypto.decryptFrom(
        myPrivateKey: carolPriv,
        senderPublicKey: bobPub,
        envelope: envelope,
      );

      expect(decrypted, isNull);
    });

    test(
      'tamper: flipping a byte in the ciphertext breaks decryption',
      () async {
        final (alicePriv, alicePub) = await keyPair();
        final (bobPriv, bobPub) = await keyPair();

        final envelope = await crypto.encryptFor(
          myPrivateKey: alicePriv,
          peerPublicKey: bobPub,
          plaintext: 'do not tamper with me',
        );

        final tampered = Uint8List.fromList(envelope);
        final lastIndex = tampered.length - 1;
        tampered[lastIndex] = tampered[lastIndex] ^ 0xFF;

        final decrypted = await crypto.decryptFrom(
          myPrivateKey: bobPriv,
          senderPublicKey: alicePub,
          envelope: tampered,
        );

        expect(decrypted, isNull);
      },
    );

    test('tamper: flipping a byte in the nonce breaks decryption', () async {
      final (alicePriv, alicePub) = await keyPair();
      final (bobPriv, bobPub) = await keyPair();

      final envelope = await crypto.encryptFor(
        myPrivateKey: alicePriv,
        peerPublicKey: bobPub,
        plaintext: 'nonce tamper test',
      );

      final tampered = Uint8List.fromList(envelope);
      tampered[1] = tampered[1] ^ 0xFF; // first nonce byte

      final decrypted = await crypto.decryptFrom(
        myPrivateKey: bobPriv,
        senderPublicKey: alicePub,
        envelope: tampered,
      );

      expect(decrypted, isNull);
    });

    test('bad version byte returns null', () async {
      final (alicePriv, alicePub) = await keyPair();
      final (bobPriv, bobPub) = await keyPair();

      final envelope = await crypto.encryptFor(
        myPrivateKey: alicePriv,
        peerPublicKey: bobPub,
        plaintext: 'versioned message',
      );

      final tampered = Uint8List.fromList(envelope);
      tampered[0] = 0x02;

      final decrypted = await crypto.decryptFrom(
        myPrivateKey: bobPriv,
        senderPublicKey: alicePub,
        envelope: tampered,
      );

      expect(decrypted, isNull);
    });

    test('two encryptions of same text differ (random nonce) but both '
        'decrypt correctly', () async {
      final (alicePriv, alicePub) = await keyPair();
      final (bobPriv, bobPub) = await keyPair();

      const plaintext = 'same message twice';

      final envelope1 = await crypto.encryptFor(
        myPrivateKey: alicePriv,
        peerPublicKey: bobPub,
        plaintext: plaintext,
      );
      final envelope2 = await crypto.encryptFor(
        myPrivateKey: alicePriv,
        peerPublicKey: bobPub,
        plaintext: plaintext,
      );

      expect(envelope1, isNot(equals(envelope2)));

      final decrypted1 = await crypto.decryptFrom(
        myPrivateKey: bobPriv,
        senderPublicKey: alicePub,
        envelope: envelope1,
      );
      final decrypted2 = await crypto.decryptFrom(
        myPrivateKey: bobPriv,
        senderPublicKey: alicePub,
        envelope: envelope2,
      );

      expect(decrypted1, plaintext);
      expect(decrypted2, plaintext);
    });

    test('generateKeyPair returns 32-byte private and public keys', () async {
      final (priv, pub) = await keyPair();
      expect(priv.length, 32);
      expect(pub.length, 32);
    });

    test(
      'envelope format: version byte, 24-byte nonce, ciphertext+MAC',
      () async {
        final (alicePriv, _) = await keyPair();
        final (_, bobPub) = await keyPair();

        const plaintext = 'format check';
        final envelope = await crypto.encryptFor(
          myPrivateKey: alicePriv,
          peerPublicKey: bobPub,
          plaintext: plaintext,
        );

        expect(envelope[0], 0x01);
        // 1 (version) + 24 (nonce) + plaintext bytes + 16 (MAC)
        expect(envelope.length, 1 + 24 + plaintext.length + 16);
      },
    );
  });

  group('CryptoService channel crypto (Meshly-AEAD level 2)', () {
    Uint8List psk(int seed) =>
        Uint8List.fromList(List<int>.generate(32, (i) => (i + seed) & 0xFF));

    test('deriveChannelKey is deterministic for the same PSK', () async {
      final k1 = await crypto.deriveChannelKey(psk(1));
      final k2 = await crypto.deriveChannelKey(psk(1));
      expect(await k1.extractBytes(), equals(await k2.extractBytes()));
    });

    test('deriveChannelKey yields a 32-byte key', () async {
      final key = await crypto.deriveChannelKey(psk(1));
      expect((await key.extractBytes()).length, 32);
    });

    test('deriveChannelKey: different PSKs give different keys', () async {
      final k1 = await crypto.deriveChannelKey(psk(1));
      final k2 = await crypto.deriveChannelKey(psk(2));
      expect(
        await k1.extractBytes(),
        isNot(equals(await k2.extractBytes())),
      );
    });

    test('channel roundtrip: encrypt then decrypt with same PSK', () async {
      const plaintext = 'канал: Привіт! 🔒 group message';
      final envelope = await crypto.encryptForChannel(
        psk: psk(7),
        plaintext: plaintext,
      );
      final decrypted = await crypto.decryptForChannel(
        psk: psk(7),
        envelope: envelope,
      );
      expect(decrypted, plaintext);
    });

    test('channel envelope starts with version byte 0x01', () async {
      final envelope = await crypto.encryptForChannel(
        psk: psk(3),
        plaintext: 'version check',
      );
      expect(envelope[0], 0x01);
    });

    test('wrong PSK cannot decrypt the channel envelope', () async {
      final envelope = await crypto.encryptForChannel(
        psk: psk(1),
        plaintext: 'secret for channel members',
      );
      final decrypted = await crypto.decryptForChannel(
        psk: psk(9),
        envelope: envelope,
      );
      expect(decrypted, isNull);
    });

    test('tamper: flipping a ciphertext byte breaks decryption', () async {
      final envelope = await crypto.encryptForChannel(
        psk: psk(4),
        plaintext: 'do not tamper',
      );
      final tampered = Uint8List.fromList(envelope);
      final last = tampered.length - 1;
      tampered[last] = tampered[last] ^ 0xFF;
      final decrypted = await crypto.decryptForChannel(
        psk: psk(4),
        envelope: tampered,
      );
      expect(decrypted, isNull);
    });

    test('bad version byte returns null', () async {
      final envelope = await crypto.encryptForChannel(
        psk: psk(4),
        plaintext: 'versioned',
      );
      final tampered = Uint8List.fromList(envelope);
      tampered[0] = 0x02;
      final decrypted = await crypto.decryptForChannel(
        psk: psk(4),
        envelope: tampered,
      );
      expect(decrypted, isNull);
    });

    test('short/empty envelope returns null', () async {
      expect(
        await crypto.decryptForChannel(psk: psk(1), envelope: Uint8List(0)),
        isNull,
      );
      expect(
        await crypto.decryptForChannel(
          psk: psk(1),
          envelope: Uint8List.fromList([0x01, 0x00, 0x00]),
        ),
        isNull,
      );
    });

    test('two encryptions of same text differ but both decrypt', () async {
      const plaintext = 'same channel message twice';
      final e1 = await crypto.encryptForChannel(
        psk: psk(5),
        plaintext: plaintext,
      );
      final e2 = await crypto.encryptForChannel(
        psk: psk(5),
        plaintext: plaintext,
      );
      expect(e1, isNot(equals(e2)));
      expect(
        await crypto.decryptForChannel(psk: psk(5), envelope: e1),
        plaintext,
      );
      expect(
        await crypto.decryptForChannel(psk: psk(5), envelope: e2),
        plaintext,
      );
    });
  });
}
