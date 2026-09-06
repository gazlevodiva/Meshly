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

  // ── Radio region (LoRaConfig) ───────────────────────────────────────────
  //
  // Field numbers checked against meshtastic/protobufs (master):
  //   FromRadio.config = 5, Config.lora = 6, LoRaConfig.region = 7,
  //   AdminMessage.set_config = 34, begin_edit_settings = 64,
  //   commit_edit_settings = 65.
  // This used to also have encodeSetChannel (AdminMessage.set_channel) —
  // removed in the sprint that decoupled conversations from Meshtastic
  // slots: it had both the wrong field number (it wrote 11, but set_channel
  // is 33) and the wrong packet `from` field (it was fromNode instead of
  // the zero the firmware requires), and — which turned out to be the
  // systemic cause of both failures — a port bug shared by all admin
  // commands, see below.
  //
  // ROOT CAUSE FOUND (2026-09): every admin command (both region and
  // channel) went out with Data.portnum = 68. In meshtastic/protobufs
  // (portnums.proto) 68 is ZPS_APP, while ADMIN_APP = 6. The firmware
  // (PhoneAPI::handleToRadioPacket → MeshService::handleToRadio →
  // Router::sendLocal) honestly accepts the packet from BLE (hence the
  // GATT_SUCCESS on the characteristic write) and delivers it to itself
  // locally (to == its own node num), but the module dispatcher
  // (FloodingRouter/Router::perhapsHandleReceived → MeshModule::callPlugins,
  // src/mesh/Router.cpp) looks for a module subscribed to that specific
  // portnum — AdminModule is subscribed to ADMIN_APP=6, not to 68. There's
  // no module for portnum=68, so the packet is silently dropped before it
  // ever reaches AdminModule::handleReceivedProtobuf: hence the silence —
  // no NAK, no ADMIN_BAD_SESSION_KEY, no reboot. Reading the config worked
  // independently of this path: it's not an AdminMessage request, it's part
  // of the automatic config dump on connect (PhoneAPI STATE_SEND_CONFIG),
  // so nothing dropped it.
  static const int _adminPort = 6; // ADMIN_APP (was 68 = ZPS_APP — a bug)
  static int _adminSeq = 0;

  /// Raw `LoRaConfig` bytes exactly as sent by the device + the parsed
  /// region (0 = UNSET, the device doesn't transmit at all).
  ///
  /// The raw bytes are needed specifically as bytes: [encodeSetRegion]
  /// patches a single field in them rather than rebuilding the message —
  /// that way all settings we don't know about (modem preset, power, fields
  /// added by newer firmware) survive untouched.
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

  /// Three ToRadio frames that change the region and nothing else:
  /// `begin_edit_settings` → `set_config{lora}` → `commit_edit_settings`.
  ///
  /// [currentLora] has to be the bytes from [decodeLoraConfig]: `set_config`
  /// replaces the whole `LoRaConfig`, so a message built from scratch would
  /// silently wipe the user's modem preset, hop limit, and power.
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

  // AdminMessage → a MeshPacket to ourselves, hop_limit=1: the packet never
  // goes out over the air.
  static Uint8List _adminFrame(Uint8List admin, int fromNode) {
    final data = _buf([_varint(1, _adminPort), _bytes(2, admin)]);
    // A distinct id per frame: the radio would treat three frames in a row
    // with the same id as duplicates and only execute the first one.
    final msgId =
        (DateTime.now().millisecondsSinceEpoch + _adminSeq++) & 0x7FFFFFFF;
    final packet = _buf([
      // from = 0 — MANDATORY. The firmware treats only an admin command
      // with from == 0 as local (and therefore trusted): it fills in its
      // own node number itself. With a non-zero from, the command is
      // treated as remote administration, requires a session key, and is
      // silently rejected (AdminModule::handleReceivedProtobuf → "Ignore
      // unauthorized admin payload"). This is exactly why writing a channel
      // to the device (the removed encodeSetChannel) never worked.
      _fixed32field(1, 0),
      _fixed32field(2, fromNode), // addressed to the device itself
      _varint(3, 0), // admin travels over the primary channel
      _msg(4, data),
      _fixed32field(6, msgId),
      _varint(9, 1), // hop_limit=1 — local only
    ]);
    return _buf([_msg(1, packet)]);
  }

  /// A byte-for-byte copy of [msg] with the varint field [field] replaced by
  /// [value] (or appended, if it wasn't present). All other fields are
  /// carried over as-is, including ones we don't know about.
  ///
  /// On a corrupted message, returns the original untouched: better to not
  /// change the region at all than to send the device a truncated config.
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
          return msg; // unknown wire type — leave the message untouched
      }
      // end < pos catches a negative length from an overflowed varint.
      if (end > msg.length || end < pos) return msg;
      if (f != field) out.addAll(msg.sublist(tagStart, end));
      pos = end;
    }
    out.addAll(_varint(field, value));
    return Uint8List.fromList(out);
  }

  // `id` is our packet id (MeshPacket.id, field 6). The radio uses it as-is,
  // and the ROUTING ACK comes back with this same id in Data.request_id —
  // that's how we match the delivery confirmation to the message in the
  // store.
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
      _varint(10, 1), // want_ack = true → firmware generates an end-to-end ACK
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

      // isDm = unicast (to != broadcast and to != 0)
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

  // ── Board model (DeviceMetadata.hw_model) ───────────────────────────────
  //
  // Field numbers checked against meshtastic/protobufs (master):
  //   FromRadio.metadata = 13, DeviceMetadata.hw_model = 9 (enum HardwareModel,
  //   varint). The device sends metadata on its own as part of the config
  //   dump on connect (want_config), no separate request needed — the same
  //   pattern as decodeLoraConfig above.
  //
  // IMPORTANT (see the sprint report): the model name does NOT indicate the
  // board's frequency band. The same model (e.g. HELTEC_V3) is sold in
  // regional variants on different hardware (868/915/433 MHz) under the
  // same hw_model — the only known exception is baked into the name itself
  // (BETAFPV_2400_TX, BETAFPV_900_NANO_TX), the remaining ~90 models don't
  // encode a band. That's why the only guard against an incompatible band
  // is [LoraRegion.compatibleWith] based on the already-set region, not on
  // the board model.
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

  /// Board model name (`HardwareModel`) from `DeviceMetadata.hw_model`, or
  /// null if the frame has no metadata, or the model is UNSET/unrecognized
  /// (newer firmware may send a value we don't know about yet — in that
  /// case it's more honest to return null than to lie about the name).
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

  // Decode ROUTING_APP (portnum=5) ACK → meshId + errorCode (+ error name).
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
      // Data.payload = Routing message; request_id is in Data field 6
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

  // Human-readable names for `Routing.Error` (meshtastic/protobufs →
  // mesh.proto, enum Error). Needed so the log shows `NOT_AUTHORIZED`,
  // `ADMIN_BAD_SESSION_KEY` etc. instead of a bare number.
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

  // Parses an AdminMessage reply (portnum=ADMIN_APP=6), if the device sent
  // one. Returns the request_id (Data.field6) and the number of the oneof
  // payload_variant field that came in the reply — that's enough to
  // diagnose "the device actually saw the admin command and replied with
  // something". Decoding the specific replies exactly (get_config_response
  // etc.) isn't needed for diagnosing the region — the device's silence was
  // precisely the problem, not a confusing reply.
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

  // Number of the first top-level field in [data] (any wire type), or null
  // for an empty/corrupted message. Used only for diagnostics
  // (decodeAdminResponse) — AdminMessage is a oneof, so the single field
  // that's set is exactly the reply variant we're looking for.
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
