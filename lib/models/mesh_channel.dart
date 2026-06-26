import 'dart:convert';
import 'dart:typed_data';

class MeshChannel {
  final String id;        // локальный uuid
  String name;
  String? avatarEmoji;
  Uint8List psk;          // 32 bytes
  int slotIndex;          // 0–7, слот на девайсе

  MeshChannel({
    required this.id,
    required this.name,
    required this.psk,
    required this.slotIndex,
    this.avatarEmoji,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    if (avatarEmoji != null) 'avatarEmoji': avatarEmoji,
    'psk': base64Encode(psk),
    'slotIndex': slotIndex,
  };

  factory MeshChannel.fromJson(Map<String, dynamic> j) => MeshChannel(
    id: j['id'] as String,
    name: j['name'] as String,
    avatarEmoji: j['avatarEmoji'] as String?,
    psk: base64Decode(j['psk'] as String),
    slotIndex: j['slotIndex'] as int,
  );
}
