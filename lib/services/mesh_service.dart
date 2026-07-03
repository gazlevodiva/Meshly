import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:meshly/models/conversation.dart';
import 'package:meshly/models/message.dart';
import 'package:meshly/services/contact_store.dart';
import 'package:meshly/services/meshtastic_proto.dart';
import 'package:meshly/services/notification_service.dart';

// Prints are used for BLE debug logging in MeshService.
// ignore_for_file: avoid_print

const _meshServiceUuid   = '6ba1b218-15a8-461f-9fa8-5dcae273eafd';
const _toRadioCharUuid   = 'f75c76d2-129e-4dad-a1dd-7866124401e7';
const _fromRadioCharUuid = '2c55e69e-4993-11ed-b878-0242ac120002';
const _fromNumCharUuid   = 'ed9da18c-a800-4f66-a670-aa7547e34453';

class MeshService {
  BluetoothDevice? _device;
  BluetoothCharacteristic? _toRadio;
  BluetoothCharacteristic? _fromRadio;
  BluetoothCharacteristic? _fromNum;
  Timer? _pollTimer;

  int? _myNodeNum;
  final Map<String, DateTime> _lastHeard = {};
  static const _onlineThreshold = Duration(minutes: 15);

  bool isOnline(String nodeId) {
    final t = _lastHeard[nodeId];
    if (t == null) return false;
    return DateTime.now().difference(t) < _onlineThreshold;
  }

  DateTime? lastHeardFor(String nodeId) => _lastHeard[nodeId];

  // Стрим для уведомления UI о новых входящих сообщениях
  final _incomingController = StreamController<Message>.broadcast();
  Stream<Message> get incomingMessages => _incomingController.stream;

  final _deviceNameController = StreamController<String?>.broadcast();
  Stream<String?> get connectedDeviceName => _deviceNameController.stream;

  String? get myNodeId => _myNodeNum != null
      ? '!${_myNodeNum!.toRadixString(16).padLeft(8, '0')}'
      : null;

  bool get isConnected => _device != null;

  Stream<List<ScanResult>> scan({Duration timeout = const Duration(seconds: 10)}) {
    unawaited(FlutterBluePlus.startScan(timeout: timeout));
    return FlutterBluePlus.scanResults;
  }

  Future<void> stopScan() => FlutterBluePlus.stopScan();

  Future<void> connect(BluetoothDevice device) async {
    await device.connect(license: License.nonprofit);
    _device = device;
    _deviceNameController.add(
      device.platformName.isNotEmpty ? device.platformName : device.remoteId.str,
    );

    final services = await device.discoverServices();
    final meshSvc = _findService(services, _meshServiceUuid);
    if (meshSvc == null) {
      final found = services.map((s) => '  ${s.serviceUuid}').join('\n');
      await device.disconnect();
      _device = null;
      throw Exception('Meshtastic-сервис не найден.\nНайденные сервисы:\n$found');
    }

    _toRadio   = _findChar(meshSvc, _toRadioCharUuid);
    _fromRadio = _findChar(meshSvc, _fromRadioCharUuid);
    _fromNum   = _findChar(meshSvc, _fromNumCharUuid);

    if (_toRadio == null || _fromRadio == null) {
      final found = meshSvc.characteristics.map((c) => '  ${c.characteristicUuid}').join('\n');
      await device.disconnect();
      _device = null;
      throw Exception('Не найдены нужные характеристики.\nДоступные:\n$found');
    }

    if (_fromNum != null) {
      await _fromNum!.setNotifyValue(true);
      unawaited(_fromNum!.onValueReceived.listen((_) => _drainFromRadio()).asFuture());
    }

    await _toRadio!.write(MeshtasticProto.encodeWantConfig());
    await _drainFromRadio();
    _pollTimer = Timer.periodic(const Duration(seconds: 3), (_) => _drainFromRadio());
  }

  // Отправить сырые байты в ToRadio (для AdminMessage и др.)
  Future<void> writeRaw(List<int> bytes) async {
    if (_toRadio == null) return;
    await _toRadio!.write(bytes);
  }

  Future<void> disconnect() async {
    _pollTimer?.cancel();
    _pollTimer = null;
    await _device?.disconnect();
    _device = null;
    _toRadio = _fromRadio = _fromNum = null;
    _deviceNameController.add(null);
  }

  // Отправить текст в conversation (DM или канал)
  Future<void> sendText(String text, Conversation conv) async {
    if (_toRadio == null) return;

    final store = ContactStore.instance;
    int? toNode;
    int channelSlot;

    if (conv.isDm && conv.peerId != null) {
      // DM: unicast к конкретному узлу, primary channel (slot 0)
      toNode = _parseNodeId(conv.peerId!);
      channelSlot = 0;
    } else if (conv.isChannel && conv.channelId != null) {
      // Канал: broadcast, нужный слот
      final ch = store.channelById(conv.channelId!);
      channelSlot = ch?.slotIndex ?? 2;
    } else {
      return;
    }

    final encoded = MeshtasticProto.encodeTextMessage(
      text,
      to: toNode,
      channel: channelSlot,
      fromNode: _myNodeNum,
    );

    await _toRadio!.write(encoded);

    // Добавляем исходящее сообщение в store
    final msgId = DateTime.now().millisecondsSinceEpoch & 0x7FFFFFFF;
    final msg = Message(
      meshId: msgId,
      fromNodeId: myNodeId ?? '!00000000',
      conversationId: conv.id,
      text: text,
      time: DateTime.now(),
      isMe: true,
      status: MessageStatus.sent,
    );
    await store.addMessage(msg);
    _incomingController.add(msg);
  }

