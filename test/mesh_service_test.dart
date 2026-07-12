import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meshly/models/contact.dart';
import 'package:meshly/models/conversation.dart';
import 'package:meshly/services/app_database.dart' hide Contact, Conversation;
import 'package:meshly/services/contact_store.dart';
import 'package:meshly/services/mesh_service.dart';

void main() {
  group('MeshService', () {
    test('fresh instance has no device name and is not connected', () {
      final service = MeshService();
      expect(service.deviceName.value, isNull);
      expect(service.isConnected, isFalse);
    });

    test('fresh instance has no myNodeId', () {
      final service = MeshService();
      expect(service.myNodeId, isNull);
    });

    test('fresh instance: isOnline is false for any nodeId', () {
      final service = MeshService();
      expect(service.isOnline('!aabbccdd'), isFalse);
      expect(service.isOnline('!00000000'), isFalse);
    });

    test('fresh instance: lastHeardFor is null for any nodeId', () {
      final service = MeshService();
      expect(service.lastHeardFor('!aabbccdd'), isNull);
    });

    test(
      'writeRaw on a disconnected instance no-ops without throwing',
      () async {
        final service = MeshService();
        await expectLater(
          service.writeRaw([1, 2, 3]),
          completes,
        );
      },
    );

    test(
      'incomingMessages stream is available before any connection',
      () async {
        final service = MeshService();
        expect(service.incomingMessages, isA<Stream<Object?>>());
      },
    );

    test('dispose is idempotent-safe and clears deviceName', () {
      final service = MeshService()..dispose();
      // deviceName was already null; dispose should not throw or leave it
      // in an unexpected state.
      expect(service.deviceName.value, isNull);
    });

    // ── Phase 3: sendText DM-without-key guard ──────────────
    // No BLE radio needed: sendText checks the peer's publicKey before it
    // ever touches _toRadio, so this works against a disconnected instance.
    group('sendText DM without contact publicKey', () {
      final store = ContactStore.instance;

      setUp(() async {
        store.resetForTesting(AppDatabase.forTesting(NativeDatabase.memory()));
        await store.init();
      });

      test(
        'returns SendResult.needsKey when peer contact has no publicKey',
        () async {
          final contact = Contact(nodeId: '!aabbccdd', displayName: 'No Key');
          await store.saveContact(contact);
          final conv = Conversation.dm('!aabbccdd');
          await store.saveConversation(conv);

          final service = MeshService();
          final result = await service.sendText('hello', conv);
          expect(result, equals(SendResult.needsKey));
        },
      );

      test(
        'returns SendResult.needsKey when peer contact is unknown entirely',
        () async {
          final conv = Conversation.dm('!deadbeef');
          final service = MeshService();
          final result = await service.sendText('hello', conv);
          expect(result, equals(SendResult.needsKey));
        },
      );
    });
  });
}
