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
    print(
      '[Store] loaded: ${_contacts.length} contacts, ${_channels.length} channels, ${_conversations.length} conversations',
    );
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
        await _db
            .into(_db.contacts)
            .insertOnConflictUpdate(
              ContactsCompanion.insert(
                nodeId: c.nodeId,
                displayName: c.displayName,
                avatarEmoji: Value(c.avatarEmoji),
                publicKey: Value(c.publicKey),
                addedAt: c.addedAt,
              ),
            );
      }

      final oldChannels = prefs.getString('channels_v1');
      if (oldChannels != null) {
        final channelsList = jsonDecode(oldChannels) as List;
        for (final j in channelsList) {
          final ch = m.MeshChannel.fromJson(j as Map<String, dynamic>);
          await _db
              .into(_db.channels)
              .insertOnConflictUpdate(
                ChannelsCompanion.insert(
                  id: ch.id,
                  name: ch.name,
                  avatarEmoji: Value(ch.avatarEmoji),
                  psk: ch.psk,
                  slotIndex: _legacySlotIndex,
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
          await _db
              .into(_db.conversations)
              .insertOnConflictUpdate(
                ConversationsCompanion.insert(
                  id: conv.id,
                  type: conv.type.name,
                  peerId: Value(conv.peerId),
                  channelId: Value(conv.channelId),
                  unreadCount: Value(conv.unreadCount),
                  iCanReadPeer: Value(conv.iCanReadPeer),
                  peerCanReadUs: Value(conv.peerCanReadUs),
                  writeAnyway: Value(conv.writeAnyway),
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
            await _db
                .into(_db.messages)
                .insert(
                  MessagesCompanion.insert(
                    meshId: msg.meshId,
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
    // Chronological order — the chat list and date chips rely on it.
    for (final list in _messages.values) {
      list.sort((a, b) => a.time.compareTo(b.time));
    }

    _blocked.clear();
    for (final row in await _db.select(_db.blockedNodes).get()) {
      _blocked.add(row.nodeId);
    }

    // Attach lastMessage to conversations
    for (final entry in _messages.entries) {
      final conv = _conversations[entry.key];
      if (conv != null && entry.value.isNotEmpty) {
        conv.lastMessage = entry.value.last;
      }
    }
  }

  // ── Contacts ──────────────────────────────────────────────

  List<m.Contact> get contacts =>
      _contacts.values.toList()
        ..sort((a, b) => a.displayName.compareTo(b.displayName));

  m.Contact? contactByNodeId(String nodeId) => _contacts[nodeId];

  /// Upserts a contact. A *missing* public key never overwrites a stored one:
  /// only a real key replaces a real key.
  ///
  /// The manual-entry tab builds a [m.Contact] with no key at all, so a plain
  /// upsert used to wipe the key of an existing contact whose node ID was
  /// retyped — the chat stayed flagged healthy while every send silently
  /// failed with "needs key". Losing an identity key must take an explicit
  /// delete, never a save.
  Future<void> saveContact(m.Contact c) async {
    final keptKey = c.publicKey ?? _contacts[c.nodeId]?.publicKey;
    // Mutating the argument on purpose: callers (and the cache) must see the
    // same contact the database now holds.
    c.publicKey = keptKey;
    _contacts[c.nodeId] = c;
    await _db
        .into(_db.contacts)
        .insertOnConflictUpdate(
          ContactsCompanion.insert(
            nodeId: c.nodeId,
            displayName: c.displayName,
            avatarEmoji: Value(c.avatarEmoji),
            publicKey: Value(keptKey),
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
    await (_db.delete(
      _db.contacts,
    )..where((t) => t.nodeId.equals(nodeId))).go();
    // Remove the associated DM conversation
    final dmId = 'dm_$nodeId';
    if (_conversations.containsKey(dmId)) {
      _conversations.remove(dmId);
      await (_db.delete(
        _db.conversations,
      )..where((t) => t.id.equals(dmId))).go();
      // No FK cascade on Messages (see app_database.dart) — drop its
      // messages explicitly, or they stay behind as orphans forever.
      _messages.remove(dmId);
      await (_db.delete(
        _db.messages,
      )..where((t) => t.conversationId.equals(dmId))).go();
    }
    notifyListeners();
  }

  // ── Blocked nodes ─────────────────────────────────────────

  List<String> get blockedNodes => _blocked.toList()..sort();

  bool isBlocked(String nodeId) => _blocked.contains(nodeId);

  Future<void> blockNode(String nodeId) async {
    await _db
        .into(_db.blockedNodes)
        .insertOnConflictUpdate(
          BlockedNodesCompanion.insert(nodeId: nodeId),
        );
    _blocked.add(nodeId);
    // Remove the associated DM conversation (same as deleteContact)
    final dmId = 'dm_$nodeId';
    if (_conversations.containsKey(dmId)) {
      _conversations.remove(dmId);
      await (_db.delete(
        _db.conversations,
      )..where((t) => t.id.equals(dmId))).go();
    }
    notifyListeners();
  }

  Future<void> unblockNode(String nodeId) async {
    await (_db.delete(
      _db.blockedNodes,
    )..where((t) => t.nodeId.equals(nodeId))).go();
    _blocked.remove(nodeId);
    // [blockNode] drops the DM conversation but keeps the contact, so unblock
    // has to put the conversation back. The receive path refuses to create
    // conversations by itself (a forged `from` must not conjure a chat), so
    // without this the contact would stay in the list, open nothing on tap,
    // and every future DM from them would be dropped in silence.
    final dmId = 'dm_$nodeId';
    if (_contacts.containsKey(nodeId) && !_conversations.containsKey(dmId)) {
      await saveConversation(m.Conversation.dm(nodeId));
    }
    notifyListeners();
  }

  // ── Channels ──────────────────────────────────────────────

  // Колонка Channels.slotIndex в БД NOT NULL, но схему сознательно не меняем
  // (см. отчёт спринта «отвязка бесед от слотов Meshtastic») — модель
  // MeshChannel больше не хранит слот, поэтому сюда просто пишем константу.
  static const _legacySlotIndex = 0;

  // Сортировка по времени создания, а не по слоту — слот больше ни на что не
  // влияет, а бесед теперь может быть сколько угодно. Для интерфейса
  // (список бесед на экране).
  List<m.MeshChannel> get channels =>
      channelsUnsorted.toList()
        ..sort((a, b) => a.createdAt.compareTo(b.createdAt));

  // Несортированное представление — для перебора PSK на приёме
  // (mesh_service.dart): порядок там не важен, а сортировка на каждый
  // входящий broadcast-пакет (включая чужой трафик) была лишней работой на
  // горячем пути.
  //
  // ВАЖНО: это обязан быть СНИМОК (List), а не живой `_channels.values`.
  // Вызывающий код перебирает результат с `await` внутри цикла (расшифровка
  // на каждый канал) — на await управление уходит в event loop, и если за
  // это время пользователь создаст/удалит беседу, `_channels` изменится.
  // Итерация по живому представлению Map в этот момент бросает
  // `ConcurrentModificationError` (это Error, а не Exception — воспроизведено
  // и учтено при разборе дефекта). Копирование List<Reference> из значений
  // Map — дешёвая операция (только ссылки, без клонирования MeshChannel),
  // так что здесь она ничего не стоит по сравнению с сортировкой, которую
  // как раз и хотели убрать. Не заменять обратно на `_channels.values`.
  List<m.MeshChannel> get channelsUnsorted => _channels.values.toList();

  m.MeshChannel? channelById(String id) => _channels[id];

  Future<m.MeshChannel> createChannel({
    required String name,
    String? avatarEmoji,
    Uint8List? psk,
  }) async {
    final ch = m.MeshChannel(
      id: _uuid.v4(),
      name: name,
      avatarEmoji: avatarEmoji,
      psk: psk ?? _generatePsk(),
    );
    _channels[ch.id] = ch;
    await _db
        .into(_db.channels)
        .insertOnConflictUpdate(
          ChannelsCompanion.insert(
            id: ch.id,
            name: ch.name,
            avatarEmoji: Value(ch.avatarEmoji),
            psk: ch.psk,
            slotIndex: _legacySlotIndex,
            createdAt: ch.createdAt,
          ),
        );
    await saveConversation(m.Conversation.channel(ch.id));
    notifyListeners();
    return ch;
  }

  Future<void> saveChannel(m.MeshChannel ch) async {
    _channels[ch.id] = ch;
    await _db
        .into(_db.channels)
        .insertOnConflictUpdate(
          ChannelsCompanion.insert(
            id: ch.id,
            name: ch.name,
            avatarEmoji: Value(ch.avatarEmoji),
            psk: ch.psk,
            slotIndex: _legacySlotIndex,
            createdAt: ch.createdAt,
          ),
        );
  }

  Future<void> deleteChannel(String id) async {
    _channels.remove(id);
    await (_db.delete(_db.channels)..where((t) => t.id.equals(id))).go();
    // Remove the associated channel conversation (same as deleteContact) —
    // otherwise it lingers with no channel behind it and the chat list shows
    // a raw internal id instead of a name.
    final convId = 'ch_$id';
    if (_conversations.containsKey(convId)) {
      _conversations.remove(convId);
      await (_db.delete(
        _db.conversations,
      )..where((t) => t.id.equals(convId))).go();
      // No FK cascade on Messages (see app_database.dart) — drop its
      // messages explicitly, or they stay behind as orphans forever.
      _messages.remove(convId);
      await (_db.delete(
        _db.messages,
      )..where((t) => t.conversationId.equals(convId))).go();
    }
    notifyListeners();
  }

  // ── Conversations ─────────────────────────────────────────

  List<m.Conversation> get conversations =>
      _conversations.values.toList()
        ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));

  m.Conversation? conversationById(String id) => _conversations[id];

  m.Conversation? dmForNode(String nodeId) => _conversations['dm_$nodeId'];

  Future<void> saveConversation(m.Conversation conv) async {
    _conversations[conv.id] = conv;
    await _db
        .into(_db.conversations)
        .insertOnConflictUpdate(
          ConversationsCompanion.insert(
            id: conv.id,
            type: conv.type.name,
            peerId: Value(conv.peerId),
            channelId: Value(conv.channelId),
            unreadCount: Value(conv.unreadCount),
            iCanReadPeer: Value(conv.iCanReadPeer),
            peerCanReadUs: Value(conv.peerCanReadUs),
            writeAnyway: Value(conv.writeAnyway),
            updatedAt: conv.updatedAt,
          ),
        );
  }

  // ── Secure chat health (peer reinstalled → key mismatch) ──
  //
  // Exactly two stored facts, one plain assignment per event. Nothing here
  // compares keys or timestamps: every caller already knows which of the two
  // directions its event proves (or hints at). See Conversation.secureOk.

  /// "We hold the peer's current key" — set from a decryption result (proof)
  /// or from scanning their QR (optimistic).
  Future<void> setICanReadPeer(String conversationId, {required bool value}) =>
      _setSecureFlags(conversationId, iCanReadPeer: value);

  /// "The peer holds our current key" — set from a decryption result (proof)
  /// or from an unauthenticated hint (their verify ping, their `[0x02]`).
  Future<void> setPeerCanReadUs(String conversationId, {required bool value}) =>
      _setSecureFlags(conversationId, peerCanReadUs: value);

  /// Both directions proven at once. Anything of theirs that decrypts says
  /// this: ECDH is symmetric, so a readable packet proves our copy of their
  /// key is right *and* that they encrypted to our current key.
  ///
  /// Retiring the "write anyway" override is not this method's job any more:
  /// [_setSecureFlags] clears it on *any* transition into a healthy state, so
  /// a caller that only flips the half it can prove gets the same guarantee.
  Future<void> markSecureVerified(String conversationId) =>
      _setSecureFlags(conversationId, iCanReadPeer: true, peerCanReadUs: true);

  /// The user chose to keep writing into a chat flagged broken. Sticky for the
  /// conversation — see [m.Conversation.writeAnyway].
  Future<void> setWriteAnyway(String conversationId, {required bool value}) =>
      _setSecureFlags(conversationId, writeAnyway: value);

  // Null means "leave this direction alone". Returns early when nothing
  // changes — pure write-saving, not semantics: assignment is idempotent.
  //
  // Enforces the one invariant of the override: "writeAnyway ⇒ the chat is
  // broken right now". Whatever route lands both directions on true — a
  // decrypted packet, a QR scan that only sets one half, [markSecureVerified]
  // — retires the override in the same write. Without that, the override
  // outlived the breakage it was granted for and silently swallowed the *next*
  // one: sending stayed unblocked and the user never chose that.
  Future<void> _setSecureFlags(
    String conversationId, {
    bool? iCanReadPeer,
    bool? peerCanReadUs,
    bool? writeAnyway,
  }) async {
    // ВНИМАНИЕ: от чтения полей conv (здесь) до их мутации (conv..iCanReadPeer
    // = ... ниже) не должно быть ни одного `await`. Сейчас гонки нет именно
    // потому, что весь этот путь синхронный и Dart не отдаёт управление
    // планировщику между чтением prevMine/prevTheirs/prevForce и присвоением
    // nextMine/nextTheirs/nextForce — конкурентный вызов _setSecureFlags для
    // той же беседы физически не может вклиниться между ними. Если кто-то
    // добавит `await` в этот промежуток (например, асинхронную проверку
    // перед мутацией), инвариант "prev* — это состояние ДО этого вызова"
    // тихо сломается: два конкурентных вызова смогут прочитать одно и то же
    // prev-состояние и один из них при откате (см. catch ниже) отменит
    // изменения другого. Заметить это на глаз потом будет очень трудно.
    final conv = _conversations[conversationId];
    if (conv == null) return;
    final nextMine = iCanReadPeer ?? conv.iCanReadPeer;
    final nextTheirs = peerCanReadUs ?? conv.peerCanReadUs;
    // A healthy chat has nothing to override.
    final nextForce =
        !(nextMine && nextTheirs) && (writeAnyway ?? conv.writeAnyway);
    if (nextMine == conv.iCanReadPeer &&
        nextTheirs == conv.peerCanReadUs &&
        nextForce == conv.writeAnyway) {
      return;
    }
    // Persist first: on a failed write roll the cache back and stay quiet, so
    // memory and disk never disagree about whether sending is blocked.
    final prevMine = conv.iCanReadPeer;
    final prevTheirs = conv.peerCanReadUs;
    final prevForce = conv.writeAnyway;
    conv
      ..iCanReadPeer = nextMine
      ..peerCanReadUs = nextTheirs
      ..writeAnyway = nextForce;
    try {
      await saveConversation(conv);
    } on Object catch (e) {
      conv
        ..iCanReadPeer = prevMine
        ..peerCanReadUs = prevTheirs
        ..writeAnyway = prevForce;
      debugPrint('[Store] secure flags save failed for $conversationId: $e');
      return;
    }
    notifyListeners();
  }

  /// Drops every stored undecryptable-placeholder message of a conversation.
  /// They are unreadable forever (the private key that could open them is
  /// gone), so there is nothing to recover. Returns how many were removed.
  Future<int> deleteUndecryptableMessages(String conversationId) async {
    final removed =
        await (_db.delete(_db.messages)..where(
              (t) =>
                  t.conversationId.equals(conversationId) &
                  t.messageText.equals(m.kUndecryptableSentinel),
            ))
            .go();
    if (removed == 0) return 0;

    final list = _messages[conversationId];
    list?.removeWhere((msg) => msg.text == m.kUndecryptableSentinel);

    final conv = _conversations[conversationId];
    if (conv != null) {
      if (conv.lastMessage?.text == m.kUndecryptableSentinel) {
        conv.lastMessage = (list != null && list.isNotEmpty) ? list.last : null;
      }
      // Otherwise the badge would keep counting messages that no longer
      // exist. Approximate (we don't know which of them were unread) but
      // never negative.
      if (conv.unreadCount > 0) {
        conv.unreadCount = (conv.unreadCount - removed).clamp(0, 1 << 30);
        await saveConversation(conv);
      }
    }
    notifyListeners();
    return removed;
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
      // Plain insert: meshId is not unique (id-less packets share meshId 0),
      // so an upsert would overwrite unrelated older messages.
      await _db
          .into(_db.messages)
          .insert(
            MessagesCompanion.insert(
              meshId: msg.meshId,
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
        await _db
            .into(_db.conversations)
            .insertOnConflictUpdate(
              ConversationsCompanion.insert(
                id: conv.id,
                type: conv.type.name,
                peerId: Value(conv.peerId),
                channelId: Value(conv.channelId),
                unreadCount: Value(conv.unreadCount),
                iCanReadPeer: Value(conv.iCanReadPeer),
                peerCanReadUs: Value(conv.peerCanReadUs),
                writeAnyway: Value(conv.writeAnyway),
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
        // ACKs correlate only our own outgoing packets.
        if (msg.isMe && msg.meshId == meshId) {
          msg.status = status;
          await (_db.update(_db.messages)
                ..where((t) => t.meshId.equals(meshId) & t.isMe.equals(true)))
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
    return nodeId.length > 5
        ? '...${nodeId.substring(nodeId.length - 5)}'
        : nodeId;
  }

  // ── Row → Model converters ────────────────────────────────

  m.Contact _toContact(Contact row) => m.Contact(
    nodeId: row.nodeId,
    displayName: row.displayName,
    avatarEmoji: row.avatarEmoji,
    publicKey: row.publicKey,
    addedAt: row.addedAt,
  );

  m.MeshChannel _toChannel(Channel row) => m.MeshChannel(
    id: row.id,
    name: row.name,
    avatarEmoji: row.avatarEmoji,
    psk: row.psk,
    createdAt: row.createdAt,
  );

  m.Conversation _toConversation(Conversation row) => m.Conversation(
    id: row.id,
    type: m.ConversationType.values.byName(row.type),
    peerId: row.peerId,
    channelId: row.channelId,
    unreadCount: row.unreadCount,
    iCanReadPeer: row.iCanReadPeer,
    peerCanReadUs: row.peerCanReadUs,
    writeAnyway: row.writeAnyway,
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
