import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:meshly/models/contact.dart';
import 'package:meshly/models/mesh_channel.dart';
import 'package:meshly/services/qr_service.dart';

void main() {
  group('QrService', () {
    test('encodeContact / decodeContact roundtrip with cyrillic name', () {
      final contact = Contact(
        nodeId: '!1f8e42c9',
        displayName: 'Мама',
        avatarEmoji: '🏕️',
      );
      final url = QrService.encodeContact(contact);
      final decoded = QrService.decodeContact(url);

      expect(decoded, isNotNull);
      expect(decoded!.nodeId, equals('!1f8e42c9'));
      expect(decoded.displayName, equals('Мама'));
      expect(decoded.avatarEmoji, equals('🏕️'));
    });

    test('encodeContact / decodeContact roundtrip: avatarEmoji = null', () {
      final contact = Contact(
        nodeId: '!aabbccdd',
        displayName: 'Папа',
      );
      final url = QrService.encodeContact(contact);
      final decoded = QrService.decodeContact(url);

      expect(decoded, isNotNull);
      expect(decoded!.avatarEmoji, isNull);
    });

    test('encodeContact / decodeContact roundtrip with publicKey', () {
      final pk = Uint8List.fromList(List<int>.generate(32, (i) => i));
      final contact = Contact(
        nodeId: '!1f8e42c9',
        displayName: 'Мама',
        publicKey: pk,
      );
      final url = QrService.encodeContact(contact);
      expect(url, contains('pk='));
      final decoded = QrService.decodeContact(url);

      expect(decoded, isNotNull);
      expect(decoded!.publicKey, equals(pk));
    });

    test('encodeContact without publicKey omits pk param, decodes to null', () {
      final contact = Contact(
        nodeId: '!aabbccdd',
        displayName: 'Папа',
      );
      final url = QrService.encodeContact(contact);
      expect(url, isNot(contains('pk=')));
      final decoded = QrService.decodeContact(url);

      expect(decoded, isNotNull);
      expect(decoded!.publicKey, isNull);
    });

    test(
      'decodeContact: old-style URL without pk decodes with publicKey null',
      () {
        final decoded = QrService.decodeContact(
          'mesh://contact/!1f8e42c9?name=Dentro&emoji=%F0%9F%91%A9',
        );

        expect(decoded, isNotNull);
        expect(decoded!.publicKey, isNull);
        expect(decoded.displayName, equals('Dentro'));
      },
    );

    test('encodeChannel / decodeChannel roundtrip', () {
      final psk = Uint8List(32);
      for (var i = 0; i < 32; i++) {
        psk[i] = i;
      }

      final channel = MeshChannel(
        id: 'test-uuid',
        name: 'семья',
        psk: psk,
        avatarEmoji: '🏠',
      );
      final url = QrService.encodeChannel(channel);
      final decoded = QrService.decodeChannel(url);

      expect(decoded, isNotNull);
      expect(decoded!.name, equals('семья'));
      // Printing `slot=1` is intentional backward compatibility with old
      // versions (see the sprint report), independent of the conversation:
      // the MeshChannel model no longer stores a slot at all, and the
      // decoder doesn't parse this field.
      expect(url, contains('slot=1'));
      expect(decoded.avatarEmoji, equals('🏠'));
      expect(decoded.psk, equals(psk));
    });

    test('encodeChannel / decodeChannel: avatarEmoji = null', () {
      final psk = Uint8List(32);
      final channel = MeshChannel(
        id: 'test-uuid-2',
        name: 'gazchannel',
        psk: psk,
      );
      final url = QrService.encodeChannel(channel);
      final decoded = QrService.decodeChannel(url);

      expect(decoded, isNotNull);
      expect(decoded!.avatarEmoji, isNull);
    });

    test('detectType: contact URL returns QrType.contact', () {
      final contact = Contact(nodeId: '!12345678', displayName: 'Test');
      final url = QrService.encodeContact(contact);
      expect(QrService.detectType(url), equals(QrType.contact));
    });

    test('detectType: channel URL returns QrType.channel', () {
      final channel = MeshChannel(
        id: 'x',
        name: 'ch',
        psk: Uint8List(32),
      );
      final url = QrService.encodeChannel(channel);
      expect(QrService.detectType(url), equals(QrType.channel));
    });

    test('detectType: garbage returns null', () {
      expect(QrService.detectType('https://example.com/random'), isNull);
      expect(QrService.detectType('not-a-url'), isNull);
      expect(QrService.detectType(''), isNull);
    });

    test('decodeContact returns null for invalid URL', () {
      expect(
        QrService.decodeContact('mesh://channel/test?psk=abc&slot=1'),
        isNull,
      );
      expect(QrService.decodeContact('https://example.com'), isNull);
    });

    test('decodeChannel returns null for contact URL', () {
      expect(
        QrService.decodeChannel('mesh://contact/!12345678?name=Test'),
        isNull,
      );
    });

    // ── Conversation slot: transition period ──────────────────────
    //
    // The slot is decoupled from the hardware channel (see the sprint
    // report) and no longer affects anything. Old codes carry `slot=<N>` —
    // they are read as before; new codes don't carry the field at all —
    // this used to reject the code entirely, now `slot` is simply optional.

    test('decodeChannel accepts any slot value (no longer validated)', () {
      final validPsk = base64Url.encode(Uint8List(16));
      for (final slot in ['0', '8', '99', 'abc']) {
        final decoded = QrService.decodeChannel(
          'mesh://channel/test?psk=$validPsk&slot=$slot',
        );
        expect(decoded, isNotNull, reason: 'slot=$slot must decode');
      }
    });

    test('decodeChannel accepts an old-style QR carrying slot=1..7', () {
      final validPsk = base64Url.encode(Uint8List(16));
      for (final slot in [1, 7]) {
        final decoded = QrService.decodeChannel(
          'mesh://channel/test?psk=$validPsk&slot=$slot',
        );
        expect(decoded, isNotNull);
      }
    });

    test('decodeChannel accepts a new-style QR without slot at all', () {
      final validPsk = base64Url.encode(Uint8List(16));
      final decoded = QrService.decodeChannel(
        'mesh://channel/test?psk=$validPsk',
      );
      expect(decoded, isNotNull);
    });

    // ── Key material length (crash guard) ─────────────────────
    //
    // A wrong-sized X25519 key makes the crypto library throw an
    // ArgumentError — an Error, not an Exception — which the `on Exception`
    // handlers on the radio and send paths let through, killing the drain
    // loop. The QR decoder is the only choke point where key bytes enter, so
    // the length check lives here.
    String contactUrl(String pkBase64) =>
        'mesh://contact/!1f8e42c9?name=Eve&pk=$pkBase64';

    test('decodeContact rejects a public key shorter than 32 bytes', () {
      final short = base64Url.encode(Uint8List(16));
      expect(QrService.decodeContact(contactUrl(short)), isNull);
    });

    test('decodeContact rejects a public key longer than 32 bytes', () {
      final long = base64Url.encode(Uint8List(64));
      expect(QrService.decodeContact(contactUrl(long)), isNull);
    });

    test('decodeContact rejects an empty pk param', () {
      expect(QrService.decodeContact(contactUrl('')), isNull);
    });

    test('decodeContact rejects a pk that is not valid base64url', () {
      expect(
        QrService.decodeContact(contactUrl('!!!not-base64!!!')),
        isNull,
      );
    });

    test('decodeContact still accepts an exactly 32-byte key', () {
      final pk = Uint8List.fromList(List<int>.generate(32, (i) => i));
      final decoded = QrService.decodeContact(
        contactUrl(base64Url.encode(pk)),
      );
      expect(decoded, isNotNull);
      expect(decoded!.publicKey, equals(pk));
    });

    String channelUrl(String pskBase64) =>
        'mesh://channel/ch?psk=$pskBase64&slot=2';

    test('decodeChannel rejects a PSK of an unsupported length', () {
      expect(
        QrService.decodeChannel(channelUrl(base64Url.encode(Uint8List(7)))),
        isNull,
      );
      expect(
        QrService.decodeChannel(channelUrl(base64Url.encode(Uint8List(64)))),
        isNull,
      );
      expect(QrService.decodeChannel(channelUrl('')), isNull);
    });

    test('decodeChannel accepts 16- and 32-byte PSKs', () {
      expect(
        QrService.decodeChannel(
          channelUrl(base64Url.encode(Uint8List(16))),
        )?.psk,
        hasLength(16),
      );
      expect(
        QrService.decodeChannel(
          channelUrl(base64Url.encode(Uint8List(32))),
        )?.psk,
        hasLength(32),
      );
    });
  });
}
