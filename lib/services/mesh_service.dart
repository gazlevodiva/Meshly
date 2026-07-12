import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:meshly/models/conversation.dart';
import 'package:meshly/models/message.dart';
import 'package:meshly/services/contact_store.dart';
import 'package:meshly/services/crypto_service.dart';
import 'package:meshly/services/meshtastic_proto.dart';
import 'package:meshly/services/notification_service.dart';
import 'package:meshly/services/notification_settings.dart';

// Prints are used for BLE debug logging in MeshService.
// ignore_for_file: avoid_print

const _meshServiceUuid = '6ba1b218-15a8-461f-9fa8-5dcae273eafd';
const _toRadioCharUuid = 'f75c76d2-129e-4dad-a1dd-7866124401e7';
const _fromRadioCharUuid = '2c55e69e-4993-11ed-b878-0242ac120002';
const _fromNumCharUuid = 'ed9da18c-a800-4f66-a670-aa7547e34453';

// Placeholder text stored for an incoming DM that could not be decrypted
// (missing sender public key, auth failure, or a plaintext DM from a
// non-Meshly node). Phase 4 UI renders this as a localized placeholder
// instead of showing it verbatim.
const kUndecryptableSentinel = ' meshly:undecryptable';

/// Outcome of [MeshService.sendText]. Channel sends always resolve to
/// [sent] (or [noChannel] if the target channel doesn't exist). DM sends
/// resolve to [needsKey] when the peer contact has no known public key —
/// DMs are encrypted-only, so we refuse to send rather than fall back to
/// plaintext.
enum SendResult { sent, needsKey, noChannel }

class MeshService {
  BluetoothDevice? _device;
  BluetoothCharacteristic? _toRadio;
  BluetoothCharacteristic? _fromRadio;
  BluetoothCharacteristic? _fromNum;
  Timer? _pollTimer;
  StreamSubscription<BluetoothConnectionState>? _connStateSub;
  bool _disposed = false;

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

  // Имя подключённого девайса (null = нет подключения).
  // ValueNotifier вместо broadcast-стрима: новые подписчики (экраны,
  // созданные ПОСЛЕ connect()) сразу видят текущее значение.
  final ValueNotifier<String?> deviceName = ValueNotifier(null);

  String? get myNodeId => _myNodeNum != null
      ? '!${_myNodeNum!.toRadixString(16).padLeft(8, '0')}'
      : null;

  bool get isConnected => _device != null;

  Stream<List<ScanResult>> scan({
    Duration timeout = const Duration(seconds: 10),
  }) {
    unawaited(FlutterBluePlus.startScan(timeout: timeout));
    return FlutterBluePlus.scanResults;
  }

  Future<void> stopScan() => FlutterBluePlus.stopScan();

  Future<void> connect(BluetoothDevice device) async {
    await device.connect(license: License.nonprofit);
    _device = device;
    deviceName.value = device.platformName.isNotEmpty
        ? device.platformName
        : device.remoteId.str;

    final services = await device.discoverServices();
    final meshSvc = _findService(services, _meshServiceUuid);
    if (meshSvc == null) {
      final found = services.map((s) => '  ${s.serviceUuid}').join('\n');
      await device.disconnect();
      _cleanupConnection();
      throw Exception(
        'Meshtastic-сервис не найден.\nНайденные сервисы:\n$found',
      );
    }

    _toRadio = _findChar(meshSvc, _toRadioCharUuid);
    _fromRadio = _findChar(meshSvc, _fromRadioCharUuid);
    _fromNum = _findChar(meshSvc, _fromNumCharUuid);

    if (_toRadio == null || _fromRadio == null) {
      final found = meshSvc.characteristics
          .map((c) => '  ${c.characteristicUuid}')
          .join('\n');
      await device.disconnect();
      _cleanupConnection();
      throw Exception('Не найдены нужные характеристики.\nДоступные:\n$found');
    }

    if (_fromNum != null) {
      await _fromNum!.setNotifyValue(true);
      unawaited(
        _fromNum!.onValueReceived.listen((_) => _drainFromRadio()).asFuture(),
      );
    }

    await _toRadio!.write(MeshtasticProto.encodeWantConfig());
    await _drainFromRadio();
    _pollTimer = Timer.periodic(
      const Duration(seconds: 3),
      (_) => _drainFromRadio(),
    );

    // Следим за реальным BLE-состоянием: если девайс отвалился
    // (вышел из зоны, разрядился) — отражаем это в UI.
    _connStateSub = device.connectionState.listen((state) {
      if (state == BluetoothConnectionState.disconnected) {
        print('[BLE] device disconnected');
        _cleanupConnection();
      }
    });
  }

