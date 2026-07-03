import 'package:flutter_test/flutter_test.dart';
import 'package:meshly/models/message.dart';

void main() {
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
