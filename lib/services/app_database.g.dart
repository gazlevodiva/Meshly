// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_database.dart';

// ignore_for_file: type=lint
class $ContactsTable extends Contacts with TableInfo<$ContactsTable, Contact> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ContactsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _nodeIdMeta = const VerificationMeta('nodeId');
  @override
  late final GeneratedColumn<String> nodeId = GeneratedColumn<String>(
    'node_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _displayNameMeta = const VerificationMeta(
    'displayName',
  );
  @override
  late final GeneratedColumn<String> displayName = GeneratedColumn<String>(
    'display_name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _avatarEmojiMeta = const VerificationMeta(
    'avatarEmoji',
  );
  @override
  late final GeneratedColumn<String> avatarEmoji = GeneratedColumn<String>(
    'avatar_emoji',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _publicKeyMeta = const VerificationMeta(
    'publicKey',
  );
  @override
  late final GeneratedColumn<Uint8List> publicKey = GeneratedColumn<Uint8List>(
    'public_key',
    aliasedName,
    true,
    type: DriftSqlType.blob,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _addedAtMeta = const VerificationMeta(
    'addedAt',
  );
  @override
  late final GeneratedColumn<DateTime> addedAt = GeneratedColumn<DateTime>(
    'added_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    nodeId,
    displayName,
    avatarEmoji,
    publicKey,
    addedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'contacts';
  @override
  VerificationContext validateIntegrity(
    Insertable<Contact> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('node_id')) {
      context.handle(
        _nodeIdMeta,
        nodeId.isAcceptableOrUnknown(data['node_id']!, _nodeIdMeta),
      );
    } else if (isInserting) {
      context.missing(_nodeIdMeta);
    }
    if (data.containsKey('display_name')) {
      context.handle(
        _displayNameMeta,
        displayName.isAcceptableOrUnknown(
          data['display_name']!,
          _displayNameMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_displayNameMeta);
    }
    if (data.containsKey('avatar_emoji')) {
      context.handle(
        _avatarEmojiMeta,
        avatarEmoji.isAcceptableOrUnknown(
          data['avatar_emoji']!,
          _avatarEmojiMeta,
        ),
      );
    }
    if (data.containsKey('public_key')) {
      context.handle(
        _publicKeyMeta,
        publicKey.isAcceptableOrUnknown(data['public_key']!, _publicKeyMeta),
      );
    }
    if (data.containsKey('added_at')) {
      context.handle(
        _addedAtMeta,
        addedAt.isAcceptableOrUnknown(data['added_at']!, _addedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_addedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {nodeId};
  @override
  Contact map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Contact(
      nodeId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}node_id'],
      )!,
      displayName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}display_name'],
      )!,
      avatarEmoji: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}avatar_emoji'],
      ),
      publicKey: attachedDatabase.typeMapping.read(
        DriftSqlType.blob,
        data['${effectivePrefix}public_key'],
      ),
      addedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}added_at'],
      )!,
    );
  }

  @override
  $ContactsTable createAlias(String alias) {
    return $ContactsTable(attachedDatabase, alias);
  }
}

