import 'dart:convert';
import 'package:flutter/foundation.dart';

// Manual minimal protobuf for Meshtastic
// ToRadio(1=MeshPacket) → MeshPacket(1=to, 3=id, 4=Data, 9=channel)
// Data(1=portnum, 2=payload)

class MeshtasticProto {
  static const int _broadcastAddr = 0xFFFFFFFF;
  static const int _portTextMessage = 1; // TEXT_MESSAGE_APP

  // Public alias so callers (mesh_service) can pass the default portnum
  // explicitly to encodeTextMessage without hardcoding the magic number.
  static const int portTextMessage = _portTextMessage;

  // Portnum used for E2E-encrypted DM envelopes (Phase 3). Official
  // Meshtastic clients don't recognize this port and simply ignore the
  // packet instead of rendering garbled ciphertext as text.
  // Named to match the Meshtastic portnums.proto enum member (PRIVATE_APP),
  // not lowerCamelCase, for cross-reference clarity with the upstream spec.
  // ignore: constant_identifier_names
  static const int PRIVATE_APP = 256;

  // ToRadio { want_config_id: id } — initiates BLE session, device starts sending packets
  static Uint8List encodeWantConfig() {
    final id = DateTime.now().millisecondsSinceEpoch & 0x7FFFFFFF;
    return _buf([_varint(3, id)]);
  }

  // ── Регион радио (LoRaConfig) ─────────────────────────────────────────
  //
  // Номера полей сверены с meshtastic/protobufs (master):
  //   FromRadio.config = 5, Config.lora = 6, LoRaConfig.region = 7,
  //   AdminMessage.set_config = 34, begin_edit_settings = 64,
  //   commit_edit_settings = 65.
  // Внимание: AdminMessage.set_channel — это 33, а НЕ 11 (см. encodeSetChannel
  // ниже). У той функции неверны и номер поля, и поле from пакета — но это
  // была не единственная и не главная беда: см. _adminPort ниже.
  //
  // НАЙДЕННАЯ ИСТИННАЯ ПРИЧИНА (2026-09): все админ-команды (и региона, и
  // канала) уходили с Data.portnum = 68. В meshtastic/protobufs
  // (portnums.proto) 68 — это ZPS_APP, а ADMIN_APP = 6. Прошивка
  // (PhoneAPI::handleToRadioPacket → MeshService::handleToRadio →
  // Router::sendLocal) честно принимает пакет с BLE (отсюда
  // GATT_SUCCESS на запись характеристики) и доставляет его себе же
  // локально (to == собственный node num), но диспетчер модулей
  // (FloodingRouter/Router::perhapsHandleReceived → MeshModule::callPlugins,
  // src/mesh/Router.cpp) ищет модуль, подписанный на конкретный portnum —
  // AdminModule подписан на ADMIN_APP=6, а не на 68. Модуля с portnum=68 нет,
  // пакет молча роняется до AdminModule::handleReceivedProtobuf: отсюда и
  // тишина — ни NAK, ни ADMIN_BAD_SESSION_KEY, ни перезагрузки. Чтение
  // конфига работало отдельно от этого пути: это не AdminMessage-запрос, а
  // часть автоматического дампа конфига при подключении
  // (PhoneAPI STATE_SEND_CONFIG), поэтому её ничего не роняло.
  static const int _adminPort = 6; // ADMIN_APP (было 68 = ZPS_APP — баг)
  static int _adminSeq = 0;

  /// Сырые байты `LoRaConfig` ровно как их прислало устройство + разобранный
  /// регион (0 = UNSET, устройство не вещает в эфир).
  ///
  /// Сырые байты нужны именно как байты: [encodeSetRegion] правит в них одно
  /// поле, а не пересобирает сообщение — так переживают нетронутыми все
  /// настройки, которых мы не знаем (модем-пресет, мощность, поля, добавленные
  /// новой прошивкой).
  static ({Uint8List raw, int region})? decodeLoraConfig(List<int> raw) {
    try {
      final bytes = Uint8List.fromList(raw);
      final config = _readMsg(bytes, 5); // FromRadio.config
      if (config == null) return null;
      final lora = _readMsg(config, 6); // Config.lora
      if (lora == null) return null;
      final region = _readVarint(lora, 7) ?? 0;
      debugPrint('[Proto] lora config: region=$region (${lora.length}B)');
      return (raw: lora, region: region);
    } on Exception catch (e) {
      debugPrint('[Proto] lora config decode error: $e');
      return null;
    }
  }

