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
  TextColumn get type => text()();        // 'dm' | 'channel'
  TextColumn get peerId => text().nullable()();
  TextColumn get channelId => text().nullable()();
  IntColumn get unreadCount => integer().withDefault(const Constant(0))();
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
}

class BlockedNodes extends Table {
  TextColumn get nodeId => text()();

  @override
  Set<Column> get primaryKey => {nodeId};
}

@DriftDatabase(tables: [Contacts, Channels, Conversations, Messages, BlockedNodes])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());
  AppDatabase.forTesting(super.e);

  @override
  int get schemaVersion => 3;

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
