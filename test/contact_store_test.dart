import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meshly/services/app_database.dart' hide Contact, Message, Conversation, Channel;
import 'package:meshly/services/contact_store.dart';
import 'package:meshly/models/contact.dart';
import 'package:meshly/models/message.dart';

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
      expect(store.contactByNodeId('!11111111')!.displayName, equals('Мамочка'));
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

      final convId = 'dm_!deadbeef';
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

    test('addMessage twice with same meshId does not duplicate', () async {
      final contact = Contact(nodeId: '!00001111', displayName: 'Брат');
      await store.saveContact(contact);

      final convId = 'dm_!00001111';
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

      final convId = 'dm_!22223333';
      final msg = Message(
        meshId: 200,
        fromNodeId: '!22223333',
        conversationId: convId,
        text: 'статус',
        time: DateTime.now(),
        isMe: true,
        status: MessageStatus.sending,
      );
      await store.addMessage(msg);
      await store.updateMessageStatus(200, MessageStatus.acked);

      final updated = store.messagesFor(convId).first;
      expect(updated.status, equals(MessageStatus.acked));
    });

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
  });
}