  /// Три кадра ToRadio, меняющие регион и ничего больше:
  /// `begin_edit_settings` → `set_config{lora}` → `commit_edit_settings`.
  ///
  /// [currentLora] обязан быть байтами из [decodeLoraConfig]: `set_config`
  /// заменяет весь `LoRaConfig` целиком, поэтому сообщение, собранное с нуля,
  /// молча затёрло бы пользователю модем-пресет, hop limit и мощность.
  static List<Uint8List> encodeSetRegion({
    required Uint8List currentLora,
    required int region,
    required int fromNode,
  }) {
    final patched = _replaceVarintField(currentLora, 7, region);
    final configBody = _msg(6, patched); // Config { lora }
    return [
      _adminFrame(_varint(64, 1), fromNode), // begin_edit_settings
      _adminFrame(_msg(34, configBody), fromNode), // set_config
      _adminFrame(_varint(65, 1), fromNode), // commit_edit_settings
    ];
  }

  // AdminMessage → MeshPacket самому себе, hop_limit=1: пакет не уходит в эфир.
  static Uint8List _adminFrame(Uint8List admin, int fromNode) {
    final data = _buf([_varint(1, _adminPort), _bytes(2, admin)]);
    // Свой id на каждый кадр: три подряд с одинаковым id радио сочло бы
    // дублями и выполнило бы только первый.
    final msgId =
        (DateTime.now().millisecondsSinceEpoch + _adminSeq++) & 0x7FFFFFFF;
    final packet = _buf([
      // from = 0 — ОБЯЗАТЕЛЬНО. Прошивка считает локальной (и потому
      // доверенной) только ту админ-команду, у которой from == 0: свой номер
      // узла она подставит сама. С ненулевым from команда считается удалённым
      // администрированием, требует сессионный ключ и молча отвергается
      // (AdminModule::handleReceivedProtobuf → "Ignore unauthorized admin
      // payload"). Именно поэтому encodeSetChannel ниже никогда не работал.
      _fixed32field(1, 0),
      _fixed32field(2, fromNode), // адресовано самому устройству
      _varint(3, 0), // admin едет по первичному каналу
      _msg(4, data),
      _fixed32field(6, msgId),
      _varint(9, 1), // hop_limit=1 — только локально
    ]);
    return _buf([_msg(1, packet)]);
  }

  /// Копия [msg] байт в байт, где varint-поле [field] заменено на [value]
  /// (или дописано, если его не было). Все прочие поля переносятся как есть,
  /// включая неизвестные нам.
  ///
  /// На испорченном сообщении возвращает исходник нетронутым: лучше не менять
  /// регион вовсе, чем отправить в устройство обрезанный конфиг.
  static Uint8List _replaceVarintField(Uint8List msg, int field, int value) {
    final out = <int>[];
    var pos = 0;
    while (pos < msg.length) {
      final tagStart = pos;
      final t = _decVarint(msg, pos);
      pos = t.$2;
      final f = t.$1 >> 3;
      final int end;
      switch (t.$1 & 7) {
        case 0:
          end = _decVarint(msg, pos).$2;
        case 1:
          end = pos + 8;
        case 2:
          final l = _decVarint(msg, pos);
          end = l.$2 + l.$1;
        case 5:
          end = pos + 4;
        default:
          return msg; // неизвестный wire type — не трогаем сообщение
      }
      // end < pos ловит отрицательную длину из переполненного варинта.
      if (end > msg.length || end < pos) return msg;
      if (f != field) out.addAll(msg.sublist(tagStart, end));
      pos = end;
    }
    out.addAll(_varint(field, value));
    return Uint8List.fromList(out);
  }

