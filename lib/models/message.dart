import 'package:meshly/models/contact.dart'
    show kDisplayNameMaxLength, sanitizeDisplayName;

/// Placeholder text of an incoming DM that could not be decrypted. Newly
/// received unreadable DMs are no longer stored at all (the conversation is
/// flagged broken instead) — this only matches leftovers written by earlier
/// versions, which `ContactStore.deleteUndecryptableMessages` cleans up.
///
/// Lives in the model layer so the store can reference it without importing
/// the BLE service; `mesh_service.dart` re-exports it for existing callers.
const kUndecryptableSentinel = ' meshly:undecryptable';

enum MessageStatus { sending, sent, acked, failed }

/// A conversation control event a member can announce: they joined (scanned
/// the QR) or left (deleted the conversation locally). See
/// `encodeSystemEvent`/`decodeSystemEvent` below for the wire format.
enum SystemEventKind {
  joined,
  left;

  /// The literal used in the wire format (see [encodeSystemEvent]) — same as
  /// [name], spelled out so callers don't have to reason about whether
  /// Dart's enum `.name` is part of the wire contract or just a coincidence.
  String get wireName => name;
}

/// Wire prefix that marks a decrypted broadcast plaintext as a join/leave
/// announcement instead of an ordinary message.
///
/// SECURITY / DESIGN: this lives in the *plaintext*, not as a distinct outer
/// packet type. From outside the encrypted envelope, an announcement is
/// byte-for-byte indistinguishable from an ordinary conversation broadcast
/// (same portnum, same channel, same envelope version) — a separate marker
/// byte on the wire would let an eavesdropper count who joins a conversation
/// and when, exactly the metadata leak Meshly just removed by decoupling
/// conversations from hardware slots. See CLAUDE.md → "Conversations are not
/// hardware channel slots" and this sprint's brief.
///
/// The prefix cannot be typed at all — see the NUL byte on
/// [_systemEventPrefix]. No
/// human-readable fallback sentence is appended (see the sprint brief) — an
/// older build renders the raw plaintext as a strange-looking message, which
/// is accepted since both sides already need to be on the current protocol
/// version for conversations to work at all (see the hardware-slot removal).
/// A NUL byte opens every announcement. This is what keeps an ordinary
/// message from ever being read as one: a text field cannot produce U+0000,
/// so no text a person can type will decode as an event.
///
/// That matters because the sender and the receivers would otherwise see
/// different things — the author's own copy renders as the plain message
/// they typed, while every other device renders it as a centred system
/// line that reads as if the app itself said it. Anyone in the
/// conversation could have forged an event by typing one message.
///
/// It does not stop a modified client: the conversation key is shared, so
/// a forged announcement remains possible for anyone willing to build one.
/// The bar is now "write your own app" rather than "type a message", and
/// SECURITY.md says so.
const _systemEventPrefix = '\u0000meshly:v1:';

/// Builds the plaintext for a join/leave announcement. [displayName] is run
/// through [sanitizeDisplayName], which caps it at [kDisplayNameMaxLength]
/// *code points* (not UTF-16 code units, so truncation cannot split a
/// surrogate pair, e.g. an emoji, in half) and flattens newlines/control
/// characters to spaces — the same limit that's enforced where a name is
/// typed (see `contact.dart`), so a name already stored as someone's
/// display name never gets truncated again, silently, here.
String encodeSystemEvent(SystemEventKind kind, String displayName) {
  final capped = sanitizeDisplayName(displayName);
  return '$_systemEventPrefix${kind.wireName}:$capped';
}

/// Parses plaintext decrypted from a channel broadcast as a join/leave
/// announcement. Returns null for anything that isn't a recognised,
/// well-formed announcement — an ordinary message that merely happens to
/// start with the prefix, a truncated packet, or an unknown kind — so the
/// caller can fall back to treating the plaintext as a regular message.
/// Never throws: every branch is a plain string check.
({SystemEventKind kind, String name})? decodeSystemEvent(String plaintext) {
  if (!plaintext.startsWith(_systemEventPrefix)) return null;
  final rest = plaintext.substring(_systemEventPrefix.length);
  final sep = rest.indexOf(':');
  if (sep < 0) return null;
  final wireName = rest.substring(0, sep);
  final name = rest.substring(sep + 1);
  if (name.isEmpty) return null;
  for (final kind in SystemEventKind.values) {
    if (kind.wireName == wireName) return (kind: kind, name: name);
  }
  return null;
}

class Message {
  Message({
    required this.meshId,
    required this.fromNodeId,
    required this.conversationId,
    required this.text,
    required this.time,
    required this.isMe,
    this.status = MessageStatus.sending,
    this.eventKind,
  });

  /// A stored join/leave system event. [announcedName] is kept in [text] —
  /// there's no separate column for it, see `app_database.dart`'s
  /// `Messages.eventKind` doc comment. Always [MessageStatus.acked]: this is
  /// a one-shot broadcast with no delivery tracking (see the sprint brief's
  /// "log of what this device saw, not a roster"), so there is no pending or
  /// failed state to represent.
  factory Message.systemEvent({
    required SystemEventKind kind,
    required String announcedName,
    required String fromNodeId,
    required String conversationId,
    required DateTime time,
    required bool isMe,
    int meshId = 0,
  }) => Message(
    meshId: meshId,
    fromNodeId: fromNodeId,
    conversationId: conversationId,
    text: announcedName,
    time: time,
    isMe: isMe,
    status: MessageStatus.acked,
    eventKind: kind,
  );

  factory Message.fromJson(Map<String, dynamic> j) => Message(
    meshId: j['meshId'] as int,
    fromNodeId: j['fromNodeId'] as String,
    conversationId: j['conversationId'] as String,
    text: j['text'] as String,
    time: DateTime.parse(j['time'] as String),
    isMe: j['isMe'] as bool,
    status: MessageStatus.values.byName(j['status'] as String),
    eventKind: j['eventKind'] == null
        ? null
        : SystemEventKind.values.byName(j['eventKind'] as String),
  );

  final int meshId; // packet id from MeshPacket field6
  final String fromNodeId; // '!1f8e42c9'
  final String conversationId;
  final String text;
  final DateTime time;
  MessageStatus status;
  final bool isMe;

  /// Non-null for a stored join/leave announcement (see [Message.systemEvent])
  /// — null for an ordinary person-to-person message. [text] holds the
  /// announced display name in that case, not message content.
  final SystemEventKind? eventKind;

  /// Whether this row is a system event (join/leave) rather than a message
  /// from a person. The future chat-UI sprint renders these inline with
  /// regular messages — see `ContactStore.messagesFor`.
  bool get isSystemEvent => eventKind != null;

  Message copyWith({MessageStatus? status}) => Message(
    meshId: meshId,
    fromNodeId: fromNodeId,
    conversationId: conversationId,
    text: text,
    time: time,
    isMe: isMe,
    status: status ?? this.status,
    eventKind: eventKind,
  );

  Map<String, dynamic> toJson() => {
    'meshId': meshId,
    'fromNodeId': fromNodeId,
    'conversationId': conversationId,
    'text': text,
    'time': time.toIso8601String(),
    'status': status.name,
    'isMe': isMe,
    if (eventKind != null) 'eventKind': eventKind!.name,
  };
}
