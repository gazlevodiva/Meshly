import 'dart:convert';
import 'dart:typed_data';

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