  // AdminMessage { set_channel: Channel } → записывает канал в девайс.
  // НЕ ЧИНИТЬ (подлежит удалению в другом спринте) — но для истории: здесь
  // как минимум ТРИ независимых бага одновременно: set_channel = 11 вместо
  // 33, portnum = 68 (ZPS_APP) вместо 6 (ADMIN_APP, см. _adminPort выше —
  // это и есть системная причина, из-за которой запись региона тоже не
  // работала), и from = fromNode вместо 0 (прошивка требует from==0 для
  // локальной команды без сессионного ключа). Любого одного из трёх уже
  // достаточно, чтобы устройство молча проигнорировало пакет.
  static Uint8List encodeSetChannel({
    required int slotIndex,
    required String name,
    required Uint8List psk,
    required int fromNode,
  }) {
    // ChannelSettings { psk(2), name(3) }
    final settings = _buf([
      _bytes(2, psk),
      _bytes(3, Uint8List.fromList(utf8.encode(name))),
    ]);

    // Channel { index(1), settings(2), role(3)=SECONDARY(2) }
    final channel = _buf([
      _varint(1, slotIndex),
      _msg(2, settings),
      _varint(3, 2), // SECONDARY
    ]);

    // AdminMessage { set_channel(11) }
    final admin = _buf([_msg(11, channel)]);

    // Data { portnum(1)=ADMIN_APP(68), payload(2) }
    final data = _buf([
      _varint(1, 68),
      _bytes(2, admin),
    ]);

    final msgId = DateTime.now().millisecondsSinceEpoch & 0x7FFFFFFF;
    final packet = _buf([
      _fixed32field(1, fromNode),
      _fixed32field(2, fromNode), // unicast to self
      _varint(3, 0), // primary channel (admin uses ch0)
      _msg(4, data),
      _fixed32field(6, msgId),
      _varint(9, 1), // hop_limit=1 (local only)
    ]);

    return _buf([_msg(1, packet)]);
  }

  // `id` — наш packet id (MeshPacket.id, field 6). Радио использует его как есть,
  // и ROUTING ACK приходит с этим же id в Data.request_id — так мы сопоставляем
  // подтверждение доставки с сообщением в store.
  static Uint8List encodeTextMessage(
    String text, {
    int? to,
    int channel = 0,
    int? fromNode,
    int? id,
    int portnum = _portTextMessage,
    Uint8List? rawPayload,
  }) {
    final dest = to ?? _broadcastAddr;
    final payloadBytes = rawPayload ?? Uint8List.fromList(utf8.encode(text));
    final msgId = id ?? (DateTime.now().millisecondsSinceEpoch & 0x7FFFFFFF);

    final data = _buf([
      _varint(1, portnum),
      _bytes(2, payloadBytes),
    ]);

    // Proto: field1=from, field2=to, field3=channel, field4=decoded, field6=id(fixed32), field9=hop_limit, field10=want_ack
    final packet = _buf([
      if (fromNode != null) _fixed32field(1, fromNode), // from = our node ID
      _fixed32field(2, dest), // to = destination
      _varint(3, channel), // channel = slot index
      _msg(4, data),
      _fixed32field(6, msgId), // id = fixed32
      _varint(9, 3), // hop_limit = 3
      _varint(10, 1), // want_ack = true → firmware генерирует end-to-end ACK
    ]);

    final toRadio = _buf([_msg(1, packet)]);
    // PRIVACY: never log the message itself. `text` is the user's plaintext
    // (the ciphertext travels separately in [rawPayload]) and debugPrint keeps
    // writing to the system log in release builds.
    debugPrint(
      '[Proto] encodeTextMessage to=0x${dest.toRadixString(16)} '
      'portnum=$portnum payload=${payloadBytes.length}B '
      'bytes=${toRadio.length}',
    );
    return toRadio;
  }

  // Decode FromRadio → extract local node num from MyNodeInfo (field 3)
  static int? decodeMyNodeNum(List<int> raw) {
    try {
      final bytes = Uint8List.fromList(raw);
      final myInfo = _readMsg(bytes, 3);
      if (myInfo == null) return null;
      return _readVarint(myInfo, 1); // MyNodeInfo.my_node_num
    } on Exception catch (_) {
      return null;
    }
  }

