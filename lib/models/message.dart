enum MessageStatus { sending, sent, acked, failed }

class Message {
  Message({
    required this.meshId,
    required this.fromNodeId,
    required this.conversationId,
    required this.text,
    required this.time,
    required this.isMe,
    this.status = MessageStatus.sending,
  });

  factory Message.fromJson(Map<String, dynamic> j) => Message(
    meshId: j['meshId'] as int,
    fromNodeId: j['fromNodeId'] as String,
    conversationId: j['conversationId'] as String,
    text: j['text'] as String,
    time: DateTime.parse(j['time'] as String),
    isMe: j['isMe'] as bool,
    status: MessageStatus.values.byName(j['status'] as String),
  );

  final int meshId;           // packet id из MeshPacket field6
  final String fromNodeId;    // '!1f8e42c9'
  final String conversationId;
  final String text;
  final DateTime time;
  MessageStatus status;
  final bool isMe;

  Map<String, dynamic> toJson() => {
    'meshId': meshId,
    'fromNodeId': fromNodeId,
    'conversationId': conversationId,
    'text': text,
    'time': time.toIso8601String(),
    'status': status.name,
    'isMe': isMe,
  };
}