  // Отправить сырые байты в ToRadio (для AdminMessage и др.)
  Future<void> writeRaw(List<int> bytes) async {
    if (_toRadio == null) return;
    await _toRadio!.write(bytes);
  }

  Future<void> disconnect() async {
    final device = _device;
    _cleanupConnection();
    await device?.disconnect();
  }

  // Идемпотентная очистка состояния подключения. Вызывается и из
  // disconnect(), и из слушателя connectionState при реальном BLE-разрыве —
  // повторный вызов (например, disconnect() сам триггерит событие
  // disconnected) безопасен.
  void _cleanupConnection() {
    unawaited(_connStateSub?.cancel());
    _connStateSub = null;
    _pollTimer?.cancel();
    _pollTimer = null;
    _device = null;
    _toRadio = _fromRadio = _fromNum = null;
    _lastHeard.clear();
    if (!_disposed) deviceName.value = null;
  }

  // Отправить текст в conversation (DM или канал)
  Future<SendResult> sendText(String text, Conversation conv) async {
    final store = ContactStore.instance;
    int? toNode;
    int channelSlot;
    var portnum = MeshtasticProto.portTextMessage;
    Uint8List? rawPayload;

    if (conv.isDm && conv.peerId != null) {
      // DM: unicast к конкретному узлу, primary channel (slot 0).
      // DM — только шифрованные: без публичного ключа контакта не отправляем.
      final peerKey = store.contactByNodeId(conv.peerId!)?.publicKey;
      if (peerKey == null) {
        print(
          '[Mesh] sendText: no public key for ${conv.peerId}, needs QR rescan',
        );
        return SendResult.needsKey;
      }
      toNode = _parseNodeId(conv.peerId!);
      channelSlot = 0;
      portnum = MeshtasticProto.PRIVATE_APP;
      rawPayload = await CryptoService.instance.encryptToContact(
        peerPublicKey: peerKey,
        plaintext: text,
      );
    } else if (conv.isChannel && conv.channelId != null) {
      // Канал: broadcast, нужный слот
      final ch = store.channelById(conv.channelId!);
      if (ch == null) {
        print('[Mesh] sendText: channel ${conv.channelId} not found, aborting');
        return SendResult.noChannel;
      }
      // Канал: собственный Meshly-AEAD (ключ из PSK канала), portnum
      // PRIVATE_APP — как в DM, чтобы официальное приложение не видело текст.
      channelSlot = ch.slotIndex;
      portnum = MeshtasticProto.PRIVATE_APP;
      rawPayload = await CryptoService.instance.encryptForChannel(
        psk: ch.psk,
        plaintext: text,
      );
    } else {
      return SendResult.noChannel;
    }

    if (_toRadio == null) return SendResult.sent;

    // Генерируем packet id заранее и передаём его в encodeTextMessage,
    // чтобы радио отправило пакет с НАШИМ id — тогда ROUTING ACK (request_id)
    // совпадёт с meshId сохранённого сообщения и статус обновится на acked.
    final msgId = DateTime.now().millisecondsSinceEpoch & 0x7FFFFFFF;
    final encoded = MeshtasticProto.encodeTextMessage(
      text,
      to: toNode,
      channel: channelSlot,
      fromNode: _myNodeNum,
      id: msgId,
      portnum: portnum,
      rawPayload: rawPayload,
    );

    await _toRadio!.write(encoded);

    // Добавляем исходящее сообщение в store (локально всегда plaintext —
    // это наш собственный текст до шифрования)
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
    _incomingController.add(msg.copyWith());
    return SendResult.sent;
  }

  // ── Incoming packet dispatch ───────────────────────────────

  Future<void> _drainFromRadio() async {
    if (_disposed || _fromRadio == null) return;
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
      final status = ack.errorCode == 0
          ? MessageStatus.acked
          : MessageStatus.failed;
      await store.updateMessageStatus(ack.meshId, status);
    }

    // MESSAGE (portnum=1 plaintext text, or portnum=PRIVATE_APP encrypted DM)
    final decoded = MeshtasticProto.decodeFromRadio(bytes);
    final portnum = decoded.portnum;
    if (portnum != MeshtasticProto.portTextMessage &&
        portnum != MeshtasticProto.PRIVATE_APP) {
      return;
    }

    final fromNodeId = decoded.from ?? '!00000000';
    final channelSlot = decoded.channel ?? 0;