  // Decode FromRadio → extract NodeInfo (for name cache)
  // Returns {nodeId: '!hex', shortName: 'abc', longName: 'Full Name'} or null
  static ({String nodeId, String shortName, String longName})? decodeNodeInfo(
    List<int> raw,
  ) {
    try {
      final bytes = Uint8List.fromList(raw);
      // FromRadio field 4 = NodeInfo
      final nodeInfo = _readMsg(bytes, 4);
      if (nodeInfo == null) return null;
      // NodeInfo.num = field 1 (uint32 varint)
      final num = _readVarint(nodeInfo, 1);
      if (num == null) return null;
      // NodeInfo.user = field 2 (User message)
      final user = _readMsg(nodeInfo, 2);
      if (user == null) return null;
      // User.id = field 1 (string), long_name = field 2, short_name = field 3
      final idBytes = _readMsg(user, 1);
      final longBytes = _readMsg(user, 2);
      final shortBytes = _readMsg(user, 3);
      if (idBytes == null) return null;
      return (
        nodeId: '!${num.toRadixString(16).padLeft(8, '0')}',
        longName: longBytes != null
            ? utf8.decode(longBytes, allowMalformed: true)
            : '',
        shortName: shortBytes != null
            ? utf8.decode(shortBytes, allowMalformed: true)
            : '',
      );
    } on Exception catch (_) {
      return null;
    }
  }

  // Decode FromRadio → extract text message fields
  // Returns: text, from nodeId, to (MeshPacket.to, raw node num), channel
  // slot, meshId, isDm (unicast), portnum (Data.portnum), rawPayload
  // (Data.payload bytes, any portnum).
  //
  // `text` is only populated for TEXT_MESSAGE_APP (portnum=1) payloads,
  // decoded as UTF-8 for backward compatibility with existing callers.
  // `portnum`/`rawPayload` are populated for ANY recognized Data portnum
  // (including PRIVATE_APP) so callers can branch on portnum themselves.
  //
  // `isDm` only says "this is a unicast", NOT "addressed to us" — the radio
  // also hands up unicasts between two other nodes it overheard. Callers that
  // care must compare `to` with their own node num themselves.
  static ({
    String? text,
    String? from,
    int? to,
    int? channel,
    int? meshId,
    bool isDm,
    int? portnum,
    Uint8List? rawPayload,
  })
  decodeFromRadio(List<int> raw) {
    const empty = (
      text: null,
      from: null,
      to: null,
      channel: null,
      meshId: null,
      isDm: false,
      portnum: null,
      rawPayload: null,
    );
    try {
      final bytes = Uint8List.fromList(raw);
      final packet = _readMsg(bytes, 2); // FromRadio field 2 = MeshPacket
      if (packet == null) return empty;

      // MeshPacket: field1=from, field2=to, field3=channel, field6=id, field9=hop_limit
      final fromNode = _readFixed32(packet, 1);
      final toNode = _readFixed32(packet, 2);
      final channel = _readVarint(packet, 3);
      final meshId = _readFixed32(packet, 6);
      final decoded = _readMsg(packet, 4);

      final fromStr = fromNode != null
          ? '!${(fromNode & 0xFFFFFFFF).toRadixString(16).padLeft(8, '0')}'
          : null;

      // isDm = unicast (to != broadcast и to != 0)
      final isDm = toNode != null && toNode != 0xFFFFFFFF && toNode != 0;

      debugPrint(
        '[Proto] from=$fromStr to=0x${toNode?.toRadixString(16)} channel=$channel meshId=$meshId',
      );

      if (decoded == null) return empty;

      final portnum = _readVarint(decoded, 1);
      debugPrint('[Proto] portnum=$portnum');
      if (portnum == null) return empty;

      final payload = _readMsg(decoded, 2);
      if (payload == null) return empty;

      final text = portnum == _portTextMessage
          ? utf8.decode(payload, allowMalformed: true)
          : null;
      // PRIVACY: the decoded text is never logged — see [encodeTextMessage].
      if (text != null) debugPrint('[Proto] received text ${payload.length}B');
      return (
        text: text,
        from: fromStr,
        to: toNode != null ? toNode & 0xFFFFFFFF : null,
        channel: channel,
        meshId: meshId,
        isDm: isDm,
        portnum: portnum,
        rawPayload: payload,
      );
    } on Exception catch (e) {
      debugPrint('[Proto] decode error: $e');
      return empty;
    }
  }

