import 'dart:convert';
import 'package:flutter/foundation.dart';

// Manual minimal protobuf for Meshtastic
// ToRadio(1=MeshPacket) → MeshPacket(1=to, 3=id, 4=Data, 9=channel)
// Data(1=portnum, 2=payload)

class MeshtasticProto {
  static const int _broadcastAddr = 0xFFFFFFFF;
  static const int _portTextMessage = 1; // TEXT_MESSAGE_APP

  // ToRadio { want_config_id: id } — initiates BLE session, device starts sending packets
  static Uint8List encodeWantConfig() {
    final id = DateTime.now().millisecondsSinceEpoch & 0x7FFFFFFF;
    return _buf([_varint(3, id)]);
  }

  // AdminMessage { set_channel: Channel } → записывает канал в девайс
  // portnum=68 (ADMIN_APP), отправляется unicast к своему node ID
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
      _varint(3, 0),              // primary channel (admin uses ch0)
      _msg(4, data),
      _fixed32field(6, msgId),
      _varint(9, 1),              // hop_limit=1 (local only)
    ]);

    return _buf([_msg(1, packet)]);
  }

  static Uint8List encodeTextMessage(String text, {int? to, int channel = 0, int? fromNode}) {
    final dest = to ?? _broadcastAddr;
    final textBytes = Uint8List.fromList(utf8.encode(text));
    final msgId = DateTime.now().millisecondsSinceEpoch & 0x7FFFFFFF;

    final data = _buf([
      _varint(1, _portTextMessage),
      _bytes(2, textBytes),
    ]);

    // Proto: field1=from, field2=to, field3=channel, field4=decoded, field6=id(fixed32), field9=hop_limit
    final packet = _buf([
      if (fromNode != null) _fixed32field(1, fromNode),  // from = our node ID
      _fixed32field(2, dest),                            // to = destination
      _varint(3, channel),                               // channel = slot index
      _msg(4, data),
      _fixed32field(6, msgId),                           // id = fixed32
      _varint(9, 3),                                     // hop_limit = 3
    ]);

    final toRadio = _buf([_msg(1, packet)]);
    debugPrint('[Proto] encodeTextMessage to=0x${dest.toRadixString(16)} text="$text" bytes=${toRadio.length}: $toRadio');
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
  static ({String nodeId, String shortName, String longName})? decodeNodeInfo(List<int> raw) {
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
        longName: longBytes != null ? utf8.decode(longBytes) : '',
        shortName: shortBytes != null ? utf8.decode(shortBytes) : '',
      );
    } on Exception catch (_) {
      return null;
    }
  }

  // Decode FromRadio → extract text message fields
  // Returns: text, from nodeId, channel slot, meshId, isDm (unicast)
  static ({String? text, String? from, int? channel, int? meshId, bool isDm}) decodeFromRadio(List<int> raw) {
    const empty = (text: null, from: null, channel: null, meshId: null, isDm: false);
    try {
      final bytes = Uint8List.fromList(raw);
      final packet = _readMsg(bytes, 2); // FromRadio field 2 = MeshPacket
      if (packet == null) return empty;

      // MeshPacket: field1=from, field2=to, field3=channel, field6=id, field9=hop_limit
      final fromNode = _readFixed32(packet, 1);
      final toNode   = _readFixed32(packet, 2);
      final channel  = _readVarint(packet, 3);
      final meshId   = _readFixed32(packet, 6);
      final decoded  = _readMsg(packet, 4);

      final fromStr = fromNode != null
          ? '!${(fromNode & 0xFFFFFFFF).toRadixString(16).padLeft(8, '0')}'
          : null;

      // isDm = unicast (to != broadcast и to != 0)
      final isDm = toNode != null && toNode != 0xFFFFFFFF && toNode != 0;

      debugPrint('[Proto] from=$fromStr to=0x${toNode?.toRadixString(16)} channel=$channel meshId=$meshId');

      if (decoded == null) return empty;

      final portnum = _readVarint(decoded, 1);
      debugPrint('[Proto] portnum=$portnum');
      if (portnum != _portTextMessage) return empty;

      final payload = _readMsg(decoded, 2);
      if (payload == null) return empty;

      final text = utf8.decode(payload);
      debugPrint('[Proto] received text="$text"');
      return (text: text, from: fromStr, channel: channel, meshId: meshId, isDm: isDm);
    } on Exception catch (e) {
      debugPrint('[Proto] decode error: $e');
      return empty;
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

  // Decode ROUTING_APP (portnum=5) ACK → meshId + errorCode
  static ({int meshId, int errorCode})? decodeRoutingAck(List<int> raw) {
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
      final errorCode = routingPayload != null ? (_readVarint(routingPayload, 3) ?? 0) : 0;
      return (meshId: requestId, errorCode: errorCode);
    } on Exception catch (_) {
      return null;
    }
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
        if (f == field) return Uint8List.fromList(data.sublist(pos, end));
        pos = end;
      } else if (wt == 5) { // fixed32
        if (pos + 4 > data.length) break;
        pos += 4;
      } else if (wt == 1) { // fixed64
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
        pos = l.$2 + l.$1;
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
          return data[pos] | (data[pos+1] << 8) | (data[pos+2] << 16) | (data[pos+3] << 24);
        }
        pos += 4;
      } else if (wt == 0) {
        final v = _decVarint(data, pos);
        pos = v.$2;
      } else if (wt == 2) {
        final l = _decVarint(data, pos);
        pos = l.$2 + l.$1;
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
      result |= (b & 0x7F) << shift;
      if ((b & 0x80) == 0) break;
      shift += 7;
    }
    return (result, currentPos);
  }
}
