/// Placeholder text of an incoming DM that could not be decrypted. Newly
/// received unreadable DMs are no longer stored at all (the conversation is
/// flagged broken instead) — this only matches leftovers written by earlier
/// versions, which `ContactStore.deleteUndecryptableMessages` cleans up.
///
/// Lives in the model layer so the store can reference it without importing
/// the BLE service; `mesh_service.dart` re-exports it for existing callers.
const kUndecryptableSentinel = ' meshly:undecryptable';

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

  final int meshId; // packet id из MeshPacket field6
  final String fromNodeId; // '!1f8e42c9'
  final String conversationId;
  final String text;
  final DateTime time;
  MessageStatus status;
  final bool isMe;

  Message copyWith({MessageStatus? status}) => Message(
    meshId: meshId,
    fromNodeId: fromNodeId,
    conversationId: conversationId,
    text: text,
    time: time,
    isMe: isMe,
    status: status ?? this.status,
  );

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