class Contact extends DataClass implements Insertable<Contact> {
  final String nodeId;
  final String displayName;
  final String? avatarEmoji;
  final Uint8List? publicKey;
  final DateTime addedAt;
  const Contact({
    required this.nodeId,
    required this.displayName,
    this.avatarEmoji,
    this.publicKey,
    required this.addedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['node_id'] = Variable<String>(nodeId);
    map['display_name'] = Variable<String>(displayName);
    if (!nullToAbsent || avatarEmoji != null) {
      map['avatar_emoji'] = Variable<String>(avatarEmoji);
    }
    if (!nullToAbsent || publicKey != null) {
      map['public_key'] = Variable<Uint8List>(publicKey);
    }
    map['added_at'] = Variable<DateTime>(addedAt);
    return map;
  }

  ContactsCompanion toCompanion(bool nullToAbsent) {
    return ContactsCompanion(
      nodeId: Value(nodeId),
      displayName: Value(displayName),
      avatarEmoji: avatarEmoji == null && nullToAbsent
          ? const Value.absent()
          : Value(avatarEmoji),
      publicKey: publicKey == null && nullToAbsent
          ? const Value.absent()
          : Value(publicKey),
      addedAt: Value(addedAt),
    );
  }

  factory Contact.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Contact(
      nodeId: serializer.fromJson<String>(json['nodeId']),
      displayName: serializer.fromJson<String>(json['displayName']),
      avatarEmoji: serializer.fromJson<String?>(json['avatarEmoji']),
      publicKey: serializer.fromJson<Uint8List?>(json['publicKey']),
      addedAt: serializer.fromJson<DateTime>(json['addedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'nodeId': serializer.toJson<String>(nodeId),
      'displayName': serializer.toJson<String>(displayName),
      'avatarEmoji': serializer.toJson<String?>(avatarEmoji),
      'publicKey': serializer.toJson<Uint8List?>(publicKey),
      'addedAt': serializer.toJson<DateTime>(addedAt),
    };
  }

  Contact copyWith({
    String? nodeId,
    String? displayName,
    Value<String?> avatarEmoji = const Value.absent(),
    Value<Uint8List?> publicKey = const Value.absent(),
    DateTime? addedAt,
  }) => Contact(
    nodeId: nodeId ?? this.nodeId,
    displayName: displayName ?? this.displayName,
    avatarEmoji: avatarEmoji.present ? avatarEmoji.value : this.avatarEmoji,
    publicKey: publicKey.present ? publicKey.value : this.publicKey,
    addedAt: addedAt ?? this.addedAt,
  );
  Contact copyWithCompanion(ContactsCompanion data) {
    return Contact(
      nodeId: data.nodeId.present ? data.nodeId.value : this.nodeId,
      displayName: data.displayName.present
          ? data.displayName.value
          : this.displayName,
      avatarEmoji: data.avatarEmoji.present
          ? data.avatarEmoji.value
          : this.avatarEmoji,
      publicKey: data.publicKey.present ? data.publicKey.value : this.publicKey,
      addedAt: data.addedAt.present ? data.addedAt.value : this.addedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Contact(')
          ..write('nodeId: $nodeId, ')
          ..write('displayName: $displayName, ')
          ..write('avatarEmoji: $avatarEmoji, ')
          ..write('publicKey: $publicKey, ')
          ..write('addedAt: $addedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    nodeId,
    displayName,
    avatarEmoji,
    $driftBlobEquality.hash(publicKey),
    addedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Contact &&
          other.nodeId == this.nodeId &&
          other.displayName == this.displayName &&
          other.avatarEmoji == this.avatarEmoji &&
          $driftBlobEquality.equals(other.publicKey, this.publicKey) &&
          other.addedAt == this.addedAt);
}

class ContactsCompanion extends UpdateCompanion<Contact> {
  final Value<String> nodeId;
  final Value<String> displayName;
  final Value<String?> avatarEmoji;
  final Value<Uint8List?> publicKey;
  final Value<DateTime> addedAt;
  final Value<int> rowid;
  const ContactsCompanion({
    this.nodeId = const Value.absent(),
    this.displayName = const Value.absent(),
    this.avatarEmoji = const Value.absent(),
    this.publicKey = const Value.absent(),
    this.addedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ContactsCompanion.insert({
    required String nodeId,
    required String displayName,
    this.avatarEmoji = const Value.absent(),
    this.publicKey = const Value.absent(),
    required DateTime addedAt,
    this.rowid = const Value.absent(),
  }) : nodeId = Value(nodeId),
       displayName = Value(displayName),
       addedAt = Value(addedAt);
  static Insertable<Contact> custom({
    Expression<String>? nodeId,
    Expression<String>? displayName,
    Expression<String>? avatarEmoji,
    Expression<Uint8List>? publicKey,
    Expression<DateTime>? addedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (nodeId != null) 'node_id': nodeId,
      if (displayName != null) 'display_name': displayName,
      if (avatarEmoji != null) 'avatar_emoji': avatarEmoji,
      if (publicKey != null) 'public_key': publicKey,
      if (addedAt != null) 'added_at': addedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ContactsCompanion copyWith({
    Value<String>? nodeId,
    Value<String>? displayName,
    Value<String?>? avatarEmoji,
    Value<Uint8List?>? publicKey,
    Value<DateTime>? addedAt,
    Value<int>? rowid,
  }) {
    return ContactsCompanion(
      nodeId: nodeId ?? this.nodeId,
      displayName: displayName ?? this.displayName,
      avatarEmoji: avatarEmoji ?? this.avatarEmoji,
      publicKey: publicKey ?? this.publicKey,
      addedAt: addedAt ?? this.addedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (nodeId.present) {
      map['node_id'] = Variable<String>(nodeId.value);
    }
    if (displayName.present) {
      map['display_name'] = Variable<String>(displayName.value);
    }
    if (avatarEmoji.present) {
      map['avatar_emoji'] = Variable<String>(avatarEmoji.value);
    }
    if (publicKey.present) {
      map['public_key'] = Variable<Uint8List>(publicKey.value);
    }
    if (addedAt.present) {
      map['added_at'] = Variable<DateTime>(addedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ContactsCompanion(')
          ..write('nodeId: $nodeId, ')
          ..write('displayName: $displayName, ')
          ..write('avatarEmoji: $avatarEmoji, ')
          ..write('publicKey: $publicKey, ')
          ..write('addedAt: $addedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ChannelsTable extends Channels with TableInfo<$ChannelsTable, Channel> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ChannelsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _avatarEmojiMeta = const VerificationMeta(
    'avatarEmoji',
  );
  @override
  late final GeneratedColumn<String> avatarEmoji = GeneratedColumn<String>(
    'avatar_emoji',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _pskMeta = const VerificationMeta('psk');
  @override
  late final GeneratedColumn<Uint8List> psk = GeneratedColumn<Uint8List>(
    'psk',
    aliasedName,
    false,
    type: DriftSqlType.blob,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _slotIndexMeta = const VerificationMeta(
    'slotIndex',
  );
  @override
  late final GeneratedColumn<int> slotIndex = GeneratedColumn<int>(
    'slot_index',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    name,
    avatarEmoji,
    psk,
    slotIndex,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'channels';
  @override
  VerificationContext validateIntegrity(
    Insertable<Channel> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('avatar_emoji')) {
      context.handle(
        _avatarEmojiMeta,
        avatarEmoji.isAcceptableOrUnknown(
          data['avatar_emoji']!,
          _avatarEmojiMeta,
        ),
      );
    }
    if (data.containsKey('psk')) {
      context.handle(
        _pskMeta,
        psk.isAcceptableOrUnknown(data['psk']!, _pskMeta),
      );
    } else if (isInserting) {
      context.missing(_pskMeta);
    }
    if (data.containsKey('slot_index')) {
      context.handle(
        _slotIndexMeta,
        slotIndex.isAcceptableOrUnknown(data['slot_index']!, _slotIndexMeta),
      );
    } else if (isInserting) {
      context.missing(_slotIndexMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Channel map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Channel(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      avatarEmoji: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}avatar_emoji'],
      ),
      psk: attachedDatabase.typeMapping.read(
        DriftSqlType.blob,
        data['${effectivePrefix}psk'],
      )!,
      slotIndex: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}slot_index'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $ChannelsTable createAlias(String alias) {
    return $ChannelsTable(attachedDatabase, alias);
  }
}

class Channel extends DataClass implements Insertable<Channel> {
  final String id;
  final String name;
  final String? avatarEmoji;
  final Uint8List psk;
  final int slotIndex;
  final DateTime createdAt;
  const Channel({
    required this.id,
    required this.name,
    this.avatarEmoji,
    required this.psk,
    required this.slotIndex,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['name'] = Variable<String>(name);
    if (!nullToAbsent || avatarEmoji != null) {
      map['avatar_emoji'] = Variable<String>(avatarEmoji);
    }
    map['psk'] = Variable<Uint8List>(psk);
    map['slot_index'] = Variable<int>(slotIndex);
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  ChannelsCompanion toCompanion(bool nullToAbsent) {
    return ChannelsCompanion(
      id: Value(id),
      name: Value(name),
      avatarEmoji: avatarEmoji == null && nullToAbsent
          ? const Value.absent()
          : Value(avatarEmoji),
      psk: Value(psk),
      slotIndex: Value(slotIndex),
      createdAt: Value(createdAt),
    );
  }

  factory Channel.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Channel(
      id: serializer.fromJson<String>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      avatarEmoji: serializer.fromJson<String?>(json['avatarEmoji']),
      psk: serializer.fromJson<Uint8List>(json['psk']),
      slotIndex: serializer.fromJson<int>(json['slotIndex']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'name': serializer.toJson<String>(name),
      'avatarEmoji': serializer.toJson<String?>(avatarEmoji),
      'psk': serializer.toJson<Uint8List>(psk),
      'slotIndex': serializer.toJson<int>(slotIndex),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  Channel copyWith({
    String? id,
    String? name,
    Value<String?> avatarEmoji = const Value.absent(),
    Uint8List? psk,
    int? slotIndex,
    DateTime? createdAt,
  }) => Channel(
    id: id ?? this.id,
    name: name ?? this.name,
    avatarEmoji: avatarEmoji.present ? avatarEmoji.value : this.avatarEmoji,
    psk: psk ?? this.psk,
    slotIndex: slotIndex ?? this.slotIndex,
    createdAt: createdAt ?? this.createdAt,
  );
  Channel copyWithCompanion(ChannelsCompanion data) {
    return Channel(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      avatarEmoji: data.avatarEmoji.present
          ? data.avatarEmoji.value
          : this.avatarEmoji,
      psk: data.psk.present ? data.psk.value : this.psk,
      slotIndex: data.slotIndex.present ? data.slotIndex.value : this.slotIndex,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Channel(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('avatarEmoji: $avatarEmoji, ')
          ..write('psk: $psk, ')
          ..write('slotIndex: $slotIndex, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    name,
    avatarEmoji,
    $driftBlobEquality.hash(psk),
    slotIndex,
    createdAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Channel &&
          other.id == this.id &&
          other.name == this.name &&
          other.avatarEmoji == this.avatarEmoji &&
          $driftBlobEquality.equals(other.psk, this.psk) &&
          other.slotIndex == this.slotIndex &&
          other.createdAt == this.createdAt);
}

class ChannelsCompanion extends UpdateCompanion<Channel> {
  final Value<String> id;
  final Value<String> name;
  final Value<String?> avatarEmoji;
  final Value<Uint8List> psk;
  final Value<int> slotIndex;
  final Value<DateTime> createdAt;
  final Value<int> rowid;
  const ChannelsCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.avatarEmoji = const Value.absent(),
    this.psk = const Value.absent(),
    this.slotIndex = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ChannelsCompanion.insert({
    required String id,
    required String name,
    this.avatarEmoji = const Value.absent(),
    required Uint8List psk,
    required int slotIndex,
    required DateTime createdAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       name = Value(name),
       psk = Value(psk),
       slotIndex = Value(slotIndex),
       createdAt = Value(createdAt);
  static Insertable<Channel> custom({
    Expression<String>? id,
    Expression<String>? name,
    Expression<String>? avatarEmoji,
    Expression<Uint8List>? psk,
    Expression<int>? slotIndex,
    Expression<DateTime>? createdAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (avatarEmoji != null) 'avatar_emoji': avatarEmoji,
      if (psk != null) 'psk': psk,
      if (slotIndex != null) 'slot_index': slotIndex,
      if (createdAt != null) 'created_at': createdAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ChannelsCompanion copyWith({
    Value<String>? id,
    Value<String>? name,
    Value<String?>? avatarEmoji,
    Value<Uint8List>? psk,
    Value<int>? slotIndex,
    Value<DateTime>? createdAt,
    Value<int>? rowid,
  }) {
    return ChannelsCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      avatarEmoji: avatarEmoji ?? this.avatarEmoji,
      psk: psk ?? this.psk,
      slotIndex: slotIndex ?? this.slotIndex,
      createdAt: createdAt ?? this.createdAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (avatarEmoji.present) {
      map['avatar_emoji'] = Variable<String>(avatarEmoji.value);
    }
    if (psk.present) {
      map['psk'] = Variable<Uint8List>(psk.value);
    }
    if (slotIndex.present) {
      map['slot_index'] = Variable<int>(slotIndex.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ChannelsCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('avatarEmoji: $avatarEmoji, ')
          ..write('psk: $psk, ')
          ..write('slotIndex: $slotIndex, ')
          ..write('createdAt: $createdAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ConversationsTable extends Conversations
    with TableInfo<$ConversationsTable, Conversation> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ConversationsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _typeMeta = const VerificationMeta('type');
  @override
  late final GeneratedColumn<String> type = GeneratedColumn<String>(
    'type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _peerIdMeta = const VerificationMeta('peerId');
  @override
  late final GeneratedColumn<String> peerId = GeneratedColumn<String>(
    'peer_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _channelIdMeta = const VerificationMeta(
    'channelId',
  );
  @override
  late final GeneratedColumn<String> channelId = GeneratedColumn<String>(
    'channel_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _unreadCountMeta = const VerificationMeta(
    'unreadCount',
  );
  @override
  late final GeneratedColumn<int> unreadCount = GeneratedColumn<int>(
    'unread_count',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _iCanReadPeerMeta = const VerificationMeta(
    'iCanReadPeer',
  );
  @override
  late final GeneratedColumn<bool> iCanReadPeer = GeneratedColumn<bool>(
    'i_can_read_peer',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("i_can_read_peer" IN (0, 1))',
    ),
    defaultValue: const Constant(true),
  );
  static const VerificationMeta _peerCanReadUsMeta = const VerificationMeta(
    'peerCanReadUs',
  );
  @override
  late final GeneratedColumn<bool> peerCanReadUs = GeneratedColumn<bool>(
    'peer_can_read_us',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("peer_can_read_us" IN (0, 1))',
    ),
    defaultValue: const Constant(true),
  );
  static const VerificationMeta _writeAnywayMeta = const VerificationMeta(
    'writeAnyway',
  );
  @override
  late final GeneratedColumn<bool> writeAnyway = GeneratedColumn<bool>(
    'write_anyway',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("write_anyway" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    type,
    peerId,
    channelId,
    unreadCount,
    iCanReadPeer,
    peerCanReadUs,
    writeAnyway,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'conversations';
  @override
  VerificationContext validateIntegrity(
    Insertable<Conversation> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('type')) {
      context.handle(
        _typeMeta,
        type.isAcceptableOrUnknown(data['type']!, _typeMeta),
      );
    } else if (isInserting) {
      context.missing(_typeMeta);
    }
    if (data.containsKey('peer_id')) {
      context.handle(
        _peerIdMeta,
        peerId.isAcceptableOrUnknown(data['peer_id']!, _peerIdMeta),
      );
    }
    if (data.containsKey('channel_id')) {
      context.handle(
        _channelIdMeta,
        channelId.isAcceptableOrUnknown(data['channel_id']!, _channelIdMeta),
      );
    }
    if (data.containsKey('unread_count')) {
      context.handle(
        _unreadCountMeta,
        unreadCount.isAcceptableOrUnknown(
          data['unread_count']!,
          _unreadCountMeta,
        ),
      );
    }
    if (data.containsKey('i_can_read_peer')) {
      context.handle(
        _iCanReadPeerMeta,
        iCanReadPeer.isAcceptableOrUnknown(
          data['i_can_read_peer']!,
          _iCanReadPeerMeta,
        ),
      );
    }
    if (data.containsKey('peer_can_read_us')) {
      context.handle(
        _peerCanReadUsMeta,
        peerCanReadUs.isAcceptableOrUnknown(
          data['peer_can_read_us']!,
          _peerCanReadUsMeta,
        ),
      );
    }
    if (data.containsKey('write_anyway')) {
      context.handle(
        _writeAnywayMeta,
        writeAnyway.isAcceptableOrUnknown(
          data['write_anyway']!,
          _writeAnywayMeta,
        ),
      );
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Conversation map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Conversation(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      type: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}type'],
      )!,
      peerId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}peer_id'],
      ),
      channelId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}channel_id'],
      ),
      unreadCount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}unread_count'],
      )!,
      iCanReadPeer: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}i_can_read_peer'],
      )!,
      peerCanReadUs: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}peer_can_read_us'],
      )!,
      writeAnyway: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}write_anyway'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $ConversationsTable createAlias(String alias) {
    return $ConversationsTable(attachedDatabase, alias);
  }
}

class Conversation extends DataClass implements Insertable<Conversation> {
  final String id;
  final String type;
  final String? peerId;
  final String? channelId;
  final int unreadCount;
  final bool iCanReadPeer;
  final bool peerCanReadUs;
  final bool writeAnyway;
  final DateTime updatedAt;
  const Conversation({
    required this.id,
    required this.type,
    this.peerId,
    this.channelId,
    required this.unreadCount,
    required this.iCanReadPeer,
    required this.peerCanReadUs,
    required this.writeAnyway,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['type'] = Variable<String>(type);
    if (!nullToAbsent || peerId != null) {
      map['peer_id'] = Variable<String>(peerId);
    }
    if (!nullToAbsent || channelId != null) {
      map['channel_id'] = Variable<String>(channelId);
    }
    map['unread_count'] = Variable<int>(unreadCount);
    map['i_can_read_peer'] = Variable<bool>(iCanReadPeer);
    map['peer_can_read_us'] = Variable<bool>(peerCanReadUs);
    map['write_anyway'] = Variable<bool>(writeAnyway);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  ConversationsCompanion toCompanion(bool nullToAbsent) {
    return ConversationsCompanion(
      id: Value(id),
      type: Value(type),
      peerId: peerId == null && nullToAbsent
          ? const Value.absent()
          : Value(peerId),
      channelId: channelId == null && nullToAbsent
          ? const Value.absent()
          : Value(channelId),
      unreadCount: Value(unreadCount),
      iCanReadPeer: Value(iCanReadPeer),
      peerCanReadUs: Value(peerCanReadUs),
      writeAnyway: Value(writeAnyway),
      updatedAt: Value(updatedAt),
    );
  }

  factory Conversation.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Conversation(
      id: serializer.fromJson<String>(json['id']),
      type: serializer.fromJson<String>(json['type']),
      peerId: serializer.fromJson<String?>(json['peerId']),
      channelId: serializer.fromJson<String?>(json['channelId']),
      unreadCount: serializer.fromJson<int>(json['unreadCount']),
      iCanReadPeer: serializer.fromJson<bool>(json['iCanReadPeer']),
      peerCanReadUs: serializer.fromJson<bool>(json['peerCanReadUs']),
      writeAnyway: serializer.fromJson<bool>(json['writeAnyway']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'type': serializer.toJson<String>(type),
      'peerId': serializer.toJson<String?>(peerId),
      'channelId': serializer.toJson<String?>(channelId),
      'unreadCount': serializer.toJson<int>(unreadCount),
      'iCanReadPeer': serializer.toJson<bool>(iCanReadPeer),
      'peerCanReadUs': serializer.toJson<bool>(peerCanReadUs),
      'writeAnyway': serializer.toJson<bool>(writeAnyway),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  Conversation copyWith({
    String? id,
    String? type,
    Value<String?> peerId = const Value.absent(),
    Value<String?> channelId = const Value.absent(),
    int? unreadCount,
    bool? iCanReadPeer,
    bool? peerCanReadUs,
    bool? writeAnyway,
    DateTime? updatedAt,
  }) => Conversation(
    id: id ?? this.id,
    type: type ?? this.type,
    peerId: peerId.present ? peerId.value : this.peerId,
    channelId: channelId.present ? channelId.value : this.channelId,
    unreadCount: unreadCount ?? this.unreadCount,
    iCanReadPeer: iCanReadPeer ?? this.iCanReadPeer,
    peerCanReadUs: peerCanReadUs ?? this.peerCanReadUs,
    writeAnyway: writeAnyway ?? this.writeAnyway,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  Conversation copyWithCompanion(ConversationsCompanion data) {
    return Conversation(
      id: data.id.present ? data.id.value : this.id,
      type: data.type.present ? data.type.value : this.type,
      peerId: data.peerId.present ? data.peerId.value : this.peerId,
      channelId: data.channelId.present ? data.channelId.value : this.channelId,
      unreadCount: data.unreadCount.present
          ? data.unreadCount.value
          : this.unreadCount,
      iCanReadPeer: data.iCanReadPeer.present
          ? data.iCanReadPeer.value
          : this.iCanReadPeer,
      peerCanReadUs: data.peerCanReadUs.present
          ? data.peerCanReadUs.value
          : this.peerCanReadUs,
      writeAnyway: data.writeAnyway.present
          ? data.writeAnyway.value
          : this.writeAnyway,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Conversation(')
          ..write('id: $id, ')
          ..write('type: $type, ')
          ..write('peerId: $peerId, ')
          ..write('channelId: $channelId, ')
          ..write('unreadCount: $unreadCount, ')
          ..write('iCanReadPeer: $iCanReadPeer, ')
          ..write('peerCanReadUs: $peerCanReadUs, ')
          ..write('writeAnyway: $writeAnyway, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    type,
    peerId,
    channelId,
    unreadCount,
    iCanReadPeer,
    peerCanReadUs,
    writeAnyway,
    updatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Conversation &&
          other.id == this.id &&
          other.type == this.type &&
          other.peerId == this.peerId &&
          other.channelId == this.channelId &&
          other.unreadCount == this.unreadCount &&
          other.iCanReadPeer == this.iCanReadPeer &&
          other.peerCanReadUs == this.peerCanReadUs &&
          other.writeAnyway == this.writeAnyway &&
          other.updatedAt == this.updatedAt);
}

class ConversationsCompanion extends UpdateCompanion<Conversation> {
  final Value<String> id;
  final Value<String> type;
  final Value<String?> peerId;
  final Value<String?> channelId;
  final Value<int> unreadCount;
  final Value<bool> iCanReadPeer;
  final Value<bool> peerCanReadUs;
  final Value<bool> writeAnyway;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const ConversationsCompanion({
    this.id = const Value.absent(),
    this.type = const Value.absent(),
    this.peerId = const Value.absent(),
    this.channelId = const Value.absent(),
    this.unreadCount = const Value.absent(),
    this.iCanReadPeer = const Value.absent(),
    this.peerCanReadUs = const Value.absent(),
    this.writeAnyway = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ConversationsCompanion.insert({
    required String id,
    required String type,
    this.peerId = const Value.absent(),
    this.channelId = const Value.absent(),
    this.unreadCount = const Value.absent(),
    this.iCanReadPeer = const Value.absent(),
    this.peerCanReadUs = const Value.absent(),
    this.writeAnyway = const Value.absent(),
    required DateTime updatedAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       type = Value(type),
       updatedAt = Value(updatedAt);
  static Insertable<Conversation> custom({
    Expression<String>? id,
    Expression<String>? type,
    Expression<String>? peerId,
    Expression<String>? channelId,
    Expression<int>? unreadCount,
    Expression<bool>? iCanReadPeer,
    Expression<bool>? peerCanReadUs,
    Expression<bool>? writeAnyway,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (type != null) 'type': type,
      if (peerId != null) 'peer_id': peerId,
      if (channelId != null) 'channel_id': channelId,
      if (unreadCount != null) 'unread_count': unreadCount,
      if (iCanReadPeer != null) 'i_can_read_peer': iCanReadPeer,
      if (peerCanReadUs != null) 'peer_can_read_us': peerCanReadUs,
      if (writeAnyway != null) 'write_anyway': writeAnyway,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ConversationsCompanion copyWith({
    Value<String>? id,
    Value<String>? type,
    Value<String?>? peerId,
    Value<String?>? channelId,
    Value<int>? unreadCount,
    Value<bool>? iCanReadPeer,
    Value<bool>? peerCanReadUs,
    Value<bool>? writeAnyway,
    Value<DateTime>? updatedAt,
    Value<int>? rowid,
  }) {
    return ConversationsCompanion(
      id: id ?? this.id,
      type: type ?? this.type,
      peerId: peerId ?? this.peerId,
      channelId: channelId ?? this.channelId,
      unreadCount: unreadCount ?? this.unreadCount,
      iCanReadPeer: iCanReadPeer ?? this.iCanReadPeer,
      peerCanReadUs: peerCanReadUs ?? this.peerCanReadUs,
      writeAnyway: writeAnyway ?? this.writeAnyway,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (type.present) {
      map['type'] = Variable<String>(type.value);
    }
    if (peerId.present) {
      map['peer_id'] = Variable<String>(peerId.value);
    }
    if (channelId.present) {
      map['channel_id'] = Variable<String>(channelId.value);
    }
    if (unreadCount.present) {
      map['unread_count'] = Variable<int>(unreadCount.value);
    }
    if (iCanReadPeer.present) {
      map['i_can_read_peer'] = Variable<bool>(iCanReadPeer.value);
    }
    if (peerCanReadUs.present) {
      map['peer_can_read_us'] = Variable<bool>(peerCanReadUs.value);
    }
    if (writeAnyway.present) {
      map['write_anyway'] = Variable<bool>(writeAnyway.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ConversationsCompanion(')
          ..write('id: $id, ')
          ..write('type: $type, ')
          ..write('peerId: $peerId, ')
          ..write('channelId: $channelId, ')
          ..write('unreadCount: $unreadCount, ')
          ..write('iCanReadPeer: $iCanReadPeer, ')
          ..write('peerCanReadUs: $peerCanReadUs, ')
          ..write('writeAnyway: $writeAnyway, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $MessagesTable extends Messages with TableInfo<$MessagesTable, Message> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $MessagesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _meshIdMeta = const VerificationMeta('meshId');
  @override
  late final GeneratedColumn<int> meshId = GeneratedColumn<int>(
    'mesh_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _conversationIdMeta = const VerificationMeta(
    'conversationId',
  );
  @override
  late final GeneratedColumn<String> conversationId = GeneratedColumn<String>(
    'conversation_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _fromNodeIdMeta = const VerificationMeta(
    'fromNodeId',
  );
  @override
  late final GeneratedColumn<String> fromNodeId = GeneratedColumn<String>(
    'from_node_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _messageTextMeta = const VerificationMeta(
    'messageText',
  );
  @override
  late final GeneratedColumn<String> messageText = GeneratedColumn<String>(
    'text',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _timeMeta = const VerificationMeta('time');
  @override
  late final GeneratedColumn<DateTime> time = GeneratedColumn<DateTime>(
    'time',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
    'status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _isMeMeta = const VerificationMeta('isMe');
  @override
  late final GeneratedColumn<bool> isMe = GeneratedColumn<bool>(
    'is_me',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_me" IN (0, 1))',
    ),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    meshId,
    conversationId,
    fromNodeId,
    messageText,
    time,
    status,
    isMe,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'messages';
  @override
  VerificationContext validateIntegrity(
    Insertable<Message> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('mesh_id')) {
      context.handle(
        _meshIdMeta,
        meshId.isAcceptableOrUnknown(data['mesh_id']!, _meshIdMeta),
      );
    } else if (isInserting) {
      context.missing(_meshIdMeta);
    }
    if (data.containsKey('conversation_id')) {
      context.handle(
        _conversationIdMeta,
        conversationId.isAcceptableOrUnknown(
          data['conversation_id']!,
          _conversationIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_conversationIdMeta);
    }
    if (data.containsKey('from_node_id')) {
      context.handle(
        _fromNodeIdMeta,
        fromNodeId.isAcceptableOrUnknown(
          data['from_node_id']!,
          _fromNodeIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_fromNodeIdMeta);
    }
    if (data.containsKey('text')) {
      context.handle(
        _messageTextMeta,
        messageText.isAcceptableOrUnknown(data['text']!, _messageTextMeta),
      );
    } else if (isInserting) {
      context.missing(_messageTextMeta);
    }
    if (data.containsKey('time')) {
      context.handle(
        _timeMeta,
        time.isAcceptableOrUnknown(data['time']!, _timeMeta),
      );
    } else if (isInserting) {
      context.missing(_timeMeta);
    }
    if (data.containsKey('status')) {
      context.handle(
        _statusMeta,
        status.isAcceptableOrUnknown(data['status']!, _statusMeta),
      );
    } else if (isInserting) {
      context.missing(_statusMeta);
    }
    if (data.containsKey('is_me')) {
      context.handle(
        _isMeMeta,
        isMe.isAcceptableOrUnknown(data['is_me']!, _isMeMeta),
      );
    } else if (isInserting) {
      context.missing(_isMeMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Message map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Message(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      meshId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}mesh_id'],
      )!,
      conversationId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}conversation_id'],
      )!,
      fromNodeId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}from_node_id'],
      )!,
      messageText: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}text'],
      )!,
      time: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}time'],
      )!,
      status: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}status'],
      )!,
      isMe: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_me'],
      )!,
    );
  }

  @override
  $MessagesTable createAlias(String alias) {
    return $MessagesTable(attachedDatabase, alias);
  }
}

class Message extends DataClass implements Insertable<Message> {
  final int id;
  final int meshId;
  final String conversationId;
  final String fromNodeId;
  final String messageText;
  final DateTime time;
  final String status;
  final bool isMe;
  const Message({
    required this.id,
    required this.meshId,
    required this.conversationId,
    required this.fromNodeId,
    required this.messageText,
    required this.time,
    required this.status,
    required this.isMe,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['mesh_id'] = Variable<int>(meshId);
    map['conversation_id'] = Variable<String>(conversationId);
    map['from_node_id'] = Variable<String>(fromNodeId);
    map['text'] = Variable<String>(messageText);
    map['time'] = Variable<DateTime>(time);
    map['status'] = Variable<String>(status);
    map['is_me'] = Variable<bool>(isMe);
    return map;
  }

  MessagesCompanion toCompanion(bool nullToAbsent) {
    return MessagesCompanion(
      id: Value(id),
      meshId: Value(meshId),
      conversationId: Value(conversationId),
      fromNodeId: Value(fromNodeId),
      messageText: Value(messageText),
      time: Value(time),
      status: Value(status),
      isMe: Value(isMe),
    );
  }

  factory Message.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Message(
      id: serializer.fromJson<int>(json['id']),
      meshId: serializer.fromJson<int>(json['meshId']),
      conversationId: serializer.fromJson<String>(json['conversationId']),
      fromNodeId: serializer.fromJson<String>(json['fromNodeId']),
      messageText: serializer.fromJson<String>(json['messageText']),
      time: serializer.fromJson<DateTime>(json['time']),
      status: serializer.fromJson<String>(json['status']),
      isMe: serializer.fromJson<bool>(json['isMe']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'meshId': serializer.toJson<int>(meshId),
      'conversationId': serializer.toJson<String>(conversationId),
      'fromNodeId': serializer.toJson<String>(fromNodeId),
      'messageText': serializer.toJson<String>(messageText),
      'time': serializer.toJson<DateTime>(time),
      'status': serializer.toJson<String>(status),
      'isMe': serializer.toJson<bool>(isMe),
    };
  }

  Message copyWith({
    int? id,
    int? meshId,
    String? conversationId,
    String? fromNodeId,
    String? messageText,
    DateTime? time,
    String? status,
    bool? isMe,
  }) => Message(
    id: id ?? this.id,
    meshId: meshId ?? this.meshId,
    conversationId: conversationId ?? this.conversationId,
    fromNodeId: fromNodeId ?? this.fromNodeId,
    messageText: messageText ?? this.messageText,
    time: time ?? this.time,
    status: status ?? this.status,
    isMe: isMe ?? this.isMe,
  );
  Message copyWithCompanion(MessagesCompanion data) {
    return Message(
      id: data.id.present ? data.id.value : this.id,
      meshId: data.meshId.present ? data.meshId.value : this.meshId,
      conversationId: data.conversationId.present
          ? data.conversationId.value
          : this.conversationId,
      fromNodeId: data.fromNodeId.present
          ? data.fromNodeId.value
          : this.fromNodeId,
      messageText: data.messageText.present
          ? data.messageText.value
          : this.messageText,
      time: data.time.present ? data.time.value : this.time,
      status: data.status.present ? data.status.value : this.status,
      isMe: data.isMe.present ? data.isMe.value : this.isMe,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Message(')
          ..write('id: $id, ')
          ..write('meshId: $meshId, ')
          ..write('conversationId: $conversationId, ')
          ..write('fromNodeId: $fromNodeId, ')
          ..write('messageText: $messageText, ')
          ..write('time: $time, ')
          ..write('status: $status, ')
          ..write('isMe: $isMe')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    meshId,
    conversationId,
    fromNodeId,
    messageText,
    time,
    status,
    isMe,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Message &&
          other.id == this.id &&
          other.meshId == this.meshId &&
          other.conversationId == this.conversationId &&
          other.fromNodeId == this.fromNodeId &&
          other.messageText == this.messageText &&
          other.time == this.time &&
          other.status == this.status &&
          other.isMe == this.isMe);
}

class MessagesCompanion extends UpdateCompanion<Message> {
  final Value<int> id;
  final Value<int> meshId;
  final Value<String> conversationId;
  final Value<String> fromNodeId;
  final Value<String> messageText;
  final Value<DateTime> time;
  final Value<String> status;
  final Value<bool> isMe;
  const MessagesCompanion({
    this.id = const Value.absent(),
    this.meshId = const Value.absent(),
    this.conversationId = const Value.absent(),
    this.fromNodeId = const Value.absent(),
    this.messageText = const Value.absent(),
    this.time = const Value.absent(),
    this.status = const Value.absent(),
    this.isMe = const Value.absent(),
  });
  MessagesCompanion.insert({
    this.id = const Value.absent(),
    required int meshId,
    required String conversationId,
    required String fromNodeId,
    required String messageText,
    required DateTime time,
    required String status,
    required bool isMe,
  }) : meshId = Value(meshId),
       conversationId = Value(conversationId),
       fromNodeId = Value(fromNodeId),
       messageText = Value(messageText),
       time = Value(time),
       status = Value(status),
       isMe = Value(isMe);
  static Insertable<Message> custom({
    Expression<int>? id,
    Expression<int>? meshId,
    Expression<String>? conversationId,
    Expression<String>? fromNodeId,
    Expression<String>? messageText,
    Expression<DateTime>? time,
    Expression<String>? status,
    Expression<bool>? isMe,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (meshId != null) 'mesh_id': meshId,
      if (conversationId != null) 'conversation_id': conversationId,
      if (fromNodeId != null) 'from_node_id': fromNodeId,
      if (messageText != null) 'text': messageText,
      if (time != null) 'time': time,
      if (status != null) 'status': status,
      if (isMe != null) 'is_me': isMe,
    });
  }

  MessagesCompanion copyWith({
    Value<int>? id,
    Value<int>? meshId,
    Value<String>? conversationId,
    Value<String>? fromNodeId,
    Value<String>? messageText,
    Value<DateTime>? time,
    Value<String>? status,
    Value<bool>? isMe,
  }) {
    return MessagesCompanion(
      id: id ?? this.id,
      meshId: meshId ?? this.meshId,
      conversationId: conversationId ?? this.conversationId,
      fromNodeId: fromNodeId ?? this.fromNodeId,
      messageText: messageText ?? this.messageText,
      time: time ?? this.time,
      status: status ?? this.status,
      isMe: isMe ?? this.isMe,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (meshId.present) {
      map['mesh_id'] = Variable<int>(meshId.value);
    }
    if (conversationId.present) {
      map['conversation_id'] = Variable<String>(conversationId.value);
    }
    if (fromNodeId.present) {
      map['from_node_id'] = Variable<String>(fromNodeId.value);
    }
    if (messageText.present) {
      map['text'] = Variable<String>(messageText.value);
    }
    if (time.present) {
      map['time'] = Variable<DateTime>(time.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (isMe.present) {
      map['is_me'] = Variable<bool>(isMe.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('MessagesCompanion(')
          ..write('id: $id, ')
          ..write('meshId: $meshId, ')
          ..write('conversationId: $conversationId, ')
          ..write('fromNodeId: $fromNodeId, ')
          ..write('messageText: $messageText, ')
          ..write('time: $time, ')
          ..write('status: $status, ')
          ..write('isMe: $isMe')
          ..write(')'))
        .toString();
  }
}

class $BlockedNodesTable extends BlockedNodes
    with TableInfo<$BlockedNodesTable, BlockedNode> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $BlockedNodesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _nodeIdMeta = const VerificationMeta('nodeId');
  @override
  late final GeneratedColumn<String> nodeId = GeneratedColumn<String>(
    'node_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [nodeId];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'blocked_nodes';
  @override
  VerificationContext validateIntegrity(
    Insertable<BlockedNode> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('node_id')) {
      context.handle(
        _nodeIdMeta,
        nodeId.isAcceptableOrUnknown(data['node_id']!, _nodeIdMeta),
      );
    } else if (isInserting) {
      context.missing(_nodeIdMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {nodeId};
  @override
  BlockedNode map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return BlockedNode(
      nodeId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}node_id'],
      )!,
    );
  }

  @override
  $BlockedNodesTable createAlias(String alias) {
    return $BlockedNodesTable(attachedDatabase, alias);
  }
}

class BlockedNode extends DataClass implements Insertable<BlockedNode> {
  final String nodeId;
  const BlockedNode({required this.nodeId});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['node_id'] = Variable<String>(nodeId);
    return map;
  }

  BlockedNodesCompanion toCompanion(bool nullToAbsent) {
    return BlockedNodesCompanion(nodeId: Value(nodeId));
  }

  factory BlockedNode.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return BlockedNode(nodeId: serializer.fromJson<String>(json['nodeId']));
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{'nodeId': serializer.toJson<String>(nodeId)};
  }

  BlockedNode copyWith({String? nodeId}) =>
      BlockedNode(nodeId: nodeId ?? this.nodeId);
  BlockedNode copyWithCompanion(BlockedNodesCompanion data) {
    return BlockedNode(
      nodeId: data.nodeId.present ? data.nodeId.value : this.nodeId,
    );
  }

  @override
  String toString() {
    return (StringBuffer('BlockedNode(')
          ..write('nodeId: $nodeId')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => nodeId.hashCode;
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is BlockedNode && other.nodeId == this.nodeId);
}

class BlockedNodesCompanion extends UpdateCompanion<BlockedNode> {
  final Value<String> nodeId;
  final Value<int> rowid;
  const BlockedNodesCompanion({
    this.nodeId = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  BlockedNodesCompanion.insert({
    required String nodeId,
    this.rowid = const Value.absent(),
  }) : nodeId = Value(nodeId);
  static Insertable<BlockedNode> custom({
    Expression<String>? nodeId,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (nodeId != null) 'node_id': nodeId,
      if (rowid != null) 'rowid': rowid,
    });
  }

  BlockedNodesCompanion copyWith({Value<String>? nodeId, Value<int>? rowid}) {
    return BlockedNodesCompanion(
      nodeId: nodeId ?? this.nodeId,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (nodeId.present) {
      map['node_id'] = Variable<String>(nodeId.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('BlockedNodesCompanion(')
          ..write('nodeId: $nodeId, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $ContactsTable contacts = $ContactsTable(this);
  late final $ChannelsTable channels = $ChannelsTable(this);
  late final $ConversationsTable conversations = $ConversationsTable(this);
  late final $MessagesTable messages = $MessagesTable(this);
  late final $BlockedNodesTable blockedNodes = $BlockedNodesTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    contacts,
    channels,
    conversations,
    messages,
    blockedNodes,
  ];
}

typedef $$ContactsTableCreateCompanionBuilder =
    ContactsCompanion Function({
      required String nodeId,
      required String displayName,
      Value<String?> avatarEmoji,
      Value<Uint8List?> publicKey,
      required DateTime addedAt,
      Value<int> rowid,
    });
typedef $$ContactsTableUpdateCompanionBuilder =
    ContactsCompanion Function({
      Value<String> nodeId,
      Value<String> displayName,
      Value<String?> avatarEmoji,
      Value<Uint8List?> publicKey,
      Value<DateTime> addedAt,
      Value<int> rowid,
    });

class $$ContactsTableFilterComposer
    extends Composer<_$AppDatabase, $ContactsTable> {
  $$ContactsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get nodeId => $composableBuilder(
    column: $table.nodeId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get displayName => $composableBuilder(
    column: $table.displayName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get avatarEmoji => $composableBuilder(
    column: $table.avatarEmoji,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<Uint8List> get publicKey => $composableBuilder(
    column: $table.publicKey,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get addedAt => $composableBuilder(
    column: $table.addedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$ContactsTableOrderingComposer
    extends Composer<_$AppDatabase, $ContactsTable> {
  $$ContactsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get nodeId => $composableBuilder(
    column: $table.nodeId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get displayName => $composableBuilder(
    column: $table.displayName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get avatarEmoji => $composableBuilder(
    column: $table.avatarEmoji,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<Uint8List> get publicKey => $composableBuilder(
    column: $table.publicKey,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get addedAt => $composableBuilder(
    column: $table.addedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ContactsTableAnnotationComposer
    extends Composer<_$AppDatabase, $ContactsTable> {
  $$ContactsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get nodeId =>
      $composableBuilder(column: $table.nodeId, builder: (column) => column);

  GeneratedColumn<String> get displayName => $composableBuilder(
    column: $table.displayName,
    builder: (column) => column,
  );

  GeneratedColumn<String> get avatarEmoji => $composableBuilder(
    column: $table.avatarEmoji,
    builder: (column) => column,
  );

  GeneratedColumn<Uint8List> get publicKey =>
      $composableBuilder(column: $table.publicKey, builder: (column) => column);

  GeneratedColumn<DateTime> get addedAt =>
      $composableBuilder(column: $table.addedAt, builder: (column) => column);
}

class $$ContactsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ContactsTable,
          Contact,
          $$ContactsTableFilterComposer,
          $$ContactsTableOrderingComposer,
          $$ContactsTableAnnotationComposer,
          $$ContactsTableCreateCompanionBuilder,
          $$ContactsTableUpdateCompanionBuilder,
          (Contact, BaseReferences<_$AppDatabase, $ContactsTable, Contact>),
          Contact,
          PrefetchHooks Function()
        > {
  $$ContactsTableTableManager(_$AppDatabase db, $ContactsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ContactsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ContactsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ContactsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> nodeId = const Value.absent(),
                Value<String> displayName = const Value.absent(),
                Value<String?> avatarEmoji = const Value.absent(),
                Value<Uint8List?> publicKey = const Value.absent(),
                Value<DateTime> addedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ContactsCompanion(
                nodeId: nodeId,
                displayName: displayName,
                avatarEmoji: avatarEmoji,
                publicKey: publicKey,
                addedAt: addedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String nodeId,
                required String displayName,
                Value<String?> avatarEmoji = const Value.absent(),
                Value<Uint8List?> publicKey = const Value.absent(),
                required DateTime addedAt,
                Value<int> rowid = const Value.absent(),
              }) => ContactsCompanion.insert(
                nodeId: nodeId,
                displayName: displayName,
                avatarEmoji: avatarEmoji,
                publicKey: publicKey,
                addedAt: addedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$ContactsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ContactsTable,
      Contact,
      $$ContactsTableFilterComposer,
      $$ContactsTableOrderingComposer,
      $$ContactsTableAnnotationComposer,
      $$ContactsTableCreateCompanionBuilder,
      $$ContactsTableUpdateCompanionBuilder,
      (Contact, BaseReferences<_$AppDatabase, $ContactsTable, Contact>),
      Contact,
      PrefetchHooks Function()
    >;
typedef $$ChannelsTableCreateCompanionBuilder =
    ChannelsCompanion Function({
      required String id,
      required String name,
      Value<String?> avatarEmoji,
      required Uint8List psk,
      required int slotIndex,
      required DateTime createdAt,
      Value<int> rowid,
    });
typedef $$ChannelsTableUpdateCompanionBuilder =
    ChannelsCompanion Function({
      Value<String> id,
      Value<String> name,
      Value<String?> avatarEmoji,
      Value<Uint8List> psk,
      Value<int> slotIndex,
      Value<DateTime> createdAt,
      Value<int> rowid,
    });

class $$ChannelsTableFilterComposer
    extends Composer<_$AppDatabase, $ChannelsTable> {
  $$ChannelsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get avatarEmoji => $composableBuilder(
    column: $table.avatarEmoji,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<Uint8List> get psk => $composableBuilder(
    column: $table.psk,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get slotIndex => $composableBuilder(
    column: $table.slotIndex,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$ChannelsTableOrderingComposer
    extends Composer<_$AppDatabase, $ChannelsTable> {
  $$ChannelsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get avatarEmoji => $composableBuilder(
    column: $table.avatarEmoji,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<Uint8List> get psk => $composableBuilder(
    column: $table.psk,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get slotIndex => $composableBuilder(
    column: $table.slotIndex,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ChannelsTableAnnotationComposer
    extends Composer<_$AppDatabase, $ChannelsTable> {
  $$ChannelsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get avatarEmoji => $composableBuilder(
    column: $table.avatarEmoji,
    builder: (column) => column,
  );

  GeneratedColumn<Uint8List> get psk =>
      $composableBuilder(column: $table.psk, builder: (column) => column);

  GeneratedColumn<int> get slotIndex =>
      $composableBuilder(column: $table.slotIndex, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);
}

class $$ChannelsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ChannelsTable,
          Channel,
          $$ChannelsTableFilterComposer,
          $$ChannelsTableOrderingComposer,
          $$ChannelsTableAnnotationComposer,
          $$ChannelsTableCreateCompanionBuilder,
          $$ChannelsTableUpdateCompanionBuilder,
          (Channel, BaseReferences<_$AppDatabase, $ChannelsTable, Channel>),
          Channel,
          PrefetchHooks Function()
        > {
  $$ChannelsTableTableManager(_$AppDatabase db, $ChannelsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ChannelsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ChannelsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ChannelsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String?> avatarEmoji = const Value.absent(),
                Value<Uint8List> psk = const Value.absent(),
                Value<int> slotIndex = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ChannelsCompanion(
                id: id,
                name: name,
                avatarEmoji: avatarEmoji,
                psk: psk,
                slotIndex: slotIndex,
                createdAt: createdAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String name,
                Value<String?> avatarEmoji = const Value.absent(),
                required Uint8List psk,
                required int slotIndex,
                required DateTime createdAt,
                Value<int> rowid = const Value.absent(),
              }) => ChannelsCompanion.insert(
                id: id,
                name: name,
                avatarEmoji: avatarEmoji,
                psk: psk,
                slotIndex: slotIndex,
                createdAt: createdAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$ChannelsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ChannelsTable,
      Channel,
      $$ChannelsTableFilterComposer,
      $$ChannelsTableOrderingComposer,
      $$ChannelsTableAnnotationComposer,
      $$ChannelsTableCreateCompanionBuilder,
      $$ChannelsTableUpdateCompanionBuilder,
      (Channel, BaseReferences<_$AppDatabase, $ChannelsTable, Channel>),
      Channel,
      PrefetchHooks Function()
    >;
typedef $$ConversationsTableCreateCompanionBuilder =
    ConversationsCompanion Function({
      required String id,
      required String type,
      Value<String?> peerId,
      Value<String?> channelId,
      Value<int> unreadCount,
      Value<bool> iCanReadPeer,
      Value<bool> peerCanReadUs,
      Value<bool> writeAnyway,
      required DateTime updatedAt,
      Value<int> rowid,
    });
typedef $$ConversationsTableUpdateCompanionBuilder =
    ConversationsCompanion Function({
      Value<String> id,
      Value<String> type,
      Value<String?> peerId,
      Value<String?> channelId,
      Value<int> unreadCount,
      Value<bool> iCanReadPeer,
      Value<bool> peerCanReadUs,
      Value<bool> writeAnyway,
      Value<DateTime> updatedAt,
      Value<int> rowid,
    });

class $$ConversationsTableFilterComposer
    extends Composer<_$AppDatabase, $ConversationsTable> {
  $$ConversationsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get peerId => $composableBuilder(
    column: $table.peerId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get channelId => $composableBuilder(
    column: $table.channelId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get unreadCount => $composableBuilder(
    column: $table.unreadCount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get iCanReadPeer => $composableBuilder(
    column: $table.iCanReadPeer,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get peerCanReadUs => $composableBuilder(
    column: $table.peerCanReadUs,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get writeAnyway => $composableBuilder(
    column: $table.writeAnyway,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$ConversationsTableOrderingComposer
    extends Composer<_$AppDatabase, $ConversationsTable> {
  $$ConversationsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get peerId => $composableBuilder(
    column: $table.peerId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get channelId => $composableBuilder(
    column: $table.channelId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get unreadCount => $composableBuilder(
    column: $table.unreadCount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get iCanReadPeer => $composableBuilder(
    column: $table.iCanReadPeer,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get peerCanReadUs => $composableBuilder(
    column: $table.peerCanReadUs,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get writeAnyway => $composableBuilder(
    column: $table.writeAnyway,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ConversationsTableAnnotationComposer
    extends Composer<_$AppDatabase, $ConversationsTable> {
  $$ConversationsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get type =>
      $composableBuilder(column: $table.type, builder: (column) => column);

  GeneratedColumn<String> get peerId =>
      $composableBuilder(column: $table.peerId, builder: (column) => column);

  GeneratedColumn<String> get channelId =>
      $composableBuilder(column: $table.channelId, builder: (column) => column);

  GeneratedColumn<int> get unreadCount => $composableBuilder(
    column: $table.unreadCount,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get iCanReadPeer => $composableBuilder(
    column: $table.iCanReadPeer,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get peerCanReadUs => $composableBuilder(
    column: $table.peerCanReadUs,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get writeAnyway => $composableBuilder(
    column: $table.writeAnyway,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$ConversationsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ConversationsTable,
          Conversation,
          $$ConversationsTableFilterComposer,
          $$ConversationsTableOrderingComposer,
          $$ConversationsTableAnnotationComposer,
          $$ConversationsTableCreateCompanionBuilder,
          $$ConversationsTableUpdateCompanionBuilder,
          (
            Conversation,
            BaseReferences<_$AppDatabase, $ConversationsTable, Conversation>,
          ),
          Conversation,
          PrefetchHooks Function()
        > {
  $$ConversationsTableTableManager(_$AppDatabase db, $ConversationsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ConversationsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ConversationsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ConversationsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> type = const Value.absent(),
                Value<String?> peerId = const Value.absent(),
                Value<String?> channelId = const Value.absent(),
                Value<int> unreadCount = const Value.absent(),
                Value<bool> iCanReadPeer = const Value.absent(),
                Value<bool> peerCanReadUs = const Value.absent(),
                Value<bool> writeAnyway = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ConversationsCompanion(
                id: id,
                type: type,
                peerId: peerId,
                channelId: channelId,
                unreadCount: unreadCount,
                iCanReadPeer: iCanReadPeer,
                peerCanReadUs: peerCanReadUs,
                writeAnyway: writeAnyway,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String type,
                Value<String?> peerId = const Value.absent(),
                Value<String?> channelId = const Value.absent(),
                Value<int> unreadCount = const Value.absent(),
                Value<bool> iCanReadPeer = const Value.absent(),
                Value<bool> peerCanReadUs = const Value.absent(),
                Value<bool> writeAnyway = const Value.absent(),
                required DateTime updatedAt,
                Value<int> rowid = const Value.absent(),
              }) => ConversationsCompanion.insert(
                id: id,
                type: type,
                peerId: peerId,
                channelId: channelId,
                unreadCount: unreadCount,
                iCanReadPeer: iCanReadPeer,
                peerCanReadUs: peerCanReadUs,
                writeAnyway: writeAnyway,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$ConversationsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ConversationsTable,
      Conversation,
      $$ConversationsTableFilterComposer,
      $$ConversationsTableOrderingComposer,
      $$ConversationsTableAnnotationComposer,
      $$ConversationsTableCreateCompanionBuilder,
      $$ConversationsTableUpdateCompanionBuilder,
      (
        Conversation,
        BaseReferences<_$AppDatabase, $ConversationsTable, Conversation>,
      ),
      Conversation,
      PrefetchHooks Function()
    >;
typedef $$MessagesTableCreateCompanionBuilder =
    MessagesCompanion Function({
      Value<int> id,
      required int meshId,
      required String conversationId,
      required String fromNodeId,
      required String messageText,
      required DateTime time,
      required String status,
      required bool isMe,
    });
typedef $$MessagesTableUpdateCompanionBuilder =
    MessagesCompanion Function({
      Value<int> id,
      Value<int> meshId,
      Value<String> conversationId,
      Value<String> fromNodeId,
      Value<String> messageText,
      Value<DateTime> time,
      Value<String> status,
      Value<bool> isMe,
    });

class $$MessagesTableFilterComposer
    extends Composer<_$AppDatabase, $MessagesTable> {
  $$MessagesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get meshId => $composableBuilder(
    column: $table.meshId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get conversationId => $composableBuilder(
    column: $table.conversationId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get fromNodeId => $composableBuilder(
    column: $table.fromNodeId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get messageText => $composableBuilder(
    column: $table.messageText,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get time => $composableBuilder(
    column: $table.time,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isMe => $composableBuilder(
    column: $table.isMe,
    builder: (column) => ColumnFilters(column),
  );
}

class $$MessagesTableOrderingComposer
    extends Composer<_$AppDatabase, $MessagesTable> {
  $$MessagesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get meshId => $composableBuilder(
    column: $table.meshId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get conversationId => $composableBuilder(
    column: $table.conversationId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get fromNodeId => $composableBuilder(
    column: $table.fromNodeId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get messageText => $composableBuilder(
    column: $table.messageText,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get time => $composableBuilder(
    column: $table.time,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isMe => $composableBuilder(
    column: $table.isMe,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$MessagesTableAnnotationComposer
    extends Composer<_$AppDatabase, $MessagesTable> {
  $$MessagesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get meshId =>
      $composableBuilder(column: $table.meshId, builder: (column) => column);

  GeneratedColumn<String> get conversationId => $composableBuilder(
    column: $table.conversationId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get fromNodeId => $composableBuilder(
    column: $table.fromNodeId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get messageText => $composableBuilder(
    column: $table.messageText,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get time =>
      $composableBuilder(column: $table.time, builder: (column) => column);

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<bool> get isMe =>
      $composableBuilder(column: $table.isMe, builder: (column) => column);
}

class $$MessagesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $MessagesTable,
          Message,
          $$MessagesTableFilterComposer,
          $$MessagesTableOrderingComposer,
          $$MessagesTableAnnotationComposer,
          $$MessagesTableCreateCompanionBuilder,
          $$MessagesTableUpdateCompanionBuilder,
          (Message, BaseReferences<_$AppDatabase, $MessagesTable, Message>),
          Message,
          PrefetchHooks Function()
        > {
  $$MessagesTableTableManager(_$AppDatabase db, $MessagesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$MessagesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$MessagesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$MessagesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int> meshId = const Value.absent(),
                Value<String> conversationId = const Value.absent(),
                Value<String> fromNodeId = const Value.absent(),
                Value<String> messageText = const Value.absent(),
                Value<DateTime> time = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<bool> isMe = const Value.absent(),
              }) => MessagesCompanion(
                id: id,
                meshId: meshId,
                conversationId: conversationId,
                fromNodeId: fromNodeId,
                messageText: messageText,
                time: time,
                status: status,
                isMe: isMe,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required int meshId,
                required String conversationId,
                required String fromNodeId,
                required String messageText,
                required DateTime time,
                required String status,
                required bool isMe,
              }) => MessagesCompanion.insert(
                id: id,
                meshId: meshId,
                conversationId: conversationId,
                fromNodeId: fromNodeId,
                messageText: messageText,
                time: time,
                status: status,
                isMe: isMe,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$MessagesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $MessagesTable,
      Message,
      $$MessagesTableFilterComposer,
      $$MessagesTableOrderingComposer,
      $$MessagesTableAnnotationComposer,
      $$MessagesTableCreateCompanionBuilder,
      $$MessagesTableUpdateCompanionBuilder,
      (Message, BaseReferences<_$AppDatabase, $MessagesTable, Message>),
      Message,
      PrefetchHooks Function()
    >;
typedef $$BlockedNodesTableCreateCompanionBuilder =
    BlockedNodesCompanion Function({required String nodeId, Value<int> rowid});
typedef $$BlockedNodesTableUpdateCompanionBuilder =
    BlockedNodesCompanion Function({Value<String> nodeId, Value<int> rowid});

class $$BlockedNodesTableFilterComposer
    extends Composer<_$AppDatabase, $BlockedNodesTable> {
  $$BlockedNodesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get nodeId => $composableBuilder(
    column: $table.nodeId,
    builder: (column) => ColumnFilters(column),
  );
}

class $$BlockedNodesTableOrderingComposer
    extends Composer<_$AppDatabase, $BlockedNodesTable> {
  $$BlockedNodesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get nodeId => $composableBuilder(
    column: $table.nodeId,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$BlockedNodesTableAnnotationComposer
    extends Composer<_$AppDatabase, $BlockedNodesTable> {
  $$BlockedNodesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get nodeId =>
      $composableBuilder(column: $table.nodeId, builder: (column) => column);
}

class $$BlockedNodesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $BlockedNodesTable,
          BlockedNode,
          $$BlockedNodesTableFilterComposer,
          $$BlockedNodesTableOrderingComposer,
          $$BlockedNodesTableAnnotationComposer,
          $$BlockedNodesTableCreateCompanionBuilder,
          $$BlockedNodesTableUpdateCompanionBuilder,
          (
            BlockedNode,
            BaseReferences<_$AppDatabase, $BlockedNodesTable, BlockedNode>,
          ),
          BlockedNode,
          PrefetchHooks Function()
        > {
  $$BlockedNodesTableTableManager(_$AppDatabase db, $BlockedNodesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$BlockedNodesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$BlockedNodesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$BlockedNodesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> nodeId = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => BlockedNodesCompanion(nodeId: nodeId, rowid: rowid),
          createCompanionCallback:
              ({
                required String nodeId,
                Value<int> rowid = const Value.absent(),
              }) => BlockedNodesCompanion.insert(nodeId: nodeId, rowid: rowid),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$BlockedNodesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $BlockedNodesTable,
      BlockedNode,
      $$BlockedNodesTableFilterComposer,
      $$BlockedNodesTableOrderingComposer,
      $$BlockedNodesTableAnnotationComposer,
      $$BlockedNodesTableCreateCompanionBuilder,
      $$BlockedNodesTableUpdateCompanionBuilder,
      (
        BlockedNode,
        BaseReferences<_$AppDatabase, $BlockedNodesTable, BlockedNode>,
      ),
      BlockedNode,
      PrefetchHooks Function()
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$ContactsTableTableManager get contacts =>
      $$ContactsTableTableManager(_db, _db.contacts);
  $$ChannelsTableTableManager get channels =>
      $$ChannelsTableTableManager(_db, _db.channels);
  $$ConversationsTableTableManager get conversations =>
      $$ConversationsTableTableManager(_db, _db.conversations);
  $$MessagesTableTableManager get messages =>
      $$MessagesTableTableManager(_db, _db.messages);
  $$BlockedNodesTableTableManager get blockedNodes =>
      $$BlockedNodesTableTableManager(_db, _db.blockedNodes);
}
