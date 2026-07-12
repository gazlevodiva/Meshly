import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meshly/services/app_database.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite3;

/// Builds the tables shared by every pre-migration schema (v1 and v2):
/// contacts, channels, conversations. blocked_nodes and messages are
/// created separately by the caller since they differ across versions.
void _createSharedTables(sqlite3.Database raw) {
  raw
    ..execute('''
        CREATE TABLE contacts (
          node_id TEXT NOT NULL,
          display_name TEXT NOT NULL,
          avatar_emoji TEXT NULL,
          added_at INTEGER NOT NULL,
          PRIMARY KEY (node_id)
        );
      ''')
    ..execute('''
        CREATE TABLE channels (
          id TEXT NOT NULL,
          name TEXT NOT NULL,
          avatar_emoji TEXT NULL,
          psk BLOB NOT NULL,
          slot_index INTEGER NOT NULL,
          created_at INTEGER NOT NULL,
          PRIMARY KEY (id)
        );
      ''')
    ..execute('''
        CREATE TABLE conversations (
          id TEXT NOT NULL,
          type TEXT NOT NULL,
          peer_id TEXT NULL,
          channel_id TEXT NULL,
          unread_count INTEGER NOT NULL DEFAULT 0,
          updated_at INTEGER NOT NULL,
          PRIMARY KEY (id)
        );
      ''');
}

/// Pre-v3 `messages` schema: `mesh_id` is the PRIMARY KEY. This is the bug
/// we fixed — id-less incoming packets all share `mesh_id` 0 and silently
/// overwrote each other.
void _createLegacyMessagesTable(sqlite3.Database raw) {
  raw.execute('''
        CREATE TABLE messages (
          mesh_id INTEGER NOT NULL,
          conversation_id TEXT NOT NULL,
          from_node_id TEXT NOT NULL,
          text TEXT NOT NULL,
          time INTEGER NOT NULL,
          status TEXT NOT NULL,
          is_me INTEGER NOT NULL,
          PRIMARY KEY (mesh_id)
        );
      ''');
}