  // ── Модель платы (DeviceMetadata.hw_model) ────────────────────────────
  //
  // Номера полей сверены с meshtastic/protobufs (master):
  //   FromRadio.metadata = 13, DeviceMetadata.hw_model = 9 (enum HardwareModel,
  //   varint). Устройство присылает metadata само в рамках дампа конфига при
  //   подключении (want_config), отдельный запрос не нужен — тот же паттерн,
  //   что и decodeLoraConfig выше.
  //
  // ВАЖНО (см. отчёт спринта): имя модели НЕ говорит о частотном диапазоне
  // платы. Одна и та же модель (например HELTEC_V3) продаётся в
  // региональных вариантах на разное железо (868/915/433 МГц) под одним и
  // тем же hw_model — единственное известное исключение зашито в самом
  // имени (BETAFPV_2400_TX, BETAFPV_900_NANO_TX), остальные ~90 моделей
  // диапазон не кодируют. Поэтому единственная защита от несовместимого
  // диапазона — [LoraRegion.compatibleWith] по уже установленному региону,
  // а не по модели платы.
  static const Map<int, String> _hardwareModelNames = {
    0: 'UNSET',
    1: 'TLORA_V2',
    2: 'TLORA_V1',
    3: 'TLORA_V2_1_1P6',
    4: 'TBEAM',
    5: 'HELTEC_V2_0',
    6: 'TBEAM_V0P7',
    7: 'T_ECHO',
    8: 'TLORA_V1_1P3',
    9: 'RAK4631',
    10: 'HELTEC_V2_1',
    11: 'HELTEC_V1',
    12: 'LILYGO_TBEAM_S3_CORE',
    13: 'RAK11200',
    14: 'NANO_G1',
    15: 'TLORA_V2_1_1P8',
    16: 'TLORA_T3_S3',
    17: 'NANO_G1_EXPLORER',
    18: 'NANO_G2_ULTRA',
    19: 'LORA_TYPE',
    20: 'WIPHONE',
    21: 'WIO_WM1110',
    22: 'RAK2560',
    23: 'HELTEC_HRU_3601',
    24: 'HELTEC_WIRELESS_BRIDGE',
    25: 'STATION_G1',
    26: 'RAK11310',
    27: 'MAKERFABS_TRACKER',
    28: 'MAKERFABS_RESERVED',
    29: 'CANARYONE',
    30: 'RP2040_LORA',
    31: 'STATION_G2',
    32: 'LORA_RELAY_V1',
    33: 'T_ECHO_PLUS',
    34: 'PPR',
    35: 'GENIEBLOCKS',
    36: 'NRF52_UNKNOWN',
    37: 'PORTDUINO',
    38: 'ANDROID_SIM',
    39: 'DIY_V1',
    40: 'NRF52840_PCA10059',
    41: 'DR_DEV',
    42: 'M5STACK',
    43: 'HELTEC_V3',
    44: 'HELTEC_WSL_V3',
    45: 'BETAFPV_2400_TX',
    46: 'BETAFPV_900_NANO_TX',
    47: 'RPI_PICO',
    48: 'HELTEC_WIRELESS_TRACKER',
    49: 'HELTEC_WIRELESS_PAPER',
    50: 'T_DECK',
    51: 'T_WATCH_S3',
    52: 'PICOMPUTER_S3',
    53: 'HELTEC_HT62',
    54: 'EBYTE_ESP32_S3',
    55: 'ESP32_S3_PICO',
    56: 'CHATTER_2',
    57: 'HELTEC_WIRELESS_PAPER_V1_0',
    58: 'HELTEC_WIRELESS_TRACKER_V1_0',
    59: 'UNPHONE',
    60: 'TD_LORAC',
    61: 'CDEBYTE_EORA_S3',
    62: 'TWC_MESH_V4',
    63: 'NRF52_PROMICRO_DIY',
    64: 'RADIOMASTER_900_BANDIT_NANO',
    65: 'HELTEC_CAPSULE_SENSOR_V3',
    66: 'HELTEC_VISION_MASTER_T190',
    67: 'HELTEC_VISION_MASTER_E213',
    68: 'HELTEC_VISION_MASTER_E290',
    69: 'HELTEC_MESH_NODE_T114',
    70: 'SENSECAP_INDICATOR',
    71: 'TRACKER_T1000_E',
    72: 'RAK3172',
    73: 'WIO_E5',
    74: 'RADIOMASTER_900_BANDIT',
    75: 'ME25LS01_4Y10TD',
    76: 'RP2040_FEATHER_RFM95',
    77: 'M5STACK_COREBASIC',
    78: 'M5STACK_CORE2',
    79: 'RPI_PICO2',
    80: 'M5STACK_CORES3',
    81: 'SEEED_XIAO_S3',
    82: 'MS24SF1',
    83: 'TLORA_C6',
    84: 'WISMESH_TAP',
    85: 'ROUTASTIC',
    86: 'MESH_TAB',
    87: 'MESHLINK',
    88: 'XIAO_NRF52_KIT',
    89: 'THINKNODE_M1',
    90: 'THINKNODE_M2',
    91: 'T_ETH_ELITE',
    92: 'HELTEC_SENSOR_HUB',
    255: 'PRIVATE_HW',
  };

