import 'dart:convert';
import 'package:drift/drift.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import '../models/contact.dart' as m;
import '../models/conversation.dart' as m;
import '../models/mesh_channel.dart' as m;
import '../models/message.dart' as m;
import 'app_database.dart';

// ignore_for_file: avoid_print

const _uuid = Uuid();

class ContactStore {
  ContactStore._();
  static final ContactStore instance = ContactStore._();

  AppDatabase _db = AppDatabase();
  bool _ready = false;

  // In-memory cache
  final Map<String, m.Contact> _contacts = {};
  final Map<String, m.MeshChannel> _channels = {};
  final Map<String, m.Conversation> _conversations = {};
  final Map<String, List<m.Message>> _messages = {};

  /// For unit tests only: replaces the db instance and clears in-memory state.
  void resetForTesting(AppDatabase db) {
    _db = db;
    _ready = false;
    _contacts.clear();
    _channels.clear();
    _conversations.clear();
    _messages.clear();
  }

  Future<void> init() async {
    if (_ready) return;
    try { await _migrateFromPrefs(); } catch (_) {}
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
    } catch (e) {
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
    list.add(msg);

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

    // Update conversation
    final conv = _conversations[msg.conversationId];
    if (conv != null) {
      conv.lastMessage = msg;
      conv.updatedAt = msg.time;
      if (!msg.isMe) conv.unreadCount++;
      await saveConversation(conv);
    }
  }

  Future<void> updateMessageStatus(int meshId, m.MessageStatus status) async {
    for (final list in _messages.values) {
      for (final msg in list) {
        if (msg.meshId == meshId) {
          msg.status = status;
          await (_db.update(_db.messages)
            ..where((t) => t.meshId.equals(meshId)))
            .write(MessagesCompanion(status: Value(status.name)));
          return;
        }
      }
    }
  }

  Future<void> markRead(String conversationId) async {
    final conv = _conversations[conversationId];
    if (conv != null) {
      conv.unreadCount = 0;
      await saveConversation(conv);
    }
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
    final r = List<int>.generate(32, (_) =>
        DateTime.now().microsecondsSinceEpoch & 0xFF ^ _uuid.v4().hashCode & 0xFF);
    return Uint8List.fromList(r);
  }
}
