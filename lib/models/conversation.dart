import 'package:meshly/models/message.dart';

enum ConversationType { dm, channel }

class Conversation {
  Conversation({
    required this.id,
    required this.type,
    this.peerId,
    this.channelId,
    this.lastMessage,
    this.unreadCount = 0,
    DateTime? updatedAt,
  }) : updatedAt = updatedAt ?? DateTime.now();

  factory Conversation.fromJson(Map<String, dynamic> j) => Conversation(
    id: j['id'] as String,
    type: ConversationType.values.byName(j['type'] as String),
    peerId: j['peerId'] as String?,
    channelId: j['channelId'] as String?,
    lastMessage: j['lastMessage'] != null
        ? Message.fromJson(j['lastMessage'] as Map<String, dynamic>)
        : null,
    unreadCount: j['unreadCount'] as int,
    updatedAt: DateTime.parse(j['updatedAt'] as String),
  );

  // Фабрики для удобного создания
  factory Conversation.dm(String nodeId) => Conversation(
    id: 'dm_$nodeId',
    type: ConversationType.dm,
    peerId: nodeId,
  );

  factory Conversation.channel(String channelId) => Conversation(
    id: 'ch_$channelId',
    type: ConversationType.channel,
    channelId: channelId,
  );

  final String id;
  final ConversationType type;

  // dm: peerId = nodeId контакта ('!1f8e42c9')
  // channel: channelId = MeshChannel.id (локальный uuid)
  final String? peerId;
  final String? channelId;

  Message? lastMessage;
  int unreadCount;
  DateTime updatedAt;

  bool get isDm => type == ConversationType.dm;
  bool get isChannel => type == ConversationType.channel;

  Map<String, dynamic> toJson() => {
    'id': id,
    'type': type.name,
    if (peerId != null) 'peerId': peerId,
    if (channelId != null) 'channelId': channelId,
    if (lastMessage != null) 'lastMessage': lastMessage!.toJson(),
    'unreadCount': unreadCount,
    'updatedAt': updatedAt.toIso8601String(),
  };
}
