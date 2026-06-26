import 'dart:math';
import 'dart:typed_data';
import '../models/mesh_channel.dart';
import 'contact_store.dart';
import 'mesh_service.dart';
import 'meshtastic_proto.dart';

// ignore_for_file: avoid_print

class ChannelManager {
  ChannelManager._();
  static final ChannelManager instance = ChannelManager._();

  // Слоты 0 (Primary) зарезервирован устройством.
  // Мы используем 1–7 для пользовательских каналов.
  static const _minSlot = 1;
  static const _maxSlot = 7;

  // Следующий свободный слот
  int nextFreeSlot(ContactStore store) {
    final used = store.channels.map((c) => c.slotIndex).toSet();
    for (var i = _minSlot; i <= _maxSlot; i++) {
      if (!used.contains(i)) return i;
    }
    return -1; // все слоты заняты
  }

  // Создать канал: сохранить локально + записать в девайс если подключён
  Future<MeshChannel?> create({
    required String name,
    required String? avatarEmoji,
    required MeshService meshService,
  }) async {
    final store = ContactStore.instance;
    final slot = nextFreeSlot(store);
    if (slot == -1) return null;

    final psk = _randomPsk();

    final ch = await store.createChannel(
      name: name,
      slotIndex: slot,
      avatarEmoji: avatarEmoji,
      psk: psk,
    );

    // Записываем в девайс если подключён
    await _writeToDevice(ch, meshService);

    return ch;
  }

  // Добавить канал полученный по QR (уже есть PSK и slot)
  Future<MeshChannel> addFromQr({
    required String name,
    required Uint8List psk,
    required int slotIndex,
    required String? avatarEmoji,
    required MeshService meshService,
  }) async {
    final store = ContactStore.instance;
    final ch = await store.createChannel(
      name: name,
      slotIndex: slotIndex,
      avatarEmoji: avatarEmoji,
      psk: psk,
    );
    await _writeToDevice(ch, meshService);
    return ch;
  }

  Future<void> _writeToDevice(MeshChannel ch, MeshService meshService) async {
    final nodeId = meshService.myNodeId;
    if (nodeId == null || !meshService.isConnected) {
      print('[ChannelMgr] not connected, skipping device write');
      return;
    }
    final nodeNum = int.parse(nodeId.substring(1), radix: 16);
    try {
      await meshService.writeRaw(
        MeshtasticProto.encodeSetChannel(
          slotIndex: ch.slotIndex,
          name: ch.name,
          psk: ch.psk,
          fromNode: nodeNum,
        ),
      );
      print('[ChannelMgr] wrote channel "${ch.name}" to slot ${ch.slotIndex}');
    } catch (e) {
      print('[ChannelMgr] device write error: $e');
    }
  }

  static Uint8List _randomPsk() {
    final rng = Random.secure();
    return Uint8List.fromList(List.generate(32, (_) => rng.nextInt(256)));
  }
}
