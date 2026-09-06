import 'package:flutter_test/flutter_test.dart';
import 'package:meshly/models/contact.dart';
import 'package:meshly/models/conversation.dart';
import 'package:meshly/models/message.dart';

void main() {
  group('Conversation secure-chat state', () {
    test('a new conversation is healthy in both directions', () {
      final conv = Conversation.dm('!aabbccdd');
      expect(conv.iCanReadPeer, isTrue);
      expect(conv.peerCanReadUs, isTrue);
      expect(conv.secureOk, isTrue);
    });

    test('secureOk needs BOTH directions', () {
      final conv = Conversation.dm('!aabbccdd')..iCanReadPeer = false;
      expect(conv.secureOk, isFalse);
      conv
        ..iCanReadPeer = true
        ..peerCanReadUs = false;
      expect(conv.secureOk, isFalse);
      conv
        ..iCanReadPeer = true
        ..peerCanReadUs = true;
      expect(conv.secureOk, isTrue);
    });

    test('both flags survive a JSON round-trip', () {
      final conv = Conversation.dm('!aabbccdd')
        ..iCanReadPeer = false
        ..peerCanReadUs = true;
      final back = Conversation.fromJson(conv.toJson());
      expect(back.iCanReadPeer, isFalse);
      expect(back.peerCanReadUs, isTrue);
      expect(back.secureOk, isFalse);
    });

    test('legacy JSON without the flags decodes as healthy', () {
      // Conversations written by pre-v9 builds carry neither key; a healthy
      // default is right because the very first failure re-flips them.
      final back = Conversation.fromJson({
        'id': 'dm_!aabbccdd',
        'type': 'dm',
        'peerId': '!aabbccdd',
        'unreadCount': 0,
        'updatedAt': DateTime(2024).toIso8601String(),
      });
      expect(back.secureOk, isTrue);
    });
  });

  group('Message.copyWith', () {
    final original = Message(
      meshId: 1,
      fromNodeId: '!aabbccdd',
      conversationId: 'dm_!aabbccdd',
      text: 'hello',
      time: DateTime(2024),
      isMe: false,
    );

    test('copyWith returns a new object', () {
      final copy = original.copyWith();
      expect(identical(original, copy), isFalse);
    });

    test('copyWith preserves all fields when no overrides', () {
      final copy = original.copyWith();
      expect(copy.meshId, equals(original.meshId));
      expect(copy.fromNodeId, equals(original.fromNodeId));
      expect(copy.conversationId, equals(original.conversationId));
      expect(copy.text, equals(original.text));
      expect(copy.time, equals(original.time));
      expect(copy.isMe, equals(original.isMe));
      expect(copy.status, equals(original.status));
    });

    test('copyWith overrides status without touching original', () {
      final copy = original.copyWith(status: MessageStatus.acked);
      expect(copy.status, equals(MessageStatus.acked));
      expect(original.status, equals(MessageStatus.sending));
    });

    test('mutating copy status does not affect original', () {
      final copy = original.copyWith()..status = MessageStatus.failed;
      expect(copy.status, equals(MessageStatus.failed));
      expect(original.status, equals(MessageStatus.sending));
    });

    test('copyWith preserves eventKind', () {
      final event = Message.systemEvent(
        kind: SystemEventKind.joined,
        announcedName: 'Boris',
        fromNodeId: '!aabbccdd',
        conversationId: 'ch_x',
        time: DateTime(2024),
        isMe: false,
      );
      final copy = event.copyWith(status: MessageStatus.failed);
      expect(copy.eventKind, equals(SystemEventKind.joined));
      expect(copy.isSystemEvent, isTrue);
      expect(original.isSystemEvent, isFalse);
    });
  });

  group('Message.systemEvent / isSystemEvent', () {
    test('systemEvent is always acked and stores the name in text', () {
      final event = Message.systemEvent(
        kind: SystemEventKind.left,
        announcedName: 'Алиса',
        fromNodeId: '!aabbccdd',
        conversationId: 'ch_x',
        time: DateTime(2024),
        isMe: false,
      );
      expect(event.status, equals(MessageStatus.acked));
      expect(event.text, equals('Алиса'));
      expect(event.eventKind, equals(SystemEventKind.left));
      expect(event.isSystemEvent, isTrue);
    });

    test('an ordinary Message has no eventKind', () {
      final msg = Message(
        meshId: 1,
        fromNodeId: '!aabbccdd',
        conversationId: 'ch_x',
        text: 'hi',
        time: DateTime(2024),
        isMe: false,
      );
      expect(msg.eventKind, isNull);
      expect(msg.isSystemEvent, isFalse);
    });

    test('toJson/fromJson round-trips eventKind', () {
      final event = Message.systemEvent(
        kind: SystemEventKind.joined,
        announcedName: 'Boris',
        fromNodeId: '!aabbccdd',
        conversationId: 'ch_x',
        time: DateTime(2024),
        isMe: true,
      );
      final back = Message.fromJson(event.toJson());
      expect(back.eventKind, equals(SystemEventKind.joined));
      expect(back.text, equals('Boris'));
    });

    test('toJson omits eventKind for an ordinary message', () {
      final msg = Message(
        meshId: 1,
        fromNodeId: '!aabbccdd',
        conversationId: 'ch_x',
        text: 'hi',
        time: DateTime(2024),
        isMe: false,
      );
      expect(msg.toJson(), isNot(contains('eventKind')));
    });
  });

  group('encodeSystemEvent / decodeSystemEvent', () {
    test('a valid announcement round-trips', () {
      final plaintext = encodeSystemEvent(SystemEventKind.joined, 'Boris');
      expect(plaintext, equals('\u0000meshly:v1:joined:Boris'));
      final decoded = decodeSystemEvent(plaintext);
      expect(decoded, isNotNull);
      expect(decoded!.kind, equals(SystemEventKind.joined));
      expect(decoded.name, equals('Boris'));
    });

    test('both kinds encode with their own literal', () {
      expect(
        encodeSystemEvent(SystemEventKind.left, 'Алиса'),
        equals('\u0000meshly:v1:left:Алиса'),
      );
    });

    test('the display name is capped at kDisplayNameMaxLength code '
        'points, without splitting a surrogate pair', () {
      // 40 emoji, each a surrogate pair in UTF-16 (2 code units) but a
      // single rune/code point — a naive substring(0, 32) on the UTF-16
      // string would cut one in half and produce an unpaired surrogate.
      final longName = '🐧' * 40;
      final plaintext = encodeSystemEvent(SystemEventKind.joined, longName);
      final decoded = decodeSystemEvent(plaintext)!;
      expect(decoded.name.runes.length, equals(kDisplayNameMaxLength));
      expect(decoded.name, equals('🐧' * kDisplayNameMaxLength));
    });

    test(
      'an ordinary message that merely resembles an announcement does not '
      'parse',
      () {
        expect(
          decodeSystemEvent('meshly:v1:joinedBoris'),
          isNull,
          reason: 'no separator between kind and name',
        );
        expect(
          decodeSystemEvent(
            'this looks like meshly:v1:joined:Boris but '
            "isn't at the start",
          ),
          isNull,
        );
        expect(
          decodeSystemEvent('an ordinary message about meshly'),
          isNull,
        );
      },
    );

    test(
      'an announced name is sanitized on decode, not trusted from the wire',
      () {
        // A modified client can put anything on the wire — encodeSystemEvent's
        // capping only binds honest senders.
        final decoded = decodeSystemEvent(
          '\u0000meshly:v1:joined:Бо\nрис\tВ',
        );
        expect(decoded?.name, equals('Бо рис В'));

        final long = 'x' * 200;
        expect(
          decodeSystemEvent('\u0000meshly:v1:left:$long')?.name,
          hasLength(kDisplayNameMaxLength),
        );
      },
    );

    test('a name of only control characters decodes to nothing', () {
      expect(decodeSystemEvent('\u0000meshly:v1:joined:\n\t  '), isNull);
    });

    test('an unknown kind is ignored, not thrown', () {
      expect(decodeSystemEvent('meshly:v1:kicked:Boris'), isNull);
    });

    test('a truncated or malformed announcement is ignored, not thrown', () {
      expect(decodeSystemEvent(''), isNull);
      expect(decodeSystemEvent('meshly:v1:'), isNull);
      expect(decodeSystemEvent('meshly:v1:joined'), isNull);
      expect(
        decodeSystemEvent('meshly:v1:joined:'),
        isNull,
        reason: 'empty name',
      );
    });
  });
}
