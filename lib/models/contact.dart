import 'dart:convert';
import 'dart:typed_data';

/// Max length, in Unicode code points, of a person's display name — the one
/// limit for the whole app. Enforced wherever a name is typed (the "My
/// contact" screen, onboarding's name step) so that what a person sets for
/// themselves, what gets stored, and what a join/leave announcement carries
/// (`encodeSystemEvent` in `message.dart`, which caps to this same value)
/// can never drift apart. A name that fits here is guaranteed to reach an
/// announcement without silent truncation.
///
/// Was `kSystemEventNameMaxLength` in `message.dart`, sized for the LoRa
/// text budget (~200 bytes) of an announcement packet. It moved here
/// because it now governs the field itself, not just one wire format that
/// reads it.
const kDisplayNameMaxLength = 32;

/// Cleans a raw, user-typed display name before it is stored: flattens
/// newlines and other control characters to spaces (the same treatment
/// `encodeSystemEvent` in `message.dart` gives an announcement — a
/// centred system line one control character away from exploding to full
/// height or hiding text behind a fake line break), trims the result, and
/// caps it at [kDisplayNameMaxLength] Unicode code points (not UTF-16 code
/// units, so an emoji's surrogate pair is never split).
///
/// Idempotent, and stable under `encodeSystemEvent`: because it already
/// caps and flattens, running an already-sanitized name through
/// `encodeSystemEvent` reproduces it unchanged, so what a person sees
/// stored for themselves is exactly what an announcement carries — no
/// separate truncation happens later, silently, on the wire.
String sanitizeDisplayName(String raw) {
  final flattened = raw.trim().replaceAll(RegExp(r'[\x00-\x1f\x7f]'), ' ');
  return String.fromCharCodes(flattened.runes.take(kDisplayNameMaxLength));
}

class Contact {
  Contact({
    required this.nodeId,
    required this.displayName,
    this.avatarEmoji,
    this.publicKey,
    DateTime? addedAt,
  }) : addedAt = addedAt ?? DateTime.now();

  factory Contact.fromJson(Map<String, dynamic> j) => Contact(
    nodeId: j['nodeId'] as String,
    displayName: j['displayName'] as String,
    avatarEmoji: j['avatarEmoji'] as String?,
    publicKey: j['publicKey'] != null
        ? base64Decode(j['publicKey'] as String)
        : null,
    addedAt: DateTime.parse(j['addedAt'] as String),
  );

  final String nodeId; // '!1f8e42c9'
  String displayName;
  String? avatarEmoji;
  // Peer's X25519 public key (32 bytes), used for E2E DM encryption. Null
  // until exchanged via QR (or added later some other way).
  Uint8List? publicKey;
  DateTime addedAt;

  Map<String, dynamic> toJson() => {
    'nodeId': nodeId,
    'displayName': displayName,
    if (avatarEmoji != null) 'avatarEmoji': avatarEmoji,
    if (publicKey != null) 'publicKey': base64Encode(publicKey!),
    'addedAt': addedAt.toIso8601String(),
  };

  String get displayLabel =>
      avatarEmoji != null ? '$avatarEmoji $displayName' : displayName;
}