  /// Имя модели платы (`HardwareModel`) из `DeviceMetadata.hw_model`, или
  /// null, если кадр не содержит metadata либо модель не UNSET/незнакома
  /// (новая прошивка может прислать значение, которого мы ещё не знаем —
  /// тогда честнее вернуть null, чем соврать именем).
  static String? decodeHwModel(List<int> raw) {
    try {
      final bytes = Uint8List.fromList(raw);
      final metadata = _readMsg(bytes, 13); // FromRadio.metadata
      if (metadata == null) return null;
      final hwModel = _readVarint(metadata, 9); // DeviceMetadata.hw_model
      if (hwModel == null) return null;
      return _hardwareModelNames[hwModel];
    } on Exception catch (e) {
      debugPrint('[Proto] hw_model decode error: $e');
      return null;
    }
  }

  // Extract sender node ID from any FromRadio MeshPacket (field2.field1 = from)
  // Returns '!hex' or null if not a MeshPacket frame
  static String? extractSender(List<int> raw) {
    try {
      final bytes = Uint8List.fromList(raw);
      final packet = _readMsg(bytes, 2);
      if (packet == null) return null;
      final fromNode = _readFixed32(packet, 1);
      if (fromNode == null || fromNode == 0) return null;
      return '!${(fromNode & 0xFFFFFFFF).toRadixString(16).padLeft(8, '0')}';
    } on Exception catch (_) {
      return null;
    }
  }

  // Decode ROUTING_APP (portnum=5) ACK → meshId + errorCode (+ имя ошибки).
  static ({int meshId, int errorCode, String errorName})? decodeRoutingAck(
    List<int> raw,
  ) {
    try {
      final bytes = Uint8List.fromList(raw);
      final packet = _readMsg(bytes, 2);
      if (packet == null) return null;
      final decoded = _readMsg(packet, 4);
      if (decoded == null) return null;
      final portnum = _readVarint(decoded, 1);
      if (portnum != 5) return null; // ROUTING_APP
      // Data.payload = Routing message; request_id в Data field 6
      final requestId = _readFixed32(decoded, 6) ?? 0;
      final routingPayload = _readMsg(decoded, 2);
      final errorCode = routingPayload != null
          ? (_readVarint(routingPayload, 3) ?? 0)
          : 0;
      return (
        meshId: requestId,
        errorCode: errorCode,
        errorName: routingErrorName(errorCode),
      );
    } on Exception catch (_) {
      return null;
    }
  }

