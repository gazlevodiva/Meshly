import 'dart:convert';
import 'dart:typed_data';

class MeshChannel {
  MeshChannel({
    required this.id,
    required this.name,
    required this.psk,
    DateTime? createdAt,
    this.avatarEmoji,
  }) : createdAt = createdAt ?? DateTime.now();

  factory MeshChannel.fromJson(Map<String, dynamic> j) => MeshChannel(
    id: j['id'] as String,
    name: j['name'] as String,
    avatarEmoji: j['avatarEmoji'] as String?,
    psk: base64Decode(j['psk'] as String),
    createdAt: j['createdAt'] != null
        ? DateTime.parse(j['createdAt'] as String)
        : null,
  );

  final String id; // local uuid
  String name;
  String? avatarEmoji;
  Uint8List psk; // 32 bytes
  // The moment the conversation was created — the conversation list is
  // sorted by it. There is no more Meshtastic hardware slot in the model:
  // it was never actually configured on the device (encodeSetChannel was
  // broken), and on receive the conversation is determined by trying PSKs
  // one by one (see the "decouple conversations from slots" sprint report).
  // The Channels.slotIndex column in the DB remains (NOT NULL, we're not
  // changing the schema) — 0 is now always written into it, see
  // ContactStore.createChannel.
  final DateTime createdAt;

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    if (avatarEmoji != null) 'avatarEmoji': avatarEmoji,
    'psk': base64Encode(psk),
    'createdAt': createdAt.toIso8601String(),
  };
}
