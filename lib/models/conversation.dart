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
    this.iCanReadPeer = true,
    this.peerCanReadUs = true,
    this.writeAnyway = false,
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
    iCanReadPeer: j['iCanReadPeer'] as bool? ?? true,
    peerCanReadUs: j['peerCanReadUs'] as bool? ?? true,
    writeAnyway: j['writeAnyway'] as bool? ?? false,
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

  /// We hold the peer's current public key → we can read what they send.
  ///
  /// Starts out `true` (optimistic): the very first packet we fail to decrypt
  /// flips it to `false`. Only two things ever set it: decryption results
  /// (proof) and a QR scan of the peer (optimistic — a stale QR self-corrects
  /// on the next unreadable packet).
  bool iCanReadPeer;

  /// The peer holds *our* current public key → they can read what we send.
  ///
  /// Set from proof (anything of theirs that decrypts also proves they
  /// encrypted to our current key — ECDH is symmetric) or from unauthenticated
  /// hints (their verify ping, their `[0x02]` "I cannot read you" notice).
  bool peerCanReadUs;

  /// The user pressed "write anyway" in this chat while it was flagged broken.
  ///
  /// Persisted on purpose. The breakage signal is unauthenticated — anyone in
  /// range can forge a `[0x02]` — so a per-visit escape hatch meant the chat
  /// re-blocked itself every time the user left and came back.
  ///
  /// Cleared by any transition into a healthy state (both halves true),
  /// whichever flag causes it — a re-scanned QR sets only one half, and the
  /// override used to survive that and swallow the next genuine breakage. So
  /// this flag provably means "this chat is broken right now".
  bool writeAnyway;

  DateTime updatedAt;

  bool get isDm => type == ConversationType.dm;
  bool get isChannel => type == ConversationType.channel;

  /// The single source of truth for "the secure chat works": both directions
  /// are readable. Everything user-visible (the recovery card, the chat-list
  /// hint, the send block) derives from this — nothing re-derives it.
  bool get secureOk => iCanReadPeer && peerCanReadUs;

  Map<String, dynamic> toJson() => {
    'id': id,
    'type': type.name,
    if (peerId != null) 'peerId': peerId,
    if (channelId != null) 'channelId': channelId,
    if (lastMessage != null) 'lastMessage': lastMessage!.toJson(),
    'unreadCount': unreadCount,
    'iCanReadPeer': iCanReadPeer,
    'peerCanReadUs': peerCanReadUs,
    'writeAnyway': writeAnyway,
    'updatedAt': updatedAt.toIso8601String(),
  };
}