  // Человекочитаемые имена `Routing.Error` (meshtastic/protobufs → mesh.proto,
  // enum Error). Нужны, чтобы в логе было видно `NOT_AUTHORIZED`,
  // `ADMIN_BAD_SESSION_KEY` и т.п., а не голое число.
  static String routingErrorName(int code) {
    const names = {
      0: 'NONE',
      1: 'NO_ROUTE',
      2: 'GOT_NAK',
      3: 'TIMEOUT',
      4: 'NO_INTERFACE',
      5: 'MAX_RETRANSMIT',
      6: 'NO_CHANNEL',
      7: 'TOO_LARGE',
      8: 'NO_RESPONSE',
      9: 'DUTY_CYCLE_LIMIT',
      32: 'BAD_REQUEST',
      33: 'NOT_AUTHORIZED',
      34: 'PKI_FAILED',
      35: 'PKI_UNKNOWN_PUBKEY',
      36: 'ADMIN_BAD_SESSION_KEY',
      37: 'ADMIN_PUBLIC_KEY_UNAUTHORIZED',
      38: 'RATE_LIMIT_EXCEEDED',
      39: 'PKI_SEND_FAIL_PUBLIC_KEY',
    };
    return names[code] ?? 'UNKNOWN($code)';
  }

  // Разбирает ответ AdminMessage (portnum=ADMIN_APP=6), если устройство его
  // прислало. Возвращает request_id (Data.field6) и номер поля oneof
  // payload_variant, которое пришло в ответе — этого достаточно для
  // диагностики "устройство вообще увидело админ-команду и что-то ответило".
  // Точное декодирование конкретных ответов (get_config_response и т.п.) не
  // нужно для диагностики региона — молчание устройства как раз и было
  // проблемой, а не непонятный ответ.
  static ({int meshId, int variantTag})? decodeAdminResponse(List<int> raw) {
    try {
      final bytes = Uint8List.fromList(raw);
      final packet = _readMsg(bytes, 2);
      if (packet == null) return null;
      final decoded = _readMsg(packet, 4);
      if (decoded == null) return null;
      final portnum = _readVarint(decoded, 1);
      if (portnum != _adminPort) return null; // ADMIN_APP
      final requestId = _readFixed32(decoded, 6) ?? 0;
      final admin = _readMsg(decoded, 2);
      final tag = admin != null ? _firstFieldTag(admin) : null;
      return (meshId: requestId, variantTag: tag ?? -1);
    } on Exception catch (_) {
      return null;
    }
  }

  // Номер первого поля верхнего уровня в [data] (любой wire type), или null
  // для пустого/испорченного сообщения. Используется только для диагностики
  // (decodeAdminResponse) — AdminMessage это oneof, поэтому единственное
  // заполненное поле и есть искомый вариант ответа.
  static int? _firstFieldTag(Uint8List data) {
    if (data.isEmpty) return null;
    final t = _decVarint(data, 0);
    return t.$1 >> 3;
  }

  // ── Encoding ──────────────────────────────────────────────

  static Uint8List _buf(List<Uint8List> parts) =>
      Uint8List.fromList(parts.expand((p) => p).toList());

  static Uint8List _varint(int field, int value) {
    return Uint8List.fromList([
      ..._encVarint((field << 3) | 0), // tag: wire type 0
      ..._encVarint(value),
    ]);
  }

  static Uint8List _fixed32field(int field, int value) {
    return Uint8List.fromList([
      ..._encVarint((field << 3) | 5), // tag: wire type 5
      value & 0xFF,
      (value >> 8) & 0xFF,
      (value >> 16) & 0xFF,
      (value >> 24) & 0xFF,
    ]);
  }

  static Uint8List _bytes(int field, Uint8List data) {
    return Uint8List.fromList([
      ..._encVarint((field << 3) | 2), // tag: wire type 2
      ..._encVarint(data.length),
      ...data,
    ]);
  }

  static Uint8List _msg(int field, Uint8List data) => _bytes(field, data);

  static List<int> _encVarint(int v) {
    final out = <int>[];
    var value = v;
    while (value > 0x7F) {
      out.add((value & 0x7F) | 0x80);
      value >>>= 7;
    }
    out.add(value & 0x7F);
    return out;
  }

  // ── Decoding ──────────────────────────────────────────────

