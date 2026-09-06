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

    // ── Кэш выведенных ключей ────────────────────────────────
    //
    // Кэш ключей keyed по самому PSK (см. crypto_service.dart), а не по id
    // беседы: главное свойство, которое он обязан сохранять при этом — не
    // путать ключи разных PSK и не отдавать протухший ключ после смены PSK.
    group('deriveChannelKey cache', () {
      test(
        'two derivations with the same PSK return an equal key (cache hit)',
        () async {
          final k1 = await crypto.deriveChannelKey(psk(11));
          final k2 = await crypto.deriveChannelKey(psk(11));
          expect(await k1.extractBytes(), equals(await k2.extractBytes()));
        },
      );

      test(
        'different PSKs never share a cached key, however many times each '
        'is requested',
        () async {
          for (var i = 0; i < 3; i++) {
            final kA = await crypto.deriveChannelKey(psk(21));
            final kB = await crypto.deriveChannelKey(psk(22));
            expect(
              await kA.extractBytes(),
              isNot(equals(await kB.extractBytes())),
            );
          }
        },
      );

      test(
        'channel key "rotation": decrypting after a PSK change uses the new '
        'key, not a cached old one keyed by the same conversation',
        () async {
          final oldPsk = psk(31);
          final newPsk = psk(32);

          // Разогреваем кэш старым PSK — как будто беседа уже получала
          // сообщения до смены ключа.
          await crypto.deriveChannelKey(oldPsk);

          final envelope = await crypto.encryptForChannel(
            psk: newPsk,
            plaintext: 'сообщение после смены ключа',
          );

          // Если бы кэш был keyed по id беседы, а не по PSK, здесь могла бы
          // подставиться старая запись — расшифровка тихо сломалась бы.
          final decrypted = await crypto.decryptForChannel(
            psk: newPsk,
            envelope: envelope,
          );
          expect(decrypted, equals('сообщение после смены ключа'));

          // Старый ключ по-прежнему не читает новые сообщения.
          final withOldKey = await crypto.decryptForChannel(
            psk: oldPsk,
            envelope: envelope,
          );
          expect(withOldKey, isNull);
        },
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

  // ── Key-mismatch service packet [0x02] ──────────────────────
  group('key mismatch notice', () {
    test('payload is exactly one byte 0x02 — no key material', () {
      final payload = keyMismatchNoticePayload();
      expect(payload, hasLength(1));
      expect(payload.single, equals(kKeyMismatchNoticeVersion));
      expect(kKeyMismatchNoticeVersion, isNot(equals(kMessageEnvelopeVersion)));
    });

    test('isKeyMismatchNotice recognizes it and nothing else', () async {
      expect(isKeyMismatchNotice(keyMismatchNoticePayload()), isTrue);
      expect(isKeyMismatchNotice(null), isFalse);
      expect(isKeyMismatchNotice(<int>[]), isFalse);
      // A regular message envelope starts with 0x01 and is far longer.
      expect(isKeyMismatchNotice(const [kMessageEnvelopeVersion]), isFalse);
      expect(isKeyMismatchNotice(const [0x02, 0x02]), isFalse);

      final (alicePriv, _) = await keyPair();
      final (_, bobPub) = await keyPair();
      final envelope = await crypto.encryptFor(
        myPrivateKey: alicePriv,
        peerPublicKey: bobPub,
        plaintext: 'обычное сообщение',
      );
      expect(isKeyMismatchNotice(envelope), isFalse);
    });

    test('the notice never decrypts as a message (DM or channel)', () async {
      final (alicePriv, alicePub) = await keyPair();
      final (bobPriv, _) = await keyPair();
      final notice = keyMismatchNoticePayload();

      expect(
        await crypto.decryptFrom(
          myPrivateKey: bobPriv,
          senderPublicKey: alicePub,
          envelope: notice,
        ),
        isNull,
      );
      expect(
        await crypto.decryptForChannel(
          psk: List<int>.filled(32, 7),
          envelope: notice,
        ),
        isNull,
      );
      // Even a version-0x02 payload padded to a plausible envelope length
      // stays unreadable: the version byte is checked, not just the size.
      final padded = Uint8List.fromList([
        kKeyMismatchNoticeVersion,
        ...List<int>.filled(40, 0),
      ]);
      expect(
        await crypto.decryptFrom(
          myPrivateKey: alicePriv,
          senderPublicKey: alicePub,
          envelope: padded,
        ),
        isNull,
      );
    });
  });

  group('key verify handshake (0x03 ping / 0x04 ack)', () {
    tearDown(crypto.resetForTesting);

    // Builds a ping/ack as [me] addressed to [peerPub].
    Future<Uint8List> buildAs(
      (Uint8List, Uint8List) me,
      Uint8List peerPub, {
      required bool ping,
    }) async {
      crypto.setIdentityForTesting(me.$1, me.$2);
      return ping
          ? crypto.buildKeyVerifyPing(peerPub)
          : crypto.buildKeyVerifyAck(peerPub);
    }

    Future<bool> verifyAs(
      (Uint8List, Uint8List) me,
      Uint8List senderPub,
      Uint8List payload,
    ) {
      crypto.setIdentityForTesting(me.$1, me.$2);
      return crypto.verifyControlPacket(
        senderPublicKey: senderPub,
        payload: payload,
      );
    }

    test(
      'ping and ack carry their version byte over a real envelope',
      () async {
        final alice = await keyPair();
        final bob = await keyPair();

        final ping = await buildAs(alice, bob.$2, ping: true);
        final ack = await buildAs(alice, bob.$2, ping: false);

        expect(ping.first, equals(kKeyVerifyPingVersion));
        expect(ack.first, equals(kKeyVerifyAckVersion));
        // [version][0x01][nonce:24][ct+mac] — the payload underneath is a
        // regular envelope, so it starts with the message version byte.
        expect(ping[1], equals(kMessageEnvelopeVersion));
        expect(ack[1], equals(kMessageEnvelopeVersion));
        expect(ping.length, greaterThan(1 + 1 + 24 + 16));
      },
    );

    test('recognisers tell ping, ack and the notice apart', () async {
      final alice = await keyPair();
      final bob = await keyPair();
      final ping = await buildAs(alice, bob.$2, ping: true);
      final ack = await buildAs(alice, bob.$2, ping: false);

      expect(isKeyVerifyPing(ping), isTrue);
      expect(isKeyVerifyAck(ping), isFalse);
      expect(isKeyVerifyAck(ack), isTrue);
      expect(isKeyVerifyPing(ack), isFalse);

      // Neither is the [0x02] notice, and the notice is neither of them.
      expect(isKeyMismatchNotice(ping), isFalse);
      expect(isKeyMismatchNotice(ack), isFalse);
      expect(isKeyVerifyPing(keyMismatchNoticePayload()), isFalse);
      expect(isKeyVerifyAck(keyMismatchNoticePayload()), isFalse);

      // Nothing else passes: null, empty, a bare version byte, a message.
      expect(isKeyVerifyPing(null), isFalse);
      expect(isKeyVerifyPing(<int>[]), isFalse);
      expect(isKeyVerifyPing(const [kKeyVerifyPingVersion]), isFalse);
      expect(isKeyVerifyAck(const [kKeyVerifyAckVersion]), isFalse);
      expect(isKeyVerifyPing(const [kMessageEnvelopeVersion, 0x00]), isFalse);
    });

    test('verifyControlPacket: true for the matching keypair', () async {
      final alice = await keyPair();
      final bob = await keyPair();

      final ping = await buildAs(alice, bob.$2, ping: true);
      expect(await verifyAs(bob, alice.$2, ping), isTrue);

      final ack = await buildAs(bob, alice.$2, ping: false);
      expect(await verifyAs(alice, bob.$2, ack), isTrue);
    });

    test('verifyControlPacket: false for a stranger key', () async {
      final alice = await keyPair();
      final bob = await keyPair();
      final mallory = await keyPair();

      final ping = await buildAs(alice, bob.$2, ping: true);
      // Right recipient, wrong claimed sender.
      expect(await verifyAs(bob, mallory.$2, ping), isFalse);
      // Right sender, wrong recipient (peer reinstalled → new identity).
      expect(await verifyAs(mallory, alice.$2, ping), isFalse);
    });

    test('verifyControlPacket: false for corrupted or stunted bytes', () async {
      final alice = await keyPair();
      final bob = await keyPair();
      final ping = await buildAs(alice, bob.$2, ping: true);

      final flipped = Uint8List.fromList(ping)
        ..[ping.length - 1] ^= 0xFF; // break the MAC
      expect(await verifyAs(bob, alice.$2, flipped), isFalse);

      // Truncated, empty, bare version byte, and the [0x02] notice.
      expect(
        await verifyAs(bob, alice.$2, Uint8List.sublistView(ping, 0, 10)),
        isFalse,
      );
      expect(await verifyAs(bob, alice.$2, Uint8List(0)), isFalse);
      expect(
        await verifyAs(
          bob,
          alice.$2,
          Uint8List.fromList([kKeyVerifyPingVersion]),
        ),
        isFalse,
      );
      expect(
        await verifyAs(bob, alice.$2, keyMismatchNoticePayload()),
        isFalse,
      );

      // A regular message is not a control packet even if it authenticates.
      crypto.setIdentityForTesting(alice.$1, alice.$2);
      final message = await crypto.encryptToContact(
        peerPublicKey: bob.$2,
        plaintext: 'привет',
      );
      expect(await verifyAs(bob, alice.$2, message), isFalse);
    });

    test('ping and ack carry DIFFERENT plaintexts', () async {
      final alice = await keyPair();
      final bob = await keyPair();
      final ping = await buildAs(alice, bob.$2, ping: true);
      final ack = await buildAs(alice, bob.$2, ping: false);

      crypto.setIdentityForTesting(bob.$1, bob.$2);
      Future<String?> open(Uint8List p) => crypto.decryptFromContact(
        senderPublicKey: alice.$2,
        envelope: Uint8List.sublistView(p, 1),
      );

      expect(await open(ping), equals(kKeyVerifyPingPlaintext));
      expect(await open(ack), equals(kKeyVerifyAckPlaintext));
      expect(kKeyVerifyPingPlaintext, isNot(equals(kKeyVerifyAckPlaintext)));
    });

    // Regression: verifyControlPacket used to accept anything that merely
    // decrypted, so any ciphertext ever produced by the contact — an old
    // message, an ack recorded off the air — counted as fresh proof once
    // someone prepended 0x03.
    test('an arbitrary ciphertext under a 0x03 byte proves nothing', () async {
      final alice = await keyPair();
      final bob = await keyPair();

      crypto.setIdentityForTesting(alice.$1, alice.$2);
      final message = await crypto.encryptToContact(
        peerPublicKey: bob.$2,
        plaintext: 'привет, это обычное сообщение',
      );
      final forged = Uint8List.fromList([kKeyVerifyPingVersion, ...message]);

      // It decrypts perfectly — and is still refused.
      crypto.setIdentityForTesting(bob.$1, bob.$2);
      expect(
        await crypto.decryptFromContact(
          senderPublicKey: alice.$2,
          envelope: Uint8List.sublistView(forged, 1),
        ),
        isNotNull,
      );
      expect(await verifyAs(bob, alice.$2, forged), isFalse);
    });

    test('swapping the 0x03/0x04 byte does not pass', () async {
      final alice = await keyPair();
      final bob = await keyPair();
      final ping = await buildAs(alice, bob.$2, ping: true);
      final ack = await buildAs(alice, bob.$2, ping: false);

      final pingAsAck = Uint8List.fromList(ping)..[0] = kKeyVerifyAckVersion;
      final ackAsPing = Uint8List.fromList(ack)..[0] = kKeyVerifyPingVersion;

      expect(await verifyAs(bob, alice.$2, pingAsAck), isFalse);
      expect(await verifyAs(bob, alice.$2, ackAsPing), isFalse);
      // The untouched originals still pass, so the check above is not
      // rejecting them for some unrelated reason.
      expect(await verifyAs(bob, alice.$2, ping), isTrue);
      expect(await verifyAs(bob, alice.$2, ack), isTrue);
    });

    test('ping/ack never decrypt as a regular message', () async {
      final alice = await keyPair();
      final bob = await keyPair();
      final ping = await buildAs(alice, bob.$2, ping: true);
      final ack = await buildAs(alice, bob.$2, ping: false);

      for (final payload in [ping, ack]) {
        expect(
          await crypto.decryptFrom(
            myPrivateKey: bob.$1,
            senderPublicKey: alice.$2,
            envelope: payload,
          ),
          isNull,
        );
        expect(
          await crypto.decryptForChannel(
            psk: List<int>.filled(32, 7),
            envelope: payload,
          ),
          isNull,
        );
      }
    });
  });
}
