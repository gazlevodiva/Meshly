import 'dart:math';
import 'dart:typed_data';

import 'package:meshly/models/mesh_channel.dart';
import 'package:meshly/services/contact_store.dart';
import 'package:meshly/services/mesh_service.dart';

/// Тонкая обёртка над [ContactStore.createChannel].
///
/// Раньше здесь же подбирался свободный аппаратный слот (1–7, слот 0 занят
/// прошивкой) и канал писался в устройство (`MeshtasticProto.encodeSetChannel`
/// — теперь удалён). Обе части ушли вместе с отвязкой бесед от слотов (см.
/// отчёт спринта): запись в устройство никогда не работала (неверный номер
/// поля и порт), а значит слот и не настраивался — беседа на приёме
/// определяется перебором PSK, а не по слоту, и бесед теперь может быть
/// сколько угодно.
///
/// Класс оставлен (не выродился в статическую функцию) намеренно: экраны
/// (`new_channel_screen.dart`) вызывают `ChannelManager.instance.create(...)`
/// напрямую, а по правилам спринта экраны трогать нельзя — сигнатура и точка
/// входа должны остаться прежними.
class ChannelManager {
  ChannelManager._();
  static final ChannelManager instance = ChannelManager._();

  // Создать беседу: сохранить локально. Устройство больше не трогаем.
  // ContactStore.createChannel всегда успешен (не бывает "все слоты заняты"
  // — слотов больше нет), поэтому возврат непустой.
  Future<MeshChannel> create({
    required String name,
    required String? avatarEmoji,
    required MeshService meshService,
  }) async {
    final store = ContactStore.instance;
    final psk = _randomPsk();
    return store.createChannel(
      name: name,
      avatarEmoji: avatarEmoji,
      psk: psk,
    );
  }

  /// Добавить беседу, полученную по QR (уже есть PSK).
  Future<MeshChannel> addFromQr({
    required String name,
    required Uint8List psk,
    required String? avatarEmoji,
    required MeshService meshService,
  }) async {
    final store = ContactStore.instance;
    return store.createChannel(
      name: name,
      avatarEmoji: avatarEmoji,
      psk: psk,
    );
  }

  static Uint8List _randomPsk() {
    final rng = Random.secure();
    return Uint8List.fromList(List.generate(32, (_) => rng.nextInt(256)));
  }
}
