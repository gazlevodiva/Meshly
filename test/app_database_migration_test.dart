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

/// 32-byte key rendered as hex, for `x'...'` blob literals.
final String _keyHex = List<int>.filled(
  32,
  3,
).map((b) => b.toRadixString(16).padLeft(2, '0')).join();

/// Builds a database at one of the intermediate secure-chat schema versions
/// (5..8) with exactly the columns that version had, filled with data in
/// every table.
///
/// These versions only ever existed on dev builds — no migration step for
/// them survives in [AppDatabase] — but test devices are still carrying
/// them, so v9 has to swallow all four.
///
/// Column history: v5 added `contacts.key_updated_at`, v6
/// `conversations.secure_broken_at`, v7 `conversations.broken_with_key`,
/// v8 `conversations.peer_scanned_at`.
sqlite3.Database _buildSecureChatEraDb(int version) {
  assert(
    version >= 5 && version <= 8,
    'only the secure-chat era versions have these columns',
  );
  final now = DateTime.now().millisecondsSinceEpoch;
  final seconds = now ~/ 1000;

  final convColumns = <String>[
    'id TEXT NOT NULL',
    'type TEXT NOT NULL',
    'peer_id TEXT NULL',
    'channel_id TEXT NULL',
    'unread_count INTEGER NOT NULL DEFAULT 0',
    if (version >= 6) 'secure_broken_at INTEGER NULL',
    if (version >= 7) 'broken_with_key BLOB NULL',
    if (version >= 8) 'peer_scanned_at INTEGER NULL',
    'updated_at INTEGER NOT NULL',
    'PRIMARY KEY (id)',
  ];

  final raw = sqlite3.sqlite3.openInMemory()
    ..execute('''
        CREATE TABLE contacts (
          node_id TEXT NOT NULL,
          display_name TEXT NOT NULL,
          avatar_emoji TEXT NULL,
          public_key BLOB NULL,
          key_updated_at INTEGER NULL,
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
    ..execute('CREATE TABLE conversations (${convColumns.join(', ')});')
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
      ''')
    ..execute('PRAGMA user_version = $version;')
    // ── Contacts: one with a key, one bare ────────────────────────
    ..execute(
      'INSERT INTO contacts '
      '(node_id, display_name, avatar_emoji, public_key, key_updated_at, '
      'added_at) '
      "VALUES ('!c0ffee11', 'Сломанный', '🙂', x'$_keyHex', $seconds, $now)",
    )
    ..execute(
      'INSERT INTO contacts '
      '(node_id, display_name, avatar_emoji, public_key, key_updated_at, '
      'added_at) '
      "VALUES ('!f00dcafe', 'Здоровый', NULL, NULL, NULL, $now)",
    )
    ..execute(
      'INSERT INTO channels '
      '(id, name, avatar_emoji, psk, slot_index, created_at) '
      "VALUES ('ch-uuid-1', 'Общий', NULL, x'$_keyHex', 2, $now)",
    )
    ..execute("INSERT INTO blocked_nodes (node_id) VALUES ('!deadbeef')");

  // ── Conversations: a broken DM (only markable from v6 on), a
  // healthy DM and a channel chat ────────────────────────────────
  final names = <String>[
    'id',
    'type',
    'peer_id',
    'channel_id',
    'unread_count',
    if (version >= 6) 'secure_broken_at',
    if (version >= 7) 'broken_with_key',
    if (version >= 8) 'peer_scanned_at',
    'updated_at',
  ].join(', ');

  String conv(
    String id,
    String type,
    String? peerId,
    String? channelId,
    int unread, {
    required bool broken,
  }) {
    final values = <String>[
      "'$id'",
      "'$type'",
      if (peerId == null) 'NULL' else "'$peerId'",
      if (channelId == null) 'NULL' else "'$channelId'",
      '$unread',
      if (version >= 6) broken ? '$seconds' : 'NULL',
      if (version >= 7) broken ? "x'$_keyHex'" : 'NULL',
      if (version >= 8) broken ? '$seconds' : 'NULL',
      '$now',
    ];
    return 'INSERT INTO conversations ($names) VALUES (${values.join(', ')})';
  }

  raw
    ..execute(
      conv('dm_!c0ffee11', 'dm', '!c0ffee11', null, 3, broken: true),
    )
    ..execute(
      conv('dm_!f00dcafe', 'dm', '!f00dcafe', null, 0, broken: false),
    )
    ..execute(
      conv('ch_ch-uuid-1', 'channel', null, 'ch-uuid-1', 7, broken: false),
    )
    // ── Messages: the thing that must never be lost ───────────────
    ..execute(
      'INSERT INTO messages '
      '(mesh_id, conversation_id, from_node_id, text, time, status, is_me) '
      "VALUES (0, 'dm_!c0ffee11', '!c0ffee11', 'первое', $now, 'received', 0)",
    )
    ..execute(
      'INSERT INTO messages '
      '(mesh_id, conversation_id, from_node_id, text, time, status, is_me) '
      "VALUES (55, 'dm_!f00dcafe', '!f00dcafe', 'второе', $now, 'sent', 1)",
    )
    ..execute(
      'INSERT INTO messages '
      '(mesh_id, conversation_id, from_node_id, text, time, status, is_me) '
      "VALUES (0, 'ch_ch-uuid-1', '!f00dcafe', 'третье', $now, 'received', 0)",
    );

  return raw;
}