  static Uint8List? _readMsg(Uint8List data, int field) {
    var pos = 0;
    while (pos < data.length) {
      final r = _decVarint(data, pos);
      pos = r.$2;
      final tag = r.$1;
      final f = tag >> 3;
      final wt = tag & 7;
      if (wt == 0) {
        final v = _decVarint(data, pos);
        if (f == field) return Uint8List.fromList(_encVarint(v.$1));
        pos = v.$2;
      } else if (wt == 2) {
        final l = _decVarint(data, pos);
        pos = l.$2;
        final end = pos + l.$1;
        // Length taken from untrusted bytes: reject if it overruns the
        // buffer OR is negative (10-byte varint with the low bit of the
        // last byte set — see _decVarint) so sublist() cannot throw
        // RangeError (an Error, which the `on Exception` wrappers would
        // NOT catch).
        if (end > data.length || end < pos) return null;
        if (f == field) return Uint8List.fromList(data.sublist(pos, end));
        pos = end;
      } else if (wt == 5) {
        // fixed32
        if (pos + 4 > data.length) break;
        pos += 4;
      } else if (wt == 1) {
        // fixed64
        if (pos + 8 > data.length) break;
        pos += 8;
      } else {
        break;
      }
    }
    return null;
  }

  static int? _readVarint(Uint8List data, int field) {
    var pos = 0;
    while (pos < data.length) {
      final r = _decVarint(data, pos);
      pos = r.$2;
      final tag = r.$1;
      final f = tag >> 3;
      final wt = tag & 7;
      if (wt == 0) {
        final v = _decVarint(data, pos);
        if (f == field) return v.$1;
        pos = v.$2;
      } else if (wt == 2) {
        final l = _decVarint(data, pos);
        final end = l.$2 + l.$1;
        // Malformed/oversized length from untrusted bytes (including a
        // negative length from a 10-byte varint — see _decVarint): stop
        // scanning instead of walking pos past the buffer or backwards.
        if (end > data.length || end < l.$2) break;
        pos = end;
      } else if (wt == 5) {
        if (pos + 4 > data.length) break;
        pos += 4;
      } else if (wt == 1) {
        if (pos + 8 > data.length) break;
        pos += 8;
      } else {
        break;
      }
    }
    return null;
  }

  // Read a fixed32 field (wire type 5, 4 bytes little-endian)
  static int? _readFixed32(Uint8List data, int field) {
    var pos = 0;
    while (pos < data.length) {
      final r = _decVarint(data, pos);
      pos = r.$2;
      final tag = r.$1;
      final f = tag >> 3;
      final wt = tag & 7;
      if (wt == 5) {
        if (pos + 4 > data.length) break;
        if (f == field) {
          return data[pos] |
              (data[pos + 1] << 8) |
              (data[pos + 2] << 16) |
              (data[pos + 3] << 24);
        }
        pos += 4;
      } else if (wt == 0) {
        final v = _decVarint(data, pos);
        pos = v.$2;
      } else if (wt == 2) {
        final l = _decVarint(data, pos);
        final end = l.$2 + l.$1;
        // Malformed/oversized length from untrusted bytes (including a
        // negative length from a 10-byte varint — see _decVarint): stop
        // scanning instead of walking pos past the buffer or backwards.
        if (end > data.length || end < l.$2) break;
        pos = end;
      } else if (wt == 1) {
        if (pos + 8 > data.length) break;
        pos += 8;
      } else {
        break;
      }
    }
    return null;
  }

  static (int, int) _decVarint(Uint8List data, int pos) {
    var result = 0;
    var shift = 0;
    var currentPos = pos;
    while (currentPos < data.length) {
      final b = data[currentPos++];
      // Dart's `int` is a signed 64-bit value: shifting a bit into position
      // 63 (the 10th varint byte) sets the sign bit and turns an otherwise
      // valid-looking field length into a negative number, which later
      // survives an `end > data.length` check (a negative end is always
      // "not greater than" the buffer length) and reaches
      // `data.sublist(pos, end)` with `end < pos`, which throws a
      // `RangeError` — an `Error`, not caught by `on Exception` wrappers.
      // We only ever need this for varints, whose values are lengths well
      // under 2^63, so bits at shift >= 63 are simply discarded: result
      // stays non-negative instead of "almost always" non-negative.
      if (shift < 63) {
        result |= (b & 0x7F) << shift;
      }
      if ((b & 0x80) == 0) break;
      shift += 7;
      // A varint is at most 10 bytes (70 bits). Cap the shift so a stream
      // of continuation bytes can't spin unboundedly on crafted input.
      if (shift > 63) break;
    }
    return (result, currentPos);
  }
}
