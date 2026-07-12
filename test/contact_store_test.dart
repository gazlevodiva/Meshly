import 'dart:typed_data';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meshly/models/contact.dart';
import 'package:meshly/models/message.dart';
import 'package:meshly/services/app_database.dart'
    hide Channel, Contact, Conversation, Message;
import 'package:meshly/services/contact_store.dart';

void main() {
  final store = ContactStore.instance;

  setUp(() async {
    store.resetForTesting(AppDatabase.forTesting(NativeDatabase.memory()));
    await store.init();
  });

  group('ContactStore', () {
    test('saveContact + contactByNodeId returns the contact', () async {
      final contact = Contact(nodeId: '!aabbccdd', displayName: 'Тестовый');
      await store.saveContact(contact);

      final found = store.contactByNodeId('!aabbccdd');
      expect(found, isNotNull);
      expect(found!.displayName, equals('Тестовый'));
    });

    test('saveContact twice with same nodeId does not duplicate', () async {
      final contact = Contact(nodeId: '!11111111', displayName: 'Мама');
      await store.saveContact(contact);

      final updated = Contact(nodeId: '!11111111', displayName: 'Мамочка');
      await store.saveContact(updated);

      expect(store.contacts.length, equals(1));
      expect(
        store.contactByNodeId('!11111111')!.displayName,
        equals('Мамочка'),
      );
    });

    test(
      'saveContact with publicKey persists and reloads across reset',
      () async {
        final db = AppDatabase.forTesting(NativeDatabase.memory());
        store.resetForTesting(db);
        await store.init();

        final pk = Uint8List.fromList(List<int>.generate(32, (i) => i));
        final contact = Contact(
          nodeId: '!pubkey01',
          displayName: 'Ключевой',
          publicKey: pk,
        );
        await store.saveContact(contact);

        store.resetForTesting(db);
        await store.init();

        final reloaded = store.contactByNodeId('!pubkey01');
        expect(reloaded, isNotNull);
        expect(reloaded!.publicKey, equals(pk));
      },
    );

    test('saveContact creates DM Conversation automatically', () async {
      final contact = Contact(nodeId: '!cafebabe', displayName: 'Папа');
      await store.saveContact(contact);

      final conv = store.dmForNode('!cafebabe');
      expect(conv, isNotNull);
      expect(conv!.isDm, isTrue);
      expect(conv.peerId, equals('!cafebabe'));
    });

    test('addMessage + messagesFor returns the message', () async {
      final contact = Contact(nodeId: '!deadbeef', displayName: 'Сестра');
      await store.saveContact(contact);

      const convId = 'dm_!deadbeef';
      final msg = Message(
        meshId: 42,
        fromNodeId: '!deadbeef',
        conversationId: convId,
        text: 'Привет!',
        time: DateTime.now(),
        isMe: false,
      );
      await store.addMessage(msg);

      final messages = store.messagesFor(convId);
      expect(messages.length, equals(1));
      expect(messages.first.text, equals('Привет!'));
    });

    test(
      'messages with meshId 0 all survive a DB reload (no PK overwrite)',
      () async {
        final db = AppDatabase.forTesting(NativeDatabase.memory());
        store.resetForTesting(db);
        await store.init();

        final contact = Contact(nodeId: '!99990000', displayName: 'Дядя');
        await store.saveContact(contact);

        const convId = 'dm_!99990000';
        for (var i = 0; i < 3; i++) {
          await store.addMessage(
            Message(
              meshId: 0,
              fromNodeId: '!99990000',
              conversationId: convId,
              text: 'Сообщение $i',
              time: DateTime(2026, 7, 1 + i, 12),
              isMe: false,
            ),
          );
        }
        expect(store.messagesFor(convId).length, equals(3));

        // Reopen the same DB — all three rows must still be there,
        // in chronological order.
        store.resetForTesting(db);
        await store.init();
        final reloaded = store.messagesFor(convId);
        expect(reloaded.length, equals(3));
        expect(
          reloaded.map((x) => x.text).toList(),
          equals(['Сообщение 0', 'Сообщение 1', 'Сообщение 2']),
        );
      },
    );

    test('addMessage twice with same meshId does not duplicate', () async {
      final contact = Contact(nodeId: '!00001111', displayName: 'Брат');
      await store.saveContact(contact);

      const convId = 'dm_!00001111';
      final msg = Message(
        meshId: 100,
        fromNodeId: '!00001111',
        conversationId: convId,
        text: 'Раз',
        time: DateTime.now(),
        isMe: false,
      );
      await store.addMessage(msg);
      await store.addMessage(msg); // duplicate

      expect(store.messagesFor(convId).length, equals(1));
    });

    test('updateMessageStatus changes message status', () async {
      final contact = Contact(nodeId: '!22223333', displayName: 'Дядя');
      await store.saveContact(contact);

      const convId = 'dm_!22223333';
      final msg = Message(
        meshId: 200,
        fromNodeId: '!22223333',
        conversationId: convId,
        text: 'статус',
        time: DateTime.now(),
        isMe: true,
      );
      await store.addMessage(msg);
      await store.updateMessageStatus(200, MessageStatus.acked);

      final updated = store.messagesFor(convId).first;
      expect(updated.status, equals(MessageStatus.acked));
    });

    test(
      'updateMessageStatus notifies listeners and persists new status',
      () async {
        final db = AppDatabase.forTesting(NativeDatabase.memory());
        store.resetForTesting(db);
        await store.init();

        final contact = Contact(nodeId: '!44445555', displayName: 'Тётя');
        await store.saveContact(contact);

        const convId = 'dm_!44445555';
        await store.addMessage(
          Message(
            meshId: 300,
            fromNodeId: '!44445555',
            conversationId: convId,
            text: 'статус-нотиф',
            time: DateTime.now(),
            isMe: true,
          ),
        );

        var notified = false;
        store.addListener(() => notified = true);
        await store.updateMessageStatus(300, MessageStatus.acked);
        expect(notified, isTrue);

        // Reopen the same DB (simulates app restart) — status must persist.
        store.resetForTesting(db);
        await store.init();
        expect(
          store.messagesFor(convId).first.status,
          equals(MessageStatus.acked),
        );
      },
    );

    test('createChannel + channelById returns the channel', () async {
      final ch = await store.createChannel(
        name: 'семья',
        slotIndex: 2,
        avatarEmoji: '🏠',
      );

      final found = store.channelById(ch.id);
      expect(found, isNotNull);
      expect(found!.name, equals('семья'));
      expect(found.slotIndex, equals(2));
      expect(found.avatarEmoji, equals('🏠'));
    });

    test('conversationForSlot returns correct Conversation', () async {
      final ch = await store.createChannel(
        name: 'gazchannel',
        slotIndex: 3,
      );

      final conv = store.conversationForSlot(3);
      expect(conv, isNotNull);
      expect(conv!.isChannel, isTrue);
      expect(conv.channelId, equals(ch.id));
    });

    test('conversationForSlot returns null for unknown slot', () {
      final conv = store.conversationForSlot(99);
      expect(conv, isNull);
    });

    // ── addMessage atomicity ───────────────────────────────

    test('addMessage updates conversation lastMessage atomically', () async {
      final contact = Contact(nodeId: '!aaaabbbb', displayName: 'Тест');
      await store.saveContact(contact);
      const convId = 'dm_!aaaabbbb';

      final msg = Message(
        meshId: 1,
        fromNodeId: '!aaaabbbb',
        conversationId: convId,
        text: 'Атомарно',
        time: DateTime.now(),
        isMe: false,
      );
      await store.addMessage(msg);

      final conv = store.dmForNode('!aaaabbbb');
      expect(conv!.lastMessage?.text, equals('Атомарно'));
      expect(conv.unreadCount, equals(1));
    });

    test(
      'addMessage increments unreadCount only for incoming messages',
      () async {
        final contact = Contact(nodeId: '!ccccdddd', displayName: 'Тест2');
        await store.saveContact(contact);
        const convId = 'dm_!ccccdddd';

        final incoming = Message(
          meshId: 10,
          fromNodeId: '!ccccdddd',
          conversationId: convId,
          text: 'входящее',
          time: DateTime.now(),
          isMe: false,
        );
        final outgoing = Message(
          meshId: 11,
          fromNodeId: '!ccccdddd',
          conversationId: convId,
          text: 'исходящее',
          time: DateTime.now(),
          isMe: true,
        );
        await store.addMessage(incoming);
        await store.addMessage(outgoing);

        final conv = store.dmForNode('!ccccdddd');
        expect(conv!.unreadCount, equals(1));
      },
    );

    // ── markRead ──────────────────────────────────────────────

    test('markRead sets unreadCount to 0', () async {
      final contact = Contact(nodeId: '!11112222', displayName: 'Тест4');
      await store.saveContact(contact);
      const convId = 'dm_!11112222';

      await store.addMessage(
        Message(
          meshId: 50,
          fromNodeId: '!11112222',
          conversationId: convId,
          text: 'входящее',
          time: DateTime.now(),
          isMe: false,
        ),
      );
      expect(store.dmForNode('!11112222')!.unreadCount, equals(1));

      await store.markRead(convId);
      expect(store.dmForNode('!11112222')!.unreadCount, equals(0));
    });

    test('markRead notifies listeners', () async {
      final contact = Contact(nodeId: '!33334444', displayName: 'Тест5');
      await store.saveContact(contact);
      const convId = 'dm_!33334444';
      await store.addMessage(
        Message(
          meshId: 60,
          fromNodeId: '!33334444',
          conversationId: convId,
          text: 'msg',
          time: DateTime.now(),
          isMe: false,
        ),
      );

      var notified = false;
      store.addListener(() => notified = true);
      await store.markRead(convId);
      expect(notified, isTrue);
    });

    test('markRead is no-op when unreadCount is already 0', () async {
      final contact = Contact(nodeId: '!55556666', displayName: 'Тест6');
      await store.saveContact(contact);
      const convId = 'dm_!55556666';

      var notifyCount = 0;
      store.addListener(() => notifyCount++);
      await store.markRead(convId); // already 0
      expect(notifyCount, equals(0));
    });

    // ── ContactStore as ChangeNotifier ────────────────────────

    test('saveContact notifies listeners', () async {
      var notified = false;
      store.addListener(() => notified = true);
      await store.saveContact(
        Contact(nodeId: '!77778888', displayName: 'Нотиф'),
      );
      expect(notified, isTrue);
    });

    test('deleteContact notifies listeners', () async {
      await store.saveContact(
        Contact(nodeId: '!99990000', displayName: 'Удалить'),
      );
      var notified = false;
      store.addListener(() => notified = true);
      await store.deleteContact('!99990000');
      expect(notified, isTrue);
    });

    test('addMessage notifies listeners', () async {
      final contact = Contact(nodeId: '!aaaabbbb', displayName: 'МессагНотиф');
      await store.saveContact(contact);
      var notified = false;
      store.addListener(() => notified = true);
      await store.addMessage(
        Message(
          meshId: 777,
          fromNodeId: '!aaaabbbb',
          conversationId: 'dm_!aaaabbbb',
          text: 'нотиф',
          time: DateTime.now(),
          isMe: false,
        ),
      );
      expect(notified, isTrue);
    });

    // ── Blocked nodes ─────────────────────────────────────────

    test('isBlocked is false by default', () {
      expect(store.isBlocked('!12341234'), isFalse);
    });

    test(
      'blockNode + unblockNode toggle isBlocked and notify listeners',
      () async {
        var notifyCount = 0;
        store.addListener(() => notifyCount++);

        await store.blockNode('!badbadba');
        expect(store.isBlocked('!badbadba'), isTrue);
        expect(notifyCount, equals(1));

        await store.unblockNode('!badbadba');
        expect(store.isBlocked('!badbadba'), isFalse);
        expect(notifyCount, equals(2));
      },
    );

    test('blockNode removes the DM conversation', () async {
      final contact = Contact(nodeId: '!66667777', displayName: 'Спамер');
      await store.saveContact(contact);
      expect(store.dmForNode('!66667777'), isNotNull);

      await store.blockNode('!66667777');
      expect(store.dmForNode('!66667777'), isNull);
    });

    test('blocked nodes persist across reload', () async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      store.resetForTesting(db);
      await store.init();

      await store.blockNode('!88889999');

      store.resetForTesting(db);
      await store.init();
      expect(store.isBlocked('!88889999'), isTrue);
      expect(store.blockedNodes, equals(['!88889999']));
    });

    test('addMessage persists to DB — reload reflects correct state', () async {
      // Use a named in-memory DB so we can reopen it after reset.
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      store.resetForTesting(db);
      await store.init();

      final contact = Contact(nodeId: '!eeeeffff', displayName: 'Тест3');
      await store.saveContact(contact);
      const convId = 'dm_!eeeeffff';

      final msg = Message(
        meshId: 99,
        fromNodeId: '!eeeeffff',
        conversationId: convId,
        text: 'персистентно',
        time: DateTime.now(),
        isMe: false,
      );
      await store.addMessage(msg);

      // Reopen the same DB instance (simulates app restart with same file).
      store.resetForTesting(db);
      await store.init();

      final messages = store.messagesFor(convId);
      expect(messages.length, equals(1));
      expect(messages.first.text, equals('персистентно'));

      final conv = store.dmForNode('!eeeeffff');
      expect(conv!.unreadCount, equals(1));
    });
  });
}
