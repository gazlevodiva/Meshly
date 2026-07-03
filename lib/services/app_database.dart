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
  IntColumn get meshId => integer()();
  TextColumn get conversationId => text()();
  TextColumn get fromNodeId => text()();
  TextColumn get messageText => text().named('text')();
  DateTimeColumn get time => dateTime()();
  TextColumn get status => text()();
  BoolColumn get isMe => boolean()();

  @override
  Set<Column> get primaryKey => {meshId};
}

@DriftDatabase(tables: [Contacts, Channels, Conversations, Messages])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());
  AppDatabase.forTesting(super.e);

  @override
  int get schemaVersion => 1;

  static QueryExecutor _openConnection() {
    return LazyDatabase(() async {
      final dir = await getApplicationDocumentsDirectory();
      final file = File(p.join(dir.path, 'meshly.db'));
      return NativeDatabase.createInBackground(file);
    });
  }
}
