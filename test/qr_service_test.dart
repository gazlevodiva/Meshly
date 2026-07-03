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

    test('encodeChannel / decodeChannel roundtrip', () {
      final psk = Uint8List(32);
      for (var i = 0; i < 32; i++) {
        psk[i] = i;
      }

      final channel = MeshChannel(
        id: 'test-uuid',
        name: 'семья',
        psk: psk,
        slotIndex: 2,
        avatarEmoji: '🏠',
      );
      final url = QrService.encodeChannel(channel);
      final decoded = QrService.decodeChannel(url);

      expect(decoded, isNotNull);
      expect(decoded!.name, equals('семья'));
      expect(decoded.slotIndex, equals(2));
      expect(decoded.avatarEmoji, equals('🏠'));
      expect(decoded.psk, equals(psk));
    });

    test('encodeChannel / decodeChannel: avatarEmoji = null', () {
      final psk = Uint8List(32);
      final channel = MeshChannel(
        id: 'test-uuid-2',
        name: 'gazchannel',
        psk: psk,
        slotIndex: 3,
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
        slotIndex: 1,
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
      expect(QrService.decodeContact('mesh://channel/test?psk=abc&slot=1'), isNull);
      expect(QrService.decodeContact('https://example.com'), isNull);
    });

    test('decodeChannel returns null for contact URL', () {
      expect(
        QrService.decodeChannel('mesh://contact/!12345678?name=Test'),
        isNull,
      );
    });

    // ── Slot bounds validation ─────────────────────────────

    test('decodeChannel returns null for slot=0 (reserved)', () {
      expect(
        QrService.decodeChannel('mesh://channel/test?psk=AAAA&slot=0'),
        isNull,
      );
    });

    test('decodeChannel returns null for slot=8 (out of range)', () {
      expect(
        QrService.decodeChannel('mesh://channel/test?psk=AAAA&slot=8'),
        isNull,
      );
    });

    test('decodeChannel returns null for slot=99 (malicious QR)', () {
      expect(
        QrService.decodeChannel('mesh://channel/test?psk=AAAA&slot=99'),
        isNull,
      );
    });

    test('decodeChannel returns null for non-numeric slot', () {
      expect(
        QrService.decodeChannel('mesh://channel/test?psk=AAAA&slot=abc'),
        isNull,
      );
    });

    test('decodeChannel accepts valid slot boundaries 1 and 7', () {
      final psk = Uint8List(32);
      final channel = MeshChannel(id: 'x', name: 'ch', psk: psk, slotIndex: 1);
      final url1 = QrService.encodeChannel(channel);
      expect(QrService.decodeChannel(url1)?.slotIndex, equals(1));

      final channel7 =
          MeshChannel(id: 'y', name: 'ch7', psk: psk, slotIndex: 7);
      final url7 = QrService.encodeChannel(channel7);
      expect(QrService.decodeChannel(url7)?.slotIndex, equals(7));
    });
  });
}