void main() {
  group('AppDatabase migrations', () {
    test(
      'fresh DB opens at current schemaVersion with all expected tables',
      () async {
        final db = AppDatabase.forTesting(NativeDatabase.memory());
        addTearDown(db.close);

        // Force the DB to actually open / run migrations.
        await db.customSelect('SELECT 1').getSingle();

        expect(db.schemaVersion, equals(4));

        final tableNames =
            (await db
                    .customSelect(
                      "SELECT name FROM sqlite_master WHERE type='table' AND name NOT LIKE 'sqlite_%'",
                    )
                    .get())
                .map((row) => row.data['name'] as String)
                .toSet();

        expect(
          tableNames,
          containsAll(<String>[
            'contacts',
            'channels',
            'conversations',
            'messages',
            'blocked_nodes',
          ]),
        );

        // v3 messages schema: surrogate autoincrement id, mesh_id no longer PK.
        final messagesInfo = await db
            .customSelect('PRAGMA table_info(messages)')
            .get();
        final idCol = messagesInfo.firstWhere(
          (row) => row.data['name'] == 'id',
        );
        expect(idCol.data['pk'], equals(1));
        final meshIdCol = messagesInfo.firstWhere(
          (row) => row.data['name'] == 'mesh_id',
        );
        expect(meshIdCol.data['pk'], equals(0));

        // v4 contacts schema: public_key column present and nullable.
        final contactsInfo = await db
            .customSelect('PRAGMA table_info(contacts)')
            .get();
        final pkCol = contactsInfo.firstWhere(
          (row) => row.data['name'] == 'public_key',
        );
        expect(pkCol.data['notnull'], equals(0));
      },
    );

    test(
      'v1 -> v4: blocked_nodes created and messages rebuilt, data preserved',
      () async {
        // Hand-build a v1 database with the sqlite3 package directly (not
        // via drift, so drift's migration machinery hasn't run yet): no
        // blocked_nodes table, messages with PRIMARY KEY(mesh_id).
        final raw = sqlite3.sqlite3.openInMemory();
        _createSharedTables(raw);
        _createLegacyMessagesTable(raw);
        // Drift stores its schema version in PRAGMA user_version.
        raw.execute('PRAGMA user_version = 1;');

        final now = DateTime.now().millisecondsSinceEpoch;
        raw
          ..execute(
            'INSERT INTO conversations '
            '(id, type, peer_id, channel_id, unread_count, updated_at) '
            "VALUES ('dm_!aaaa1111', 'dm', '!aaaa1111', NULL, 0, $now)",
          )
          // Two message rows already present before the migration runs.
          // What matters for the regression we're guarding is that the
          // rebuild preserves every row that existed in the old messages
          // table, regardless of mesh_id value/collisions.
          ..execute(
            'INSERT INTO messages '
            '(mesh_id, conversation_id, from_node_id, text, time, status, is_me) '
            "VALUES (0, 'dm_!aaaa1111', '!aaaa1111', 'первое', $now, 'received', 0)",
          )
          ..execute(
            'INSERT INTO messages '
            '(mesh_id, conversation_id, from_node_id, text, time, status, is_me) '
            "VALUES (55, 'dm_!aaaa1111', '!aaaa1111', 'второе', $now, 'sent', 1)",
          );

        // Now open AppDatabase against this pre-existing v1 DB — drift
        // should detect user_version=1 and run the v1->v3 migration chain.
        final db = AppDatabase.forTesting(NativeDatabase.opened(raw));
        addTearDown(db.close);

        final tableNames =
            (await db
                    .customSelect(
                      "SELECT name FROM sqlite_master WHERE type='table' AND name NOT LIKE 'sqlite_%'",
                    )
                    .get())
                .map((row) => row.data['name'] as String)
                .toSet();
        expect(tableNames, contains('blocked_nodes'));
        expect(tableNames, isNot(contains('messages_old')));

        final rows = await db
            .customSelect(
              'SELECT mesh_id, text, conversation_id FROM messages ORDER BY text',
            )
            .get();
        expect(rows, hasLength(2));
        expect(rows[0].data['text'], equals('второе'));
        expect(rows[0].data['mesh_id'], equals(55));
        expect(rows[1].data['text'], equals('первое'));
        expect(rows[1].data['mesh_id'], equals(0));

        // The rebuilt messages table must no longer have mesh_id as PK.
        final messagesInfo = await db
            .customSelect('PRAGMA table_info(messages)')
            .get();
        final meshIdCol = messagesInfo.firstWhere(
          (row) => row.data['name'] == 'mesh_id',
        );
        expect(meshIdCol.data['pk'], equals(0));
        final idCol = messagesInfo.firstWhere(
          (row) => row.data['name'] == 'id',
        );
        expect(idCol.data['pk'], equals(1));
      },
    );

    test(
      'v2 -> v3: messages rebuilt preserving rows with duplicate mesh_id=0 history',
      () async {
        final raw = sqlite3.sqlite3.openInMemory();
        _createSharedTables(raw);
        // v2 already has blocked_nodes.
        raw.execute('''
        CREATE TABLE blocked_nodes (
          node_id TEXT NOT NULL,
          PRIMARY KEY (node_id)
        );
      ''');
        _createLegacyMessagesTable(raw);
        final now = DateTime.now().millisecondsSinceEpoch;
        raw
          ..execute('PRAGMA user_version = 2;')
          ..execute("INSERT INTO blocked_nodes (node_id) VALUES ('!deadbeef')")
          ..execute(
            'INSERT INTO messages '
            '(mesh_id, conversation_id, from_node_id, text, time, status, is_me) '
            "VALUES (0, 'dm_!bbbb2222', '!bbbb2222', 'единственное', $now, 'received', 0)",
          );

        final db = AppDatabase.forTesting(NativeDatabase.opened(raw));
        addTearDown(db.close);

        // blocked_nodes row survived untouched (no migration step touches
        // it going from v2 to v3).
        final blocked = await db
            .customSelect('SELECT node_id FROM blocked_nodes')
            .get();
        expect(blocked.map((r) => r.data['node_id']), contains('!deadbeef'));

        final rows = await db.customSelect('SELECT text FROM messages').get();
        expect(rows, hasLength(1));
        expect(rows.first.data['text'], equals('единственное'));
      },
    );

    test(
      'v3 -> v4: public_key column added to contacts, existing rows preserved with null key',
      () async {
        // Hand-build a v3 database: shared tables + blocked_nodes + the
        // *current* (post-rebuild) messages schema, but contacts still
        // missing the public_key column.
        final raw = sqlite3.sqlite3.openInMemory();
        _createSharedTables(raw);
        raw
          ..execute('''
            CREATE TABLE blocked_nodes (
              node_id TEXT NOT NULL,
              PRIMARY KEY (node_id)
            );
          ''')
          ..execute('''
            CREATE TABLE messages (
              id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
              mesh_id INTEGER NOT NULL,
              conversation_id TEXT NOT NULL,
              from_node_id TEXT NOT NULL,
              text TEXT NOT NULL,
              time INTEGER NOT NULL,
              status TEXT NOT NULL,
              is_me INTEGER NOT NULL
            );
          ''');

        final now = DateTime.now().millisecondsSinceEpoch;
        raw
          ..execute('PRAGMA user_version = 3;')
          ..execute(
            'INSERT INTO contacts (node_id, display_name, avatar_emoji, added_at) '
            "VALUES ('!ccaaffee', 'Старый контакт', NULL, $now)",
          );

        final db = AppDatabase.forTesting(NativeDatabase.opened(raw));
        addTearDown(db.close);

        final contactsInfo = await db
            .customSelect('PRAGMA table_info(contacts)')
            .get();
        final pkCol = contactsInfo.firstWhere(
          (row) => row.data['name'] == 'public_key',
        );
        expect(pkCol.data['notnull'], equals(0));

        final rows = await db
            .customSelect(
              'SELECT node_id, display_name, public_key FROM contacts',
            )
            .get();
        expect(rows, hasLength(1));
        expect(rows.first.data['node_id'], equals('!ccaaffee'));
        expect(rows.first.data['display_name'], equals('Старый контакт'));
        expect(rows.first.data['public_key'], isNull);
      },
    );
  });
}
