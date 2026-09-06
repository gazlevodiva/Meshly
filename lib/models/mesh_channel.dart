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

  final String id; // локальный uuid
  String name;
  String? avatarEmoji;
  Uint8List psk; // 32 bytes
  // Момент создания беседы — по нему сортируется список бесед. Аппаратного
  // слота Meshtastic в модели больше нет: он и не настраивался в устройстве
  // (encodeSetChannel был сломан), а беседа на приёме определяется перебором
  // PSK (см. отчёт спринта «отвязка бесед от слотов»). Колонка
  // Channels.slotIndex в БД осталась (NOT NULL, схему не меняем) — в неё
  // теперь всегда пишется 0, см. ContactStore.createChannel.
  final DateTime createdAt;

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    if (avatarEmoji != null) 'avatarEmoji': avatarEmoji,
    'psk': base64Encode(psk),
    'createdAt': createdAt.toIso8601String(),
  };
}
