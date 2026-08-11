import 'package:flutter_test/flutter_test.dart';
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
  });
}