  // ── Incoming packet dispatch ───────────────────────────────

  Future<void> _drainFromRadio() async {
    if (_fromRadio == null) return;
    for (var i = 0; i < 20; i++) {
      try {
        final bytes = await _fromRadio!.read();
        if (bytes.isEmpty) break;
        await _onBytesReceived(bytes);
      } on Exception catch (e) {
        print('[BLE] drain error: $e');
        break;
      }
    }
  }

  Future<void> _onBytesReceived(List<int> bytes) async {
    final store = ContactStore.instance;

    // Track lastHeard from any MeshPacket sender
    final sender = MeshtasticProto.extractSender(bytes);
    if (sender != null && sender != myNodeId) {
      _lastHeard[sender] = DateTime.now();
    }

    // MyNodeInfo → сохраняем свой node ID
    final myNum = MeshtasticProto.decodeMyNodeNum(bytes);
    if (myNum != null) {
      _myNodeNum = myNum;
      debugPrint('[Mesh] my node = $myNodeId');
    }

    // NodeInfo — только логируем, имя контакта пользователь задаёт сам
    final nodeInfo = MeshtasticProto.decodeNodeInfo(bytes);
    if (nodeInfo != null) {
      print('[Mesh] node ${nodeInfo.nodeId} = "${nodeInfo.longName}"');
    }

    // ROUTING ACK (portnum=5) → обновляем статус сообщения
    final ack = MeshtasticProto.decodeRoutingAck(bytes);
    if (ack != null) {
      print('[Mesh] routing ack meshId=${ack.meshId} error=${ack.errorCode}');
      final status = ack.errorCode == 0 ? MessageStatus.acked : MessageStatus.failed;
      await store.updateMessageStatus(ack.meshId, status);
    }

    // TEXT MESSAGE (portnum=1)
    final decoded = MeshtasticProto.decodeFromRadio(bytes);
    if (decoded.text == null || decoded.text!.isEmpty) return;

    final fromNodeId = decoded.from ?? '!00000000';
    final channelSlot = decoded.channel ?? 0;

    // Не показываем собственные эхо-пакеты
    if (fromNodeId == myNodeId) return;

    // Определяем conversation
    Conversation? conv;
    if (decoded.isDm) {
      // Unicast к нам → DM от fromNodeId
      conv = store.dmForNode(fromNodeId);
      if (conv == null) {
        // Незнакомый контакт: создаём временный DM
        conv = Conversation.dm(fromNodeId);
        await store.saveConversation(conv);
      }
    } else {
      // Broadcast на канале → ищем по слоту
      conv = store.conversationForSlot(channelSlot);
    }

    if (conv == null) {
      print('[Mesh] no conversation for fromNode=$fromNodeId slot=$channelSlot — ignoring');
      return;
    }

    final msg = Message(
      meshId: decoded.meshId ?? 0,
      fromNodeId: fromNodeId,
      conversationId: conv.id,
      text: decoded.text!.trim(),
      time: DateTime.now(),
      isMe: false,
    );

    await store.addMessage(msg);
    _incomingController.add(msg);
    print('[Mesh] message in ${conv.id} from $fromNodeId: "${msg.text}"');

    // Локальное уведомление для входящих сообщений
    String notifTitle;
    if (conv.isDm && conv.peerId != null) {
      final contact = store.contactByNodeId(fromNodeId);
      notifTitle = contact?.displayName ?? fromNodeId;
    } else if (conv.isChannel && conv.channelId != null) {
      final ch = store.channelById(conv.channelId!);
      final senderContact = store.contactByNodeId(fromNodeId);
      final senderName = senderContact?.displayName ?? fromNodeId;
      notifTitle = '${ch?.name ?? "Канал"} · $senderName';
    } else {
      notifTitle = fromNodeId;
    }
    await NotificationService.instance.showMessage(
      title: notifTitle,
      body: msg.text,
      conversationId: conv.id,
    );
  }

  // ── Helpers ───────────────────────────────────────────────

  static int? _parseNodeId(String nodeId) {
    // '!1f8e42c9' → 0x1F8E42C9
    final hex = nodeId.startsWith('!') ? nodeId.substring(1) : nodeId;
    return int.tryParse(hex, radix: 16);
  }

  static BluetoothService? _findService(List<BluetoothService> services, String uuid) =>
      services.cast<BluetoothService?>().firstWhere(
        (s) => s!.serviceUuid.toString().toLowerCase() == uuid.toLowerCase(),
        orElse: () => null,
      );

  static BluetoothCharacteristic? _findChar(BluetoothService svc, String uuid) =>
      svc.characteristics.cast<BluetoothCharacteristic?>().firstWhere(
        (c) => c!.characteristicUuid.toString().toLowerCase() == uuid.toLowerCase(),
        orElse: () => null,
      );

  void dispose() {
    _pollTimer?.cancel();
    unawaited(_incomingController.close());
    unawaited(_deviceNameController.close());
  }
}