/// A database at v9: the two secure-chat booleans are in place, `write_anyway`
/// is not.
sqlite3.Database _buildV9Db() {
  final now = DateTime.now().millisecondsSinceEpoch;
  return sqlite3.sqlite3.openInMemory()
    ..execute('''
        CREATE TABLE contacts (
          node_id TEXT NOT NULL,
          display_name TEXT NOT NULL,
          avatar_emoji TEXT NULL,
          public_key BLOB NULL,
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
          i_can_read_peer INTEGER NOT NULL DEFAULT 1
            CHECK (i_can_read_peer IN (0, 1)),
          peer_can_read_us INTEGER NOT NULL DEFAULT 1
            CHECK (peer_can_read_us IN (0, 1)),
          updated_at INTEGER NOT NULL,
          PRIMARY KEY (id)
        );
      ''')
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
      ''')
    ..execute('PRAGMA user_version = 9;')
    ..execute(
      'INSERT INTO contacts '
      '(node_id, display_name, avatar_emoji, public_key, added_at) '
      "VALUES ('!c0ffee11', 'Сломанный', '🙂', x'$_keyHex', $now)",
    )
    ..execute(
      'INSERT INTO conversations '
      '(id, type, peer_id, channel_id, unread_count, i_can_read_peer, '
      'peer_can_read_us, updated_at) '
      "VALUES ('dm_!c0ffee11', 'dm', '!c0ffee11', NULL, 3, 0, 1, $now)",
    )
    ..execute(
      'INSERT INTO conversations '
      '(id, type, peer_id, channel_id, unread_count, i_can_read_peer, '
      'peer_can_read_us, updated_at) '
      "VALUES ('dm_!f00dcafe', 'dm', '!f00dcafe', NULL, 0, 1, 1, $now)",
    )
    ..execute(
      'INSERT INTO messages '
      '(mesh_id, conversation_id, from_node_id, text, time, status, is_me) '
      "VALUES (0, 'dm_!c0ffee11', '!c0ffee11', 'первое', $now, 'received', 0)",
    )
    ..execute(
      'INSERT INTO messages '
      '(mesh_id, conversation_id, from_node_id, text, time, status, is_me) '
      "VALUES (55, 'dm_!f00dcafe', '!f00dcafe', 'второе', $now, 'sent', 1)",
    );
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

        expect(db.schemaVersion, equals(10));

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

        // v9 contacts schema: the dead key_updated_at column is gone.
        expect(
          contactsInfo.map((row) => row.data['name']),
          isNot(contains('key_updated_at')),
        );

        // v9 conversations schema: two non-null booleans replace the four
        // ad-hoc secure-chat columns.
        final conversationsInfo = await db
            .customSelect('PRAGMA table_info(conversations)')
            .get();
        final convColumns = conversationsInfo
            .map((row) => row.data['name'])
            .toSet();
        expect(
          convColumns,
          containsAll(['i_can_read_peer', 'peer_can_read_us', 'write_anyway']),
        );
        expect(
          convColumns,
          isNot(
            anyOf(
              contains('secure_broken_at'),
              contains('broken_with_key'),
              contains('peer_scanned_at'),
            ),
          ),
        );
        for (final name in [
          'i_can_read_peer',
          'peer_can_read_us',
          // v10: sticky "write anyway" per conversation.
          'write_anyway',
        ]) {
          final col = conversationsInfo.firstWhere(
            (row) => row.data['name'] == name,
          );
          expect(col.data['notnull'], equals(1));
        }
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

    test(
      'v4 -> v9: contacts keep their keys, the dead column is never added',
      () async {
        // Hand-build a v4 database: contacts carry public_key, conversations
        // have none of the secure-chat columns at all.
        final now = DateTime.now().millisecondsSinceEpoch;
        final raw = sqlite3.sqlite3.openInMemory()
          ..execute('''
            CREATE TABLE contacts (
              node_id TEXT NOT NULL,
              display_name TEXT NOT NULL,
              avatar_emoji TEXT NULL,
              public_key BLOB NULL,
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
          ''')
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
          ''')
          ..execute('PRAGMA user_version = 4;')
          ..execute(
            'INSERT INTO contacts '
            '(node_id, display_name, avatar_emoji, public_key, added_at) '
            "VALUES ('!ddeeaadd', 'Контакт с ключом', '😀', X'010203', $now)",
          )
          ..execute(
            'INSERT INTO conversations '
            '(id, type, peer_id, channel_id, unread_count, updated_at) '
            "VALUES ('dm_!ddeeaadd', 'dm', '!ddeeaadd', NULL, 3, $now)",
          );

        final db = AppDatabase.forTesting(NativeDatabase.opened(raw));
        addTearDown(db.close);

        final contacts = await db
            .customSelect(
              'SELECT node_id, display_name, avatar_emoji, public_key '
              'FROM contacts',
            )
            .get();
        expect(contacts, hasLength(1));
        expect(contacts.first.data['display_name'], equals('Контакт с ключом'));
        expect(contacts.first.data['avatar_emoji'], equals('😀'));
        expect(contacts.first.data['public_key'], equals([1, 2, 3]));

        // No secure_broken_at existed here, so the transformer is skipped and
        // both directions simply start healthy.
        final convs = await db
            .customSelect(
              'SELECT unread_count, i_can_read_peer, peer_can_read_us '
              'FROM conversations',
            )
            .get();
        expect(convs, hasLength(1));
        expect(convs.first.data['unread_count'], equals(3));
        expect(convs.first.data['i_can_read_peer'], equals(1));
        expect(convs.first.data['peer_can_read_us'], equals(1));
      },
    );

    test(
      'v8 -> v9: four secure-chat columns collapse into two, every row of '
      'every table survives',
      () async {
        // Hand-build a full v8 database with data in every table — the whole
        // point of this test is that rebuilding contacts and conversations
        // loses nothing, least of all chat history.
        final now = DateTime.now().millisecondsSinceEpoch;
        final key = List<int>.filled(
          32,
          3,
        ).map((b) => b.toRadixString(16).padLeft(2, '0')).join();
        final raw = sqlite3.sqlite3.openInMemory()
          ..execute('''
            CREATE TABLE contacts (
              node_id TEXT NOT NULL,
              display_name TEXT NOT NULL,
              avatar_emoji TEXT NULL,
              public_key BLOB NULL,
              key_updated_at INTEGER NULL,
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
              secure_broken_at INTEGER NULL,
              broken_with_key BLOB NULL,
              peer_scanned_at INTEGER NULL,
              updated_at INTEGER NOT NULL,
              PRIMARY KEY (id)
            );
          ''')
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
          ''')
          ..execute('PRAGMA user_version = 8;')
          ..execute(
            'INSERT INTO contacts '
            '(node_id, display_name, avatar_emoji, public_key, key_updated_at, '
            'added_at) '
            "VALUES ('!c0ffee11', 'Сломанный', '🙂', x'$key', "
            '${now ~/ 1000}, $now)',
          )
          ..execute(
            'INSERT INTO contacts '
            '(node_id, display_name, avatar_emoji, public_key, key_updated_at, '
            'added_at) '
            "VALUES ('!f00dcafe', 'Здоровый', NULL, NULL, NULL, $now)",
          )
          ..execute(
            'INSERT INTO channels '
            '(id, name, avatar_emoji, psk, slot_index, created_at) '
            "VALUES ('ch-uuid-1', 'Общий', NULL, x'$key', 2, $now)",
          )
          ..execute("INSERT INTO blocked_nodes (node_id) VALUES ('!deadbeef')")
          // A broken chat...
          ..execute(
            'INSERT INTO conversations '
            '(id, type, peer_id, channel_id, unread_count, secure_broken_at, '
            'broken_with_key, peer_scanned_at, updated_at) '
            "VALUES ('dm_!c0ffee11', 'dm', '!c0ffee11', NULL, 3, "
            "${now ~/ 1000}, x'$key', ${now ~/ 1000}, $now)",
          )
          // ...and a healthy one.
          ..execute(
            'INSERT INTO conversations '
            '(id, type, peer_id, channel_id, unread_count, secure_broken_at, '
            'broken_with_key, peer_scanned_at, updated_at) '
            "VALUES ('dm_!f00dcafe', 'dm', '!f00dcafe', NULL, 0, "
            'NULL, NULL, NULL, $now)',
          )
          ..execute(
            'INSERT INTO messages '
            '(mesh_id, conversation_id, from_node_id, text, time, status, is_me) '
            "VALUES (0, 'dm_!c0ffee11', '!c0ffee11', 'первое', $now, "
            "'received', 0)",
          )
          ..execute(
            'INSERT INTO messages '
            '(mesh_id, conversation_id, from_node_id, text, time, status, is_me) '
            "VALUES (55, 'dm_!f00dcafe', '!f00dcafe', 'второе', $now, "
            "'sent', 1)",
          );

        final db = AppDatabase.forTesting(NativeDatabase.opened(raw));
        addTearDown(db.close);

        // ── Schema: old columns gone, new ones in place ──────────
        final convColumns =
            (await db.customSelect('PRAGMA table_info(conversations)').get())
                .map((row) => row.data['name'])
                .toSet();
        expect(
          convColumns,
          containsAll(['i_can_read_peer', 'peer_can_read_us', 'write_anyway']),
        );
        expect(
          convColumns,
          isNot(
            anyOf(
              contains('secure_broken_at'),
              contains('broken_with_key'),
              contains('peer_scanned_at'),
            ),
          ),
        );
        final contactColumns =
            (await db.customSelect('PRAGMA table_info(contacts)').get())
                .map((row) => row.data['name'])
                .toSet();
        expect(contactColumns, isNot(contains('key_updated_at')));

        // ── Messages: untouched, both rows still there ───────────
        final messages = await db
            .customSelect(
              'SELECT mesh_id, conversation_id, text, status, is_me '
              'FROM messages ORDER BY text',
            )
            .get();
        expect(messages, hasLength(2));
        expect(messages[0].data['text'], equals('второе'));
        expect(messages[0].data['mesh_id'], equals(55));
        expect(messages[0].data['is_me'], equals(1));
        expect(messages[1].data['text'], equals('первое'));
        expect(messages[1].data['conversation_id'], equals('dm_!c0ffee11'));

        // ── Contacts: rebuilt without losing a byte ──────────────
        final contacts = await db
            .customSelect(
              'SELECT node_id, display_name, avatar_emoji, public_key, added_at '
              'FROM contacts ORDER BY node_id',
            )
            .get();
        expect(contacts, hasLength(2));
        expect(contacts[0].data['node_id'], equals('!c0ffee11'));
        expect(contacts[0].data['display_name'], equals('Сломанный'));
        expect(contacts[0].data['avatar_emoji'], equals('🙂'));
        expect(contacts[0].data['public_key'], equals(List<int>.filled(32, 3)));
        expect(contacts[1].data['node_id'], equals('!f00dcafe'));
        expect(contacts[1].data['public_key'], isNull);

        // ── Channels and blocked nodes: never rebuilt ────────────
        final channels = await db
            .customSelect('SELECT id, name, slot_index FROM channels')
            .get();
        expect(channels, hasLength(1));
        expect(channels.first.data['name'], equals('Общий'));
        expect(channels.first.data['slot_index'], equals(2));
        final blocked = await db
            .customSelect('SELECT node_id FROM blocked_nodes')
            .get();
        expect(blocked.map((r) => r.data['node_id']), contains('!deadbeef'));

        // ── Conversations: data kept, state mapped ───────────────
        final convs = await db
            .customSelect(
              'SELECT id, peer_id, unread_count, i_can_read_peer, '
              'peer_can_read_us FROM conversations ORDER BY id',
            )
            .get();
        expect(convs, hasLength(2));
        expect(convs[0].data['id'], equals('dm_!c0ffee11'));
        expect(convs[0].data['peer_id'], equals('!c0ffee11'));
        expect(convs[0].data['unread_count'], equals(3));
        // The old mark was ambiguous about direction; it maps to the
        // conservative half so the recovery card keeps showing.
        expect(convs[0].data['i_can_read_peer'], equals(0));
        expect(convs[0].data['peer_can_read_us'], equals(1));
        // A healthy chat stays healthy in both directions.
        expect(convs[1].data['id'], equals('dm_!f00dcafe'));
        expect(convs[1].data['i_can_read_peer'], equals(1));
        expect(convs[1].data['peer_can_read_us'], equals(1));
      },
    );

    // v5..v7 shipped only on dev builds and their migration steps were
    // deleted, so v9 is the first step these databases ever run. Each of
    // them has a different set of conversations columns, and the v9
    // transformer must not reach for one that isn't there yet.
    for (final version in [5, 6, 7]) {
      test(
        'v$version -> v9: upgrade succeeds and no row is lost',
        () async {
          final raw = _buildSecureChatEraDb(version);
          final db = AppDatabase.forTesting(NativeDatabase.opened(raw));
          addTearDown(db.close);

          // Opening at all is half the test: a transformer referencing a
          // column this version lacks would blow up right here.
          await db.customSelect('SELECT 1').getSingle();

          // ── Messages: untouched by the rebuild ─────────────────
          final messages = await db
              .customSelect(
                'SELECT mesh_id, conversation_id, text, is_me '
                'FROM messages ORDER BY text',
              )
              .get();
          expect(messages, hasLength(3));
          expect(messages[0].data['text'], equals('второе'));
          expect(messages[0].data['mesh_id'], equals(55));
          expect(messages[0].data['conversation_id'], equals('dm_!f00dcafe'));
          expect(messages[0].data['is_me'], equals(1));
          expect(messages[1].data['text'], equals('первое'));
          expect(messages[1].data['conversation_id'], equals('dm_!c0ffee11'));
          expect(messages[1].data['is_me'], equals(0));
          expect(messages[2].data['text'], equals('третье'));
          expect(messages[2].data['conversation_id'], equals('ch_ch-uuid-1'));

          // ── Contacts: rebuilt, keys intact ─────────────────────
          final contacts = await db
              .customSelect(
                'SELECT node_id, display_name, avatar_emoji, public_key '
                'FROM contacts ORDER BY node_id',
              )
              .get();
          expect(contacts, hasLength(2));
          expect(contacts[0].data['node_id'], equals('!c0ffee11'));
          expect(contacts[0].data['display_name'], equals('Сломанный'));
          expect(contacts[0].data['avatar_emoji'], equals('🙂'));
          expect(
            contacts[0].data['public_key'],
            equals(List<int>.filled(32, 3)),
          );
          expect(contacts[1].data['node_id'], equals('!f00dcafe'));
          expect(contacts[1].data['public_key'], isNull);

          // ── Channels and blocked nodes: never rebuilt ──────────
          final channels = await db
              .customSelect('SELECT id, name, slot_index FROM channels')
              .get();
          expect(channels, hasLength(1));
          expect(channels.first.data['name'], equals('Общий'));
          expect(channels.first.data['slot_index'], equals(2));
          final blocked = await db
              .customSelect('SELECT node_id FROM blocked_nodes')
              .get();
          expect(blocked.map((r) => r.data['node_id']), contains('!deadbeef'));

          // ── Conversations: rows kept, state mapped ─────────────
          final convs = await db
              .customSelect(
                'SELECT id, type, peer_id, channel_id, unread_count, '
                'i_can_read_peer, peer_can_read_us FROM conversations '
                'ORDER BY id',
              )
              .get();
          expect(convs, hasLength(3));
          expect(convs[0].data['id'], equals('ch_ch-uuid-1'));
          expect(convs[0].data['type'], equals('channel'));
          expect(convs[0].data['channel_id'], equals('ch-uuid-1'));
          expect(convs[0].data['unread_count'], equals(7));
          expect(convs[1].data['id'], equals('dm_!c0ffee11'));
          expect(convs[1].data['peer_id'], equals('!c0ffee11'));
          expect(convs[1].data['unread_count'], equals(3));
          // v5 has no secure_broken_at at all, so nothing marks this chat
          // as broken and it starts healthy; from v6 on the old mark maps
          // to the conservative half.
          expect(
            convs[1].data['i_can_read_peer'],
            equals(version >= 6 ? 0 : 1),
          );
          expect(convs[1].data['peer_can_read_us'], equals(1));
          expect(convs[2].data['id'], equals('dm_!f00dcafe'));
          expect(convs[2].data['i_can_read_peer'], equals(1));
          expect(convs[2].data['peer_can_read_us'], equals(1));

          // ── Schema: dropped columns really gone ────────────────
          final convColumns =
              (await db.customSelect('PRAGMA table_info(conversations)').get())
                  .map((row) => row.data['name'])
                  .toSet();
          expect(
            convColumns,
            containsAll(['i_can_read_peer', 'peer_can_read_us', 'write_anyway']),
          );
          expect(
            convColumns,
            isNot(
              anyOf(
                contains('secure_broken_at'),
                contains('broken_with_key'),
                contains('peer_scanned_at'),
              ),
            ),
          );
          final contactColumns =
              (await db.customSelect('PRAGMA table_info(contacts)').get())
                  .map((row) => row.data['name'])
                  .toSet();
          expect(contactColumns, isNot(contains('key_updated_at')));

          // v10's column arrives with the rebuild, defaulting to "still
          // blocked" for every existing chat.
          final forced = await db
              .customSelect('SELECT write_anyway FROM conversations')
              .get();
          expect(
            forced.map((r) => r.data['write_anyway']),
            everyElement(equals(0)),
          );
        },
      );
    }

    // The only version that reaches the v10 step (everything older gets the
    // column from the v9 rebuild instead).
    test('v9 -> v10: write_anyway added, every row preserved', () async {
      final raw = _buildV9Db();
      final db = AppDatabase.forTesting(NativeDatabase.opened(raw));
      addTearDown(db.close);

      await db.customSelect('SELECT 1').getSingle();

      final convs = await db
          .customSelect(
            'SELECT id, type, peer_id, unread_count, i_can_read_peer, '
            'peer_can_read_us, write_anyway FROM conversations ORDER BY id',
          )
          .get();
      expect(convs, hasLength(2));
      expect(convs[0].data['id'], equals('dm_!c0ffee11'));
      expect(convs[0].data['unread_count'], equals(3));
      expect(convs[0].data['i_can_read_peer'], equals(0));
      expect(convs[0].data['peer_can_read_us'], equals(1));
      expect(convs[0].data['write_anyway'], equals(0));
      expect(convs[1].data['id'], equals('dm_!f00dcafe'));
      expect(convs[1].data['i_can_read_peer'], equals(1));
      expect(convs[1].data['write_anyway'], equals(0));

      // Messages and contacts are not touched by an addColumn, but a wrong
      // step (a rebuild instead) would quietly drop them.
      final messages = await db
          .customSelect('SELECT text FROM messages ORDER BY text')
          .get();
      expect(messages.map((r) => r.data['text']), equals(['второе', 'первое']));
      final contacts = await db
          .customSelect('SELECT node_id, public_key FROM contacts')
          .get();
      expect(contacts, hasLength(1));
      expect(contacts.first.data['public_key'], equals(List<int>.filled(32, 3)));
    });
  });
}
