import 'dart:convert';
import 'dart:math';

import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import 'package:meshly/models/contact.dart' as m;
import 'package:meshly/models/conversation.dart' as m;
import 'package:meshly/models/mesh_channel.dart' as m;
import 'package:meshly/models/message.dart' as m;
import 'package:meshly/services/app_database.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

// Prints are used for debug logging in ContactStore.
// ignore_for_file: avoid_print

const _uuid = Uuid();

class ContactStore extends ChangeNotifier {
  ContactStore._();
  static final ContactStore instance = ContactStore._();

  AppDatabase _db = AppDatabase();
  bool _ready = false;

  // In-memory cache
  final Map<String, m.Contact> _contacts = {};
  final Map<String, m.MeshChannel> _channels = {};
  final Map<String, m.Conversation> _conversations = {};
  final Map<String, List<m.Message>> _messages = {};
  final Set<String> _blocked = {};

  /// For unit tests only: replaces the db instance and clears in-memory state.
  void resetForTesting(AppDatabase db) {
    _db = db;
    _ready = false;
    _contacts.clear();
    _channels.clear();
    _conversations.clear();
    _messages.clear();
    _blocked.clear();
  }

  Future<void> init() async {
    if (_ready) return;
    try {
      await _migrateFromPrefs();
      // Migration failure is non-fatal. Intentionally catches both Exception
      // and Error (e.g. binding not initialized in test environments).
      // ignore: avoid_catches_without_on_clauses
    } catch (e) {
      print('[Store] migration skipped: $e');
    }
    await _loadAll();
    _ready = true;
    print('[Store] loaded: ${_contacts.length} contacts, ${_channels.length} channels, ${_conversations.length} conversations');
  }

  // ── Migration from SharedPreferences ──────────────────────

  Future<void> _migrateFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final oldContacts = prefs.getString('contacts_v1');
    if (oldContacts == null) return;

    try {
      final contactsList = jsonDecode(oldContacts) as List;
      for (final j in contactsList) {
        final c = m.Contact.fromJson(j as Map<String, dynamic>);
        await _db.into(_db.contacts).insertOnConflictUpdate(
          ContactsCompanion.insert(
            nodeId: c.nodeId,
            displayName: c.displayName,
            avatarEmoji: Value(c.avatarEmoji),
            addedAt: c.addedAt,
          ),
        );
      }

      final oldChannels = prefs.getString('channels_v1');
      if (oldChannels != null) {
        final channelsList = jsonDecode(oldChannels) as List;
        for (final j in channelsList) {
          final ch = m.MeshChannel.fromJson(j as Map<String, dynamic>);
          await _db.into(_db.channels).insertOnConflictUpdate(
            ChannelsCompanion.insert(
              id: ch.id,
              name: ch.name,
              avatarEmoji: Value(ch.avatarEmoji),
              psk: ch.psk,
              slotIndex: ch.slotIndex,
              createdAt: DateTime.now(),
            ),
          );
        }
      }

      final oldConvs = prefs.getString('conversations_v1');
      if (oldConvs != null) {
        final convsList = jsonDecode(oldConvs) as List;
        for (final j in convsList) {
          final conv = m.Conversation.fromJson(j as Map<String, dynamic>);
          await _db.into(_db.conversations).insertOnConflictUpdate(
            ConversationsCompanion.insert(
              id: conv.id,
              type: conv.type.name,
              peerId: Value(conv.peerId),
              channelId: Value(conv.channelId),
              unreadCount: Value(conv.unreadCount),
              updatedAt: conv.updatedAt,
            ),
          );
        }
      }

      final oldMsgs = prefs.getString('messages_v1');
      if (oldMsgs != null) {
        final msgsMap = jsonDecode(oldMsgs) as Map<String, dynamic>;
        for (final entry in msgsMap.entries) {
          for (final j in entry.value as List) {
            final msg = m.Message.fromJson(j as Map<String, dynamic>);
            await _db.into(_db.messages).insertOnConflictUpdate(
              MessagesCompanion.insert(
                meshId: Value(msg.meshId),
                conversationId: msg.conversationId,
                fromNodeId: msg.fromNodeId,
                messageText: msg.text,
                time: msg.time,
                status: msg.status.name,
                isMe: msg.isMe,
              ),
            );
          }
        }
      }
    } on Exception catch (e) {
      print('[Store] Migration error: $e');
    }

