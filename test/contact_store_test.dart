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

  // The in-memory database is closed with the test that opened it, instead of
  // being abandoned on the next resetForTesting.
  AppDatabase openTestDb() {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    return db;
  }

  setUp(() async {
    store.resetForTesting(openTestDb());
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
        final db = openTestDb();
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

    // Regression (destructive): the manual-entry tab builds a Contact with no
    // key, so re-adding an already known node ID by hand used to null out its
    // stored public key. The chat stayed flagged healthy while every send
    // silently failed with needsKey.
    test('saveContact without a key keeps the stored one', () async {
      final pk = Uint8List.fromList(List<int>.generate(32, (i) => i));
      await store.saveContact(
        Contact(nodeId: '!keep0001', displayName: 'Ключевой', publicKey: pk),
      );

      await store.saveContact(
        Contact(nodeId: '!keep0001', displayName: 'Переименован'),
      );

      final found = store.contactByNodeId('!keep0001')!;
      expect(found.publicKey, equals(pk), reason: 'key must survive');
      expect(found.displayName, equals('Переименован'));
    });

    test('saveContact without a key keeps the key across reload', () async {
      final db = openTestDb();
      store.resetForTesting(db);
      await store.init();

      final pk = Uint8List.fromList(List<int>.generate(32, (i) => 255 - i));
      await store.saveContact(
        Contact(nodeId: '!keep0002', displayName: 'Ключевой', publicKey: pk),
      );
      await store.saveContact(
        Contact(nodeId: '!keep0002', displayName: 'Вручную'),
      );

      store.resetForTesting(db);
      await store.init();
      expect(store.contactByNodeId('!keep0002')!.publicKey, equals(pk));
    });

    test('saveContact with a new key replaces the stored one', () async {
      final oldPk = Uint8List.fromList(List<int>.generate(32, (i) => i));
      final newPk = Uint8List.fromList(List<int>.generate(32, (i) => i + 1));
      await store.saveContact(
        Contact(nodeId: '!keep0003', displayName: 'Ключевой', publicKey: oldPk),
      );
      await store.saveContact(
        Contact(
          nodeId: '!keep0003',
          displayName: 'Переустановился',
          publicKey: newPk,
        ),
      );

      expect(store.contactByNodeId('!keep0003')!.publicKey, equals(newPk));
    });

    // The caller (add_contact_screen) decides whether to flag the chat
    // readable by looking at the contact it just saved, so the argument must
    // reflect what actually landed in the store.
    test('saveContact backfills the key onto the passed contact', () async {
      final pk = Uint8List.fromList(List<int>.generate(32, (i) => i));
      await store.saveContact(
        Contact(nodeId: '!keep0004', displayName: 'Ключевой', publicKey: pk),
      );

      final manual = Contact(nodeId: '!keep0004', displayName: 'Вручную');
      await store.saveContact(manual);
      expect(manual.publicKey, equals(pk));
    });

    test('saveContact of a brand new keyless contact stays keyless', () async {
      final fresh = Contact(nodeId: '!keep0005', displayName: 'Новый');
      await store.saveContact(fresh);
      expect(store.contactByNodeId('!keep0005')!.publicKey, isNull);
    });

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
        final db = openTestDb();
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
        final db = openTestDb();
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

    // Regression: blockNode drops the DM conversation, and the hardened
    // receive path no longer recreates one, so an unblock that did not
    // restore it lost every future DM from that contact forever (and the
    // contact row opened nothing on tap).
    test('unblockNode restores the DM conversation', () async {
      await store.saveContact(
        Contact(nodeId: '!77778888', displayName: 'Прощённый'),
      );
      expect(store.dmForNode('!77778888'), isNotNull);

      await store.blockNode('!77778888');
      expect(store.dmForNode('!77778888'), isNull);

      await store.unblockNode('!77778888');
      final conv = store.dmForNode('!77778888');
      expect(conv, isNotNull);
      expect(conv!.peerId, equals('!77778888'));
      expect(conv.isDm, isTrue);
    });

    test('unblockNode restores a conversation that survives reload', () async {
      final db = openTestDb();
      store.resetForTesting(db);
      await store.init();

      await store.saveContact(
        Contact(nodeId: '!7777aaaa', displayName: 'Прощённый'),
      );
      await store.blockNode('!7777aaaa');
      await store.unblockNode('!7777aaaa');

      store.resetForTesting(db);
      await store.init();
      expect(store.dmForNode('!7777aaaa'), isNotNull);
    });

    test('unblockNode of a node without a contact creates no chat', () async {
      await store.blockNode('!99990000');
      await store.unblockNode('!99990000');
      expect(store.dmForNode('!99990000'), isNull);
      expect(store.conversations, isEmpty);
    });

    test('unblockNode keeps an existing conversation as is', () async {
      await store.saveContact(
        Contact(nodeId: '!7777bbbb', displayName: 'Не блокировался'),
      );
      final conv = store.dmForNode('!7777bbbb')!;
      await store.setICanReadPeer(conv.id, value: false);

      await store.unblockNode('!7777bbbb');
      // Same object, flags untouched — no silent "healthy" reset.
      expect(identical(store.dmForNode('!7777bbbb'), conv), isTrue);
      expect(conv.iCanReadPeer, isFalse);
    });

    test('blocked nodes persist across reload', () async {
      final db = openTestDb();
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
      final db = openTestDb();
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

    // ── Broken secure chat (peer reinstalled) ─────────────────
    group('secure chat health', () {
      Future<String> makeDm(String nodeId) async {
        await store.saveContact(
          Contact(nodeId: nodeId, displayName: 'Переустановился'),
        );
        return 'dm_$nodeId';
      }

      test('a fresh conversation is healthy in both directions', () async {
        final convId = await makeDm('!br0ken01');
        final conv = store.conversationById(convId)!;
        expect(conv.iCanReadPeer, isTrue);
        expect(conv.peerCanReadUs, isTrue);
        expect(conv.secureOk, isTrue);
      });

      test(
        'setICanReadPeer(false) breaks only our half and notifies',
        () async {
          final convId = await makeDm('!br0ken02');

          var notifyCount = 0;
          void listener() => notifyCount++;
          store.addListener(listener);
          addTearDown(() => store.removeListener(listener));

          await store.setICanReadPeer(convId, value: false);
          final conv = store.conversationById(convId)!;
          expect(conv.iCanReadPeer, isFalse);
          // The other direction is untouched: [0x02] and an unreadable packet
          // say different things, and each writes only its own half.
          expect(conv.peerCanReadUs, isTrue);
          expect(conv.secureOk, isFalse);
          expect(notifyCount, equals(1));

          // Assignment, not a first-wins mark: a repeat is a no-op and must not
          // spend a write or a rebuild.
          await store.setICanReadPeer(convId, value: false);
          expect(notifyCount, equals(1));
        },
      );

      test(
        'setPeerCanReadUs(false) breaks only their half and notifies',
        () async {
          final convId = await makeDm('!br0ken03');

          var notifyCount = 0;
          void listener() => notifyCount++;
          store.addListener(listener);
          addTearDown(() => store.removeListener(listener));

          await store.setPeerCanReadUs(convId, value: false);
          final conv = store.conversationById(convId)!;
          expect(conv.peerCanReadUs, isFalse);
          expect(conv.iCanReadPeer, isTrue);
          expect(conv.secureOk, isFalse);
          expect(notifyCount, equals(1));

          await store.setPeerCanReadUs(convId, value: false);
          expect(notifyCount, equals(1));
        },
      );

      test('markSecureVerified restores both directions at once', () async {
        final convId = await makeDm('!br0ken04');
        await store.setICanReadPeer(convId, value: false);
        await store.setPeerCanReadUs(convId, value: false);

        var notifyCount = 0;
        void listener() => notifyCount++;
        store.addListener(listener);
        addTearDown(() => store.removeListener(listener));

        // One decrypted packet proves both halves — ECDH is symmetric.
        await store.markSecureVerified(convId);
        expect(store.conversationById(convId)!.secureOk, isTrue);
        expect(notifyCount, equals(1));

        await store.markSecureVerified(convId);
        expect(notifyCount, equals(1));
      });

      test('setICanReadPeer(true) alone does not unblock the chat', () async {
        // The peer deleted us: only they can fix their half, so re-scanning
        // their QR must not make the chat look healthy.
        final convId = await makeDm('!br0ken05');
        await store.setPeerCanReadUs(convId, value: false);
        await store.setICanReadPeer(convId, value: true);
        expect(store.conversationById(convId)!.secureOk, isFalse);
      });

      // ── "Write anyway" override ──────────────────────────────
      //
      // The invariant: writeAnyway may only be set while the chat is broken.
      // It is sticky on purpose (the breakage signal is unauthenticated, so a
      // per-visit hatch re-blocked the chat on every return), which makes
      // clearing it on recovery the load-bearing half.

      test('setWriteAnyway persists across reload', () async {
        final db = openTestDb();
        store.resetForTesting(db);
        await store.init();
        final convId = await makeDm('!fo0rce01');
        await store.setPeerCanReadUs(convId, value: false);
        await store.setWriteAnyway(convId, value: true);
        expect(store.conversationById(convId)!.writeAnyway, isTrue);

        store.resetForTesting(db);
        await store.init();
        expect(store.conversationById(convId)!.writeAnyway, isTrue);
      });

      test('writeAnyway survives while the chat is still broken', () async {
        final convId = await makeDm('!fo0rce02');
        await store.setICanReadPeer(convId, value: false);
        await store.setPeerCanReadUs(convId, value: false);
        await store.setWriteAnyway(convId, value: true);

        // Half the breakage clears — still broken, so the override stands.
        await store.setPeerCanReadUs(convId, value: true);
        final conv = store.conversationById(convId)!;
        expect(conv.secureOk, isFalse);
        expect(conv.writeAnyway, isTrue);
      });

      test('markSecureVerified retires the override', () async {
        final convId = await makeDm('!fo0rce03');
        await store.setICanReadPeer(convId, value: false);
        await store.setWriteAnyway(convId, value: true);

        await store.markSecureVerified(convId);
        final conv = store.conversationById(convId)!;
        expect(conv.secureOk, isTrue);
        expect(conv.writeAnyway, isFalse);
      });

      // Regression: recovery through a single half-flag (what a QR re-scan
      // does) left writeAnyway set on a healthy chat. The next *real* breakage
      // then failed to block sending, and the user — who never chose that —
      // kept writing into the void.
      test('healing via the last missing half retires the override', () async {
        final convId = await makeDm('!fo0rce04');
        await store.setICanReadPeer(convId, value: false);
        await store.setWriteAnyway(convId, value: true);

        // Exactly what a QR re-scan does: one direction, no markSecureVerified.
        await store.setICanReadPeer(convId, value: true);
        var conv = store.conversationById(convId)!;
        expect(conv.secureOk, isTrue);
        expect(conv.writeAnyway, isFalse);

        // ...so the next genuine breakage blocks sending again.
        await store.setPeerCanReadUs(convId, value: false);
        conv = store.conversationById(convId)!;
        expect(conv.secureOk, isFalse);
        expect(conv.writeAnyway, isFalse);
      });

      test('the retired override does not come back after a reload', () async {
        final db = openTestDb();
        store.resetForTesting(db);
        await store.init();
        final convId = await makeDm('!fo0rce05');
        await store.setPeerCanReadUs(convId, value: false);
        await store.setWriteAnyway(convId, value: true);
        await store.setPeerCanReadUs(convId, value: true);

        store.resetForTesting(db);
        await store.init();
        expect(store.conversationById(convId)!.writeAnyway, isFalse);
      });

      test('a healthy chat never records an override', () async {
        final convId = await makeDm('!fo0rce06');

        var notifyCount = 0;
        void listener() => notifyCount++;
        store.addListener(listener);
        addTearDown(() => store.removeListener(listener));

        await store.setWriteAnyway(convId, value: true);
        final conv = store.conversationById(convId)!;
        expect(conv.writeAnyway, isFalse);
        expect(notifyCount, equals(0), reason: 'nothing changed, no rebuild');
      });

      test('both flags persist across reload', () async {
        final db = openTestDb();
        store.resetForTesting(db);
        await store.init();
        final convId = await makeDm('!br0ken06');
        await store.setICanReadPeer(convId, value: false);
        await store.setPeerCanReadUs(convId, value: false);

        store.resetForTesting(db);
        await store.init();
        var conv = store.conversationById(convId)!;
        expect(conv.iCanReadPeer, isFalse);
        expect(conv.peerCanReadUs, isFalse);

        await store.markSecureVerified(convId);
        store.resetForTesting(db);
        await store.init();
        conv = store.conversationById(convId)!;
        expect(conv.iCanReadPeer, isTrue);
        expect(conv.peerCanReadUs, isTrue);
      });

      test('adding a message keeps the flags (upsert regression)', () async {
        // addMessage upserts the whole conversation row; a forgotten column
        // there would silently heal a broken chat on the next message.
        final db = openTestDb();
        store.resetForTesting(db);
        await store.init();
        final convId = await makeDm('!br0ken07');
        await store.setPeerCanReadUs(convId, value: false);

        await store.addMessage(
          Message(
            meshId: 777,
            fromNodeId: '!br0ken07',
            conversationId: convId,
            text: 'привет',
            time: DateTime.now(),
            isMe: false,
          ),
        );

        store.resetForTesting(db);
        await store.init();
        expect(store.conversationById(convId)!.peerCanReadUs, isFalse);
      });

      test('setting a flag on an unknown conversation is a no-op', () async {
        await store.setICanReadPeer('dm_!nosuch', value: false);
        expect(store.conversationById('dm_!nosuch'), isNull);
      });

      test(
        'deleteUndecryptableMessages removes only sentinels of that chat',
        () async {
          final aId = await makeDm('!clean001');
          final bId = await makeDm('!clean002');

          Future<void> add(String convId, String text, int meshId) =>
              store.addMessage(
                Message(
                  meshId: meshId,
                  fromNodeId: convId.substring(3),
                  conversationId: convId,
                  text: text,
                  time: DateTime.now(),
                  isMe: false,
                ),
              );

          await add(aId, kUndecryptableSentinel, 1);
          await add(aId, 'нормальное', 2);
          await add(aId, kUndecryptableSentinel, 3);
          await add(bId, kUndecryptableSentinel, 4);

          final removed = await store.deleteUndecryptableMessages(aId);
          expect(removed, equals(2));

          final left = store.messagesFor(aId);
          expect(left, hasLength(1));
          expect(left.single.text, equals('нормальное'));
          // The other conversation is untouched.
          expect(store.messagesFor(bId), hasLength(1));
        },
      );

      test(
        'deleteUndecryptableMessages returns 0 when there is nothing to purge',
        () async {
          final convId = await makeDm('!clean003');
          expect(await store.deleteUndecryptableMessages(convId), equals(0));
        },
      );

      test(
        'deleteUndecryptableMessages drops the sentinel from the DB too',
        () async {
          final db = openTestDb();
          store.resetForTesting(db);
          await store.init();
          final convId = await makeDm('!clean004');
          await store.addMessage(
            Message(
              meshId: 7,
              fromNodeId: '!clean004',
              conversationId: convId,
              text: kUndecryptableSentinel,
              time: DateTime.now(),
              isMe: false,
            ),
          );

          expect(await store.deleteUndecryptableMessages(convId), equals(1));

          store.resetForTesting(db);
          await store.init();
          expect(store.messagesFor(convId), isEmpty);
        },
      );
    });
  });
}
