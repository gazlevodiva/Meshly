import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

part 'app_database.g.dart';

class Contacts extends Table {
  TextColumn get nodeId => text()();
  TextColumn get displayName => text()();
  TextColumn get avatarEmoji => text().nullable()();
  // Peer's X25519 public key (32 bytes), used for E2E DM encryption.
  // Null until exchanged via QR.
  BlobColumn get publicKey => blob().nullable()();
  DateTimeColumn get addedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {nodeId};
}

class Channels extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get avatarEmoji => text().nullable()();
  BlobColumn get psk => blob()();
  IntColumn get slotIndex => integer()();
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

class Conversations extends Table {
  TextColumn get id => text()();
  TextColumn get type => text()(); // 'dm' | 'channel'
  TextColumn get peerId => text().nullable()();
  TextColumn get channelId => text().nullable()();
  IntColumn get unreadCount => integer().withDefault(const Constant(0))();
  // The two facts that describe a secure chat's health; everything else
  // (card, chat-list hint, send block) derives from them.
  // See Conversation.iCanReadPeer / Conversation.peerCanReadUs.
  BoolColumn get iCanReadPeer => boolean().withDefault(const Constant(true))();
  BoolColumn get peerCanReadUs => boolean().withDefault(const Constant(true))();
  // The user chose "write anyway" in a chat flagged broken. Persisted per
  // conversation: the breakage signal is unauthenticated, so a repeated forged
  // packet must not be able to re-block a chat the user already unblocked.
  // Cleared again when the chat is genuinely proven healthy.
  BoolColumn get writeAnyway => boolean().withDefault(const Constant(false))();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

class Messages extends Table {
  // Surrogate key: meshId is NOT unique — incoming packets without an id all
  // carry meshId 0, and radio-assigned ids can collide over time. Using it as
  // the PK silently overwrote older messages (lost chat history).
  IntColumn get id => integer().autoIncrement()();
  IntColumn get meshId => integer()();
  TextColumn get conversationId => text()();
  TextColumn get fromNodeId => text()();
  TextColumn get messageText => text().named('text')();
  DateTimeColumn get time => dateTime()();
  TextColumn get status => text()();
  BoolColumn get isMe => boolean()();
  // Null for an ordinary message from a person. Non-null ('joined' / 'left')
  // marks this row as a conversation system event instead — a member
  // announced joining or leaving. There is deliberately no separate "members"
  // table (see the sprint brief: this is a log of what this device saw, not a
  // roster) — an event is just another row in this table, so it sorts and
  // loads inline with regular messages for free. The announced display name
  // is stored in [messageText] itself; there's nothing else it could mean
  // when this column is set. See models/message.dart's SystemEventKind.
  TextColumn get eventKind => text().nullable()();
}

class BlockedNodes extends Table {
  TextColumn get nodeId => text()();

  @override
  Set<Column> get primaryKey => {nodeId};
}

@DriftDatabase(
  tables: [Contacts, Channels, Conversations, Messages, BlockedNodes],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());
  AppDatabase.forTesting(super.e);

  @override
  int get schemaVersion => 11;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onUpgrade: (m, from, to) async {
      if (from < 2) {
        await m.createTable(blockedNodes);
      }
      if (from < 3) {
        // messages had PRIMARY KEY(mesh_id); rows with colliding mesh ids
        // (all id-less incoming packets share meshId 0) overwrote each other.
        // Rebuild the table with a surrogate autoincrement id.
        await m.database.customStatement(
          'ALTER TABLE messages RENAME TO messages_old',
        );
        await m.createTable(messages);
        await m.database.customStatement(
          'INSERT INTO messages '
          '(mesh_id, conversation_id, from_node_id, text, time, status, is_me) '
          'SELECT mesh_id, conversation_id, from_node_id, text, time, status, '
          'is_me FROM messages_old',
        );
        await m.database.customStatement('DROP TABLE messages_old');
      }
      if (from < 4) {
        await m.addColumn(contacts, contacts.publicKey);
      }
      // Versions 5..8 only ever existed on dev builds (never released) and
      // their steps were deleted, so `from` can jump straight from 4 to 9.
      // Each of them added one column that is gone again in v9: v5
      // contacts.key_updated_at, v6 conversations.secure_broken_at, v7
      // .broken_with_key, v8 .peer_scanned_at. No step is needed to add
      // them — v9 rebuilds both tables and simply doesn't carry them over —
      // but anything reading an old column below MUST guard on `from`,
      // since a v4 (or v5) database doesn't have it yet. Test devices are
      // still on these versions; app_database_migration_test.dart covers
      // every path v1..v8 -> v9.
      if (from < 9) {
        // Four ad-hoc flags collapse into two facts: can I read them, can they
        // read me. Both default to true (healthy) — the first failure flips
        // them. Messages are untouched: only these two tables are rebuilt.
        await m.alterTable(
          // TableMigration is drift's only way to drop a column; marked
          // experimental upstream but stable in practice and covered by tests.
          // ignore: experimental_member_use
          TableMigration(
            conversations,
            columnTransformer: {
              // Old "something is broken" mark was ambiguous about the
              // direction; map it to the conservative half — we cannot read
              // them — so an actually-broken chat keeps showing the card
              // instead of silently claiming to be healthy.
              // The guard is not an optimisation: secure_broken_at does not
              // exist before v6, and referencing it there fails the whole
              // upgrade with "no such column" (app won't start).
              if (from >= 6)
                conversations.iCanReadPeer: const CustomExpression<bool>(
                  'secure_broken_at IS NULL',
                ),
            },
            newColumns: [
              conversations.iCanReadPeer,
              conversations.peerCanReadUs,
              // Also listed here even though it belongs to v10: the rebuild
              // recreates the table from the *current* schema, so the column
              // exists in the new table either way — without this it would be
              // copied from a source table that has no such column (NULL,
              // failing the NOT NULL/CHECK constraint). The v10 step below
              // therefore only runs for databases that skipped this rebuild.
              conversations.writeAnyway,
            ],
          ),
        );
        // Same as above: rebuild without the dropped column.
        // ignore: experimental_member_use
        await m.alterTable(TableMigration(contacts));
      }
      // "Write anyway" moved from screen state to the conversation, so it
      // survives leaving the chat. Defaults to false: existing chats start
      // blocked again exactly as they were. Only for databases already at v9
      // — anything older got the column from the v9 rebuild above, and adding
      // it twice fails with "duplicate column name".
      if (from >= 9 && from < 10) {
        await m.addColumn(conversations, conversations.writeAnyway);
      }
      // Join/leave system events reuse the messages table (see its
      // eventKind doc comment) instead of a new table.
      //
      // Guard is `from >= 3`, not just `from < 11`: the `from < 3` branch
      // above rebuilds messages with `m.createTable(messages)`, which always
      // builds from the *current* table definition — eventKind already
      // exists on that fresh table, so addColumn-ing it again here would
      // fail with "duplicate column name" (the same trap writeAnyway's v10
      // step avoids above). From v3 on, messages is untouched by every
      // migration until now, so a plain addColumn is safe for any of them.
      if (from >= 3 && from < 11) {
        await m.addColumn(messages, messages.eventKind);
      }
    },
  );

  static QueryExecutor _openConnection() {
    return LazyDatabase(() async {
      final dir = await getApplicationDocumentsDirectory();
      final file = File(p.join(dir.path, 'meshly.db'));
      return NativeDatabase.createInBackground(file);
    });
  }
}