    // Не показываем собственные эхо-пакеты
    if (fromNodeId == myNodeId) return;

    // Игнорируем сообщения от заблокированных нод
    if (store.isBlocked(fromNodeId)) return;

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
      print(
        '[Mesh] no conversation for fromNode=$fromNodeId slot=$channelSlot — ignoring',
      );
      return;
    }

    // Разбор текста в зависимости от порта:
    // - DM: только PRIVATE_APP расшифровывается; TEXT_MESSAGE_APP-плейнтекст
    //   от не-Meshly ноды или неудачная расшифровка → сентинел-заглушка.
    // - Канал: только собственный Meshly-AEAD (PRIVATE_APP + PSK канала).
    //   Чужой plaintext (TEXT_MESSAGE_APP) и любую неудачную расшифровку
    //   молча дропаем — общий/официальный канал в Meshly не показываем.
    String? text;
    var notify = true;
    if (decoded.isDm) {
      if (portnum == MeshtasticProto.PRIVATE_APP &&
          decoded.rawPayload != null) {
        final senderKey = store.contactByNodeId(fromNodeId)?.publicKey;
        if (senderKey != null) {
          text = await CryptoService.instance.decryptFromContact(
            senderPublicKey: senderKey,
            envelope: decoded.rawPayload!,
          );
        }
      }
      if (text == null) {
        text = kUndecryptableSentinel;
        notify = false;
      }
    } else {
      // Broadcast/канал: принимаем только зашифрованный Meshly-конверт.
      if (portnum != MeshtasticProto.PRIVATE_APP ||
          decoded.rawPayload == null) {
        return;
      }
      final psk = store.channelById(conv.channelId!)?.psk;
      if (psk == null) return;
      text = await CryptoService.instance.decryptForChannel(
        psk: psk,
        envelope: decoded.rawPayload!,
      );
      if (text == null) return;
    }

    final msg = Message(
      meshId: decoded.meshId ?? 0,
      fromNodeId: fromNodeId,
      conversationId: conv.id,
      text: text,
      time: DateTime.now(),
      isMe: false,
    );

    await store.addMessage(msg);
    _incomingController.add(msg.copyWith());
    print('[Mesh] message in ${conv.id} from $fromNodeId: "${msg.text}"');

    // Локальное уведомление для входящих сообщений
    if (!notify) return;
    String notifTitle;
    if (conv.isDm && conv.peerId != null) {
      final contact = store.contactByNodeId(fromNodeId);
      notifTitle = contact?.displayName ?? fromNodeId;
    } else if (conv.isChannel && conv.channelId != null) {
      final ch = store.channelById(conv.channelId!);
      final senderContact = store.contactByNodeId(fromNodeId);
      final senderName = senderContact?.displayName ?? fromNodeId;
      // TODO(l10n): notification title fallback. MeshService has no
      // BuildContext, so this stays a Russian literal until localization
      // is plumbed through.
      notifTitle = '${ch?.name ?? "Канал"} · $senderName';
    } else {
      notifTitle = fromNodeId;
    }
    final shouldNotify = NotificationSettings.instance.shouldNotify(
      convId: conv.id,
      isDm: conv.isDm,
    );
    if (shouldNotify) {
      await NotificationService.instance.showMessage(
        title: notifTitle,
        body: msg.text,
        conversationId: conv.id,
      );
    }
  }

  // ── Helpers ───────────────────────────────────────────────

  static int? _parseNodeId(String nodeId) {
    // '!1f8e42c9' → 0x1F8E42C9
    final hex = nodeId.startsWith('!') ? nodeId.substring(1) : nodeId;
    return int.tryParse(hex, radix: 16);
  }

  static BluetoothService? _findService(
    List<BluetoothService> services,
    String uuid,
  ) => services.cast<BluetoothService?>().firstWhere(
    (s) => s!.serviceUuid.toString().toLowerCase() == uuid.toLowerCase(),
    orElse: () => null,
  );

  static BluetoothCharacteristic? _findChar(
    BluetoothService svc,
    String uuid,
  ) => svc.characteristics.cast<BluetoothCharacteristic?>().firstWhere(
    (c) => c!.characteristicUuid.toString().toLowerCase() == uuid.toLowerCase(),
    orElse: () => null,
  );

  void dispose() {
    _disposed = true;
    unawaited(_connStateSub?.cancel());
    _connStateSub = null;
    _pollTimer?.cancel();
    unawaited(_incomingController.close());
    deviceName.dispose();
  }
}