    await prefs.remove('contacts_v1');
    await prefs.remove('channels_v1');
    await prefs.remove('conversations_v1');
    await prefs.remove('messages_v1');
  }

  // ── Load all data into cache ───────────────────────────────

  Future<void> _loadAll() async {
    _contacts.clear();
    for (final row in await _db.select(_db.contacts).get()) {
      _contacts[row.nodeId] = _toContact(row);
    }

    _channels.clear();
    for (final row in await _db.select(_db.channels).get()) {
      _channels[row.id] = _toChannel(row);
    }

    _conversations.clear();
    for (final row in await _db.select(_db.conversations).get()) {
      _conversations[row.id] = _toConversation(row);
    }

    _messages.clear();
    for (final row in await _db.select(_db.messages).get()) {
      final msg = _toMessage(row);
      _messages.putIfAbsent(msg.conversationId, () => []).add(msg);
    }

    _blocked.clear();
    for (final row in await _db.select(_db.blockedNodes).get()) {
      _blocked.add(row.nodeId);
    }

    // Attach lastMessage to conversations
    for (final entry in _messages.entries) {
      final conv = _conversations[entry.key];
      if (conv != null && entry.value.isNotEmpty) {
        final sorted = List<m.Message>.from(entry.value)
          ..sort((a, b) => a.time.compareTo(b.time));
        conv.lastMessage = sorted.last;
      }
    }
  }

  // ── Contacts ──────────────────────────────────────────────

  List<m.Contact> get contacts => _contacts.values.toList()
    ..sort((a, b) => a.displayName.compareTo(b.displayName));

  m.Contact? contactByNodeId(String nodeId) => _contacts[nodeId];

  Future<void> saveContact(m.Contact c) async {
    _contacts[c.nodeId] = c;
    await _db.into(_db.contacts).insertOnConflictUpdate(
      ContactsCompanion.insert(
        nodeId: c.nodeId,
        displayName: c.displayName,
        avatarEmoji: Value(c.avatarEmoji),
        addedAt: c.addedAt,
      ),
    );
    // Create DM conversation if not exists
    final dmId = 'dm_${c.nodeId}';
    if (!_conversations.containsKey(dmId)) {
      await saveConversation(m.Conversation.dm(c.nodeId));
    }
    notifyListeners();
  }

  Future<void> deleteContact(String nodeId) async {
    _contacts.remove(nodeId);
    await (_db.delete(_db.contacts)..where((t) => t.nodeId.equals(nodeId))).go();
    // Remove the associated DM conversation
    final dmId = 'dm_$nodeId';
    if (_conversations.containsKey(dmId)) {
      _conversations.remove(dmId);
      await (_db.delete(_db.conversations)..where((t) => t.id.equals(dmId))).go();
    }
    notifyListeners();
  }

  // ── Blocked nodes ─────────────────────────────────────────

  List<String> get blockedNodes => _blocked.toList()..sort();

  bool isBlocked(String nodeId) => _blocked.contains(nodeId);

  Future<void> blockNode(String nodeId) async {
    await _db.into(_db.blockedNodes).insertOnConflictUpdate(
      BlockedNodesCompanion.insert(nodeId: nodeId),
    );
    _blocked.add(nodeId);
    // Remove the associated DM conversation (same as deleteContact)
    final dmId = 'dm_$nodeId';
    if (_conversations.containsKey(dmId)) {
      _conversations.remove(dmId);
      await (_db.delete(_db.conversations)..where((t) => t.id.equals(dmId))).go();
    }
    notifyListeners();
  }

  Future<void> unblockNode(String nodeId) async {
    await (_db.delete(_db.blockedNodes)..where((t) => t.nodeId.equals(nodeId))).go();
    _blocked.remove(nodeId);
    notifyListeners();
  }

  // ── Channels ──────────────────────────────────────────────

  List<m.MeshChannel> get channels => _channels.values.toList()
    ..sort((a, b) => a.slotIndex.compareTo(b.slotIndex));

  m.MeshChannel? channelById(String id) => _channels[id];

  Future<m.MeshChannel> createChannel({
    required String name,
    required int slotIndex,
    String? avatarEmoji,
    Uint8List? psk,
  }) async {
    final ch = m.MeshChannel(
      id: _uuid.v4(),
      name: name,
      slotIndex: slotIndex,
      avatarEmoji: avatarEmoji,
      psk: psk ?? _generatePsk(),
    );
    _channels[ch.id] = ch;
    await _db.into(_db.channels).insertOnConflictUpdate(
      ChannelsCompanion.insert(
        id: ch.id,
        name: ch.name,
        avatarEmoji: Value(ch.avatarEmoji),
        psk: ch.psk,
        slotIndex: ch.slotIndex,
        createdAt: DateTime.now(),
      ),
    );
    await saveConversation(m.Conversation.channel(ch.id));
    notifyListeners();
    return ch;
  }

  Future<void> saveChannel(m.MeshChannel ch) async {
    _channels[ch.id] = ch;
    await _db.into(_db.channels).insertOnConflictUpdate(
      ChannelsCompanion.insert(
        id: ch.id,
        name: ch.name,
        avatarEmoji: Value(ch.avatarEmoji),
        psk: ch.psk,
        slotIndex: ch.slotIndex,
        createdAt: DateTime.now(),
      ),
    );
  }

  Future<void> deleteChannel(String id) async {
    _channels.remove(id);
    await (_db.delete(_db.channels)..where((t) => t.id.equals(id))).go();
    notifyListeners();
  }

  // ── Conversations ─────────────────────────────────────────

  List<m.Conversation> get conversations => _conversations.values.toList()
    ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));

  m.Conversation? conversationById(String id) => _conversations[id];

  m.Conversation? dmForNode(String nodeId) => _conversations['dm_$nodeId'];

  m.Conversation? conversationForSlot(int slotIndex) {
    for (final ch in _channels.values) {
      if (ch.slotIndex == slotIndex) {
        return _conversations['ch_${ch.id}'];
      }
    }
    return null;
  }

  Future<void> saveConversation(m.Conversation conv) async {
    _conversations[conv.id] = conv;
    await _db.into(_db.conversations).insertOnConflictUpdate(
      ConversationsCompanion.insert(
        id: conv.id,
        type: conv.type.name,
        peerId: Value(conv.peerId),
        channelId: Value(conv.channelId),
        unreadCount: Value(conv.unreadCount),
        updatedAt: conv.updatedAt,
      ),
    );
  }

  // ── Messages ──────────────────────────────────────────────

  List<m.Message> messagesFor(String conversationId) =>
      List.unmodifiable(_messages[conversationId] ?? []);

  Future<void> addMessage(m.Message msg) async {
    final list = _messages.putIfAbsent(msg.conversationId, () => []);
    // Deduplicate by meshId
    if (msg.meshId != 0 && list.any((x) => x.meshId == msg.meshId)) return;

    final conv = _conversations[msg.conversationId];

    // Write message + conversation update atomically so a crash between the two
    // writes cannot leave lastMessage/unreadCount stale.
    await _db.transaction(() async {
      await _db.into(_db.messages).insertOnConflictUpdate(
        MessagesCompanion.insert(
          meshId: Value(msg.meshId),
          conversationId: msg.conversationId,
          fromNodeId: msg.fromNodeId,
          messageText: msg.text,
          time: msg.time,
          status: msg.status.name,
          isMe: msg.isMe,
        ),
      );

      if (conv != null) {
        if (!msg.isMe) conv.unreadCount++;
        conv
          ..lastMessage = msg
          ..updatedAt = msg.time;
        await _db.into(_db.conversations).insertOnConflictUpdate(
          ConversationsCompanion.insert(
            id: conv.id,
            type: conv.type.name,
            peerId: Value(conv.peerId),
            channelId: Value(conv.channelId),
            unreadCount: Value(conv.unreadCount),
            updatedAt: conv.updatedAt,
          ),
        );
      }
    });

    // Update in-memory cache only after successful DB commit.
    list.add(msg);
    notifyListeners();
  }

  Future<void> updateMessageStatus(int meshId, m.MessageStatus status) async {
    for (final list in _messages.values) {
      for (final msg in list) {
        if (msg.meshId == meshId) {
          msg.status = status;
          await (_db.update(_db.messages)
            ..where((t) => t.meshId.equals(meshId)))
            .write(MessagesCompanion(status: Value(status.name)));
          notifyListeners();
          return;
        }
      }
    }
  }

  Future<void> markRead(String conversationId) async {
    final conv = _conversations[conversationId];
    if (conv == null || conv.unreadCount == 0) return;
    conv.unreadCount = 0;
    await saveConversation(conv);
    notifyListeners();
  }

  // ── Helpers: display name ─────────────────────────────────

  String displayNameFor(String nodeId) {
    final c = _contacts[nodeId];
    if (c != null) return c.displayLabel;
    return nodeId.length > 5 ? '...${nodeId.substring(nodeId.length - 5)}' : nodeId;
  }

  // ── Row → Model converters ────────────────────────────────

  m.Contact _toContact(Contact row) => m.Contact(
    nodeId: row.nodeId,
    displayName: row.displayName,
    avatarEmoji: row.avatarEmoji,
    addedAt: row.addedAt,
  );

  m.MeshChannel _toChannel(Channel row) => m.MeshChannel(
    id: row.id,
    name: row.name,
    avatarEmoji: row.avatarEmoji,
    psk: row.psk,
    slotIndex: row.slotIndex,
  );

  m.Conversation _toConversation(Conversation row) => m.Conversation(
    id: row.id,
    type: m.ConversationType.values.byName(row.type),
    peerId: row.peerId,
    channelId: row.channelId,
    unreadCount: row.unreadCount,
    updatedAt: row.updatedAt,
  );

  m.Message _toMessage(Message row) => m.Message(
    meshId: row.meshId,
    fromNodeId: row.fromNodeId,
    conversationId: row.conversationId,
    text: row.messageText,
    time: row.time,
    status: m.MessageStatus.values.byName(row.status),
    isMe: row.isMe,
  );

  // ── Generate random 32-byte PSK ───────────────────────────

  static Uint8List _generatePsk() {
    final rng = Random.secure();
    return Uint8List.fromList(List<int>.generate(32, (_) => rng.nextInt(256)));
  }
}
