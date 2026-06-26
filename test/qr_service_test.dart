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
        avatarEmoji: null,
      );
      final url = QrService.encodeContact(contact);
      final decoded = QrService.decodeContact(url);

      expect(decoded, isNotNull);
      expect(decoded!.avatarEmoji, isNull);
    });

    test('encodeChannel / decodeChannel roundtrip', () {
      final psk = Uint8List(32);
      for (int i = 0; i < 32; i++) psk[i] = i;

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
        avatarEmoji: null,
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
  });
}
