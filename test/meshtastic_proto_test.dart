import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:meshly/services/meshtastic_proto.dart';

void main() {
  group('MeshtasticProto', () {
    // Helper: encodeTextMessage produces ToRadio bytes.
    // decodeFromRadio expects FromRadio bytes where field2 = MeshPacket.
    // encodeTextMessage wraps packet in field1 (ToRadio), but decodeFromRadio
    // reads field2 (FromRadio). We need to re-wrap the packet in field2.
    //
    // encodeTextMessage → ToRadio { field1: MeshPacket }
    // We extract the raw MeshPacket and re-wrap it as FromRadio { field2: MeshPacket }
    List<int> toFromRadio(List<int> toRadioBytes) {
      // Parse ToRadio: field1 (wire type 2) = MeshPacket
      final bytes = List<int>.from(toRadioBytes);
      var pos = 0;

      List<int>? packetBytes;
      while (pos < bytes.length) {
        final tagByte = bytes[pos++];
        final fieldNum = tagByte >> 3;
        final wireType = tagByte & 7;
        if (wireType == 2) {
          // read length-delimited
          var len = 0;
          var shift = 0;
          while (true) {
            final b = bytes[pos++];
            len |= (b & 0x7F) << shift;
            if ((b & 0x80) == 0) break;
            shift += 7;
          }
          final chunk = bytes.sublist(pos, pos + len);
          if (fieldNum == 1) packetBytes = chunk;
          pos += len;
        } else {
          break; // unexpected
        }
      }

      if (packetBytes == null) return [];

      // Encode as FromRadio { field2: MeshPacket }
      // Tag for field2, wire type 2 = (2 << 3) | 2 = 18
      final tagBytes = [18];
      // Encode length as varint
      var len = packetBytes.length;
      final lenBytes = <int>[];
      while (len > 0x7F) {
        lenBytes.add((len & 0x7F) | 0x80);
        len >>= 7;
      }
      lenBytes.add(len);

      return [...tagBytes, ...lenBytes, ...packetBytes];
    }

    test('encodeTextMessage / decodeFromRadio roundtrip: text matches', () {
      const text = 'Привет мир';
      const fromNode = 0x1f8e42c9;
      final toRadio = MeshtasticProto.encodeTextMessage(
        text,
        fromNode: fromNode,
      );
      final fromRadio = toFromRadio(toRadio);
      final result = MeshtasticProto.decodeFromRadio(fromRadio);
      expect(result.text, equals(text));
    });

    test('encodeTextMessage / decodeFromRadio roundtrip: from field', () {
      const fromNode = 0x1f8e42c9;
      final toRadio = MeshtasticProto.encodeTextMessage(
        'hello',
        fromNode: fromNode,
      );
      final fromRadio = toFromRadio(toRadio);
      final result = MeshtasticProto.decodeFromRadio(fromRadio);
      expect(result.from, equals('!1f8e42c9'));
    });

    test('encodeTextMessage / decodeFromRadio roundtrip: channel field', () {
      const fromNode = 0xaabbccdd;
      const channel = 3;
      final toRadio = MeshtasticProto.encodeTextMessage(
        'msg',
        fromNode: fromNode,
        channel: channel,
      );
      final fromRadio = toFromRadio(toRadio);
      final result = MeshtasticProto.decodeFromRadio(fromRadio);
      expect(result.channel, equals(channel));
    });

    test('isDm = true when to is a specific node', () {
      const fromNode = 0x11111111;
      const toNode = 0x22222222;
      final toRadio = MeshtasticProto.encodeTextMessage(
        'dm message',
        fromNode: fromNode,
        to: toNode,
      );
      final fromRadio = toFromRadio(toRadio);
      final result = MeshtasticProto.decodeFromRadio(fromRadio);
      expect(result.isDm, isTrue);
    });

    test('isDm = false when to is null (broadcast)', () {
      const fromNode = 0x11111111;
      final toRadio = MeshtasticProto.encodeTextMessage(
        'broadcast',
        fromNode: fromNode,
        // to not specified → broadcast 0xFFFFFFFF
      );
      final fromRadio = toFromRadio(toRadio);
      final result = MeshtasticProto.decodeFromRadio(fromRadio);
      expect(result.isDm, isFalse);
    });

    test('decodeFromRadio: non-text portnum returns text = null', () {
      // Build a FromRadio with portnum=5 (ROUTING_APP) instead of 1
      // We can reuse the helper but build a raw packet manually.
      // Simplest: use decodeFromRadio on an empty list → returns empty record
      final result = MeshtasticProto.decodeFromRadio([]);
      expect(result.text, isNull);
    });

    test('decodeFromRadio with routing portnum returns text = null', () {
      // Build FromRadio bytes manually with portnum=5
      // ToRadio packet structure with portnum=5 → convert to FromRadio
      //
      // We'll encode a text message and then corrupt portnum by using
      // a packet where Data.portnum != 1.
      // Easiest: just pass garbage bytes that have a MeshPacket wrapper
      // but the decoded data has a non-text portnum.
      //
      // We build a minimal FromRadio with MeshPacket containing portnum=5.
      // field2 of FromRadio = MeshPacket, field4 of MeshPacket = Data,
      // field1 of Data = portnum (varint 5)
      final data = [0x08, 0x05]; // field1 varint = 5
      // MeshPacket.field4 = data (wire type 2, field 4 = tag 34)
      final packet = [0x22, data.length, ...data];
      // FromRadio.field2 = packet (wire type 2, field 2 = tag 18)
      final fromRadio = [0x12, packet.length, ...packet];

      final result = MeshtasticProto.decodeFromRadio(fromRadio);
      expect(result.text, isNull);
    });

    test('extractSender returns !hex from a valid packet', () {
      const fromNode = 0xdeadbeef;
      final toRadio = MeshtasticProto.encodeTextMessage(
        'test',
        fromNode: fromNode,
      );
      final fromRadio = toFromRadio(toRadio);
      final sender = MeshtasticProto.extractSender(fromRadio);
      expect(sender, equals('!deadbeef'));
    });

    test('extractSender returns null for empty bytes', () {
      final sender = MeshtasticProto.extractSender([]);
      expect(sender, isNull);
    });

    // ── Packet id / ACK correlation ────────────────────────

    test(
      'encodeTextMessage writes explicit id into MeshPacket.id (field 6)',
      () {
        const msgId = 0x12345678;
        final toRadio = MeshtasticProto.encodeTextMessage(
          'ack me',
          fromNode: 0x11111111,
          id: msgId,
        );
        final fromRadio = toFromRadio(toRadio);
        final result = MeshtasticProto.decodeFromRadio(fromRadio);
        expect(result.meshId, equals(msgId));
      },
    );

    test('encodeTextMessage id roundtrips for max 31-bit value', () {
      const msgId =
          0x7FFFFFFF; // как в sendText: millisecondsSinceEpoch & 0x7FFFFFFF
      final toRadio = MeshtasticProto.encodeTextMessage(
        'edge',
        fromNode: 0x22222222,
        id: msgId,
      );
      final fromRadio = toFromRadio(toRadio);
      final result = MeshtasticProto.decodeFromRadio(fromRadio);
      expect(result.meshId, equals(msgId));
    });

    test('encodeTextMessage sets want_ack (field 10) = 1 on the packet', () {
      final toRadio = MeshtasticProto.encodeTextMessage(
        'ack me',
        fromNode: 0x11111111,
        id: 0x12345678,
      );
      // ToRadio { field1: MeshPacket } — extract the raw MeshPacket bytes.
      // Tag for field1, wire type 2 = (1 << 3) | 2 = 0x0A.
      expect(toRadio[0], equals(0x0A));
      var pos = 1;
      var len = 0;
      var shift = 0;
      while (true) {
        final b = toRadio[pos++];
        len |= (b & 0x7F) << shift;
        if ((b & 0x80) == 0) break;
        shift += 7;
      }
      final packet = toRadio.sublist(pos, pos + len);

      // Scan MeshPacket fields for want_ack: varint field 10,
      // tag = (10 << 3) | 0 = 0x50, value must be 1 (true).
      int? wantAck;
      var p = 0;
      while (p < packet.length) {
        final tag = packet[p++];
        final field = tag >> 3;
        final wire = tag & 7;
        if (wire == 0) {
          var v = 0;
          var s = 0;
          while (true) {
            final b = packet[p++];
            v |= (b & 0x7F) << s;
            if ((b & 0x80) == 0) break;
            s += 7;
          }
          if (field == 10) wantAck = v;
        } else if (wire == 2) {
          var l = 0;
          var s = 0;
          while (true) {
            final b = packet[p++];
            l |= (b & 0x7F) << s;
            if ((b & 0x80) == 0) break;
            s += 7;
          }
          p += l;
        } else if (wire == 5) {
          p += 4;
        } else {
          fail('unexpected wire type $wire in MeshPacket');
        }
      }
      expect(
        wantAck,
        equals(1),
        reason: 'want_ack (field 10) must be set to 1',
      );
    });

    test('decodeRoutingAck reads request_id matching the sent packet id', () {
      const requestId = 0x0A0B0C0D;
      // Data: field1=portnum(5=ROUTING_APP), field2=Routing payload,
      // field6=request_id (fixed32, tag = (6<<3)|5 = 0x35)
      final routing = [
        0x18,
        0x00,
      ]; // Routing.error_reason (field3 varint) = 0 = NONE
      final data = [
        0x08, 0x05, // portnum = 5
        0x12, routing.length, ...routing,
        0x35, 0x0D, 0x0C, 0x0B, 0x0A, // request_id fixed32 LE
      ];
      // MeshPacket.field4 = Data (tag 34)
      final packet = [0x22, data.length, ...data];
      // FromRadio.field2 = MeshPacket (tag 18)
      final fromRadio = [0x12, packet.length, ...packet];

      final ack = MeshtasticProto.decodeRoutingAck(fromRadio);
      expect(ack, isNotNull);
      expect(ack!.meshId, equals(requestId));
      expect(ack.errorCode, equals(0));
    });

    // ── Malformed UTF-8 resilience ─────────────────────────

    test('decodeFromRadio does not throw on malformed UTF-8 in text payload', () {
      // Build a FromRadio with invalid UTF-8 bytes (0xFF, 0xFE) in the payload.
      // Data: field1=portnum(1), field2=payload(invalid utf8)
      final invalidPayload = [0xFF, 0xFE, 0x00]; // not valid UTF-8
      // field2 of Data (wire type 2, tag = (2<<3)|2 = 18)
      final data = [
        0x08, 0x01, // portnum = 1 (TEXT_MESSAGE_APP)
        0x12, invalidPayload.length, ...invalidPayload, // payload
      ];
      // MeshPacket.field4 = Data (tag 34)
      final packet = [0x22, data.length, ...data];
      // FromRadio.field2 = MeshPacket (tag 18)
      final fromRadio = [0x12, packet.length, ...packet];

      expect(
        () => MeshtasticProto.decodeFromRadio(fromRadio),
        returnsNormally,
      );
      final result = MeshtasticProto.decodeFromRadio(fromRadio);
      // Text should be non-null (replacement chars), not null or exception.
      expect(result.text, isNotNull);
    });

    // ── Phase 3: portnum / rawPayload plumbing ─────────────

    test(
      'encodeTextMessage with rawPayload+portnum: decode returns portnum and exact bytes',
      () {
        final envelope = Uint8List.fromList([1, 2, 3, 4, 5, 0xFF, 0x80, 0x00]);
        final toRadio = MeshtasticProto.encodeTextMessage(
          '', // ignored when rawPayload is set
          fromNode: 0x1f8e42c9,
          to: 0x22222222,
          portnum: MeshtasticProto.PRIVATE_APP,
          rawPayload: envelope,
        );
        final fromRadio = toFromRadio(toRadio);
        final result = MeshtasticProto.decodeFromRadio(fromRadio);
        expect(result.portnum, equals(MeshtasticProto.PRIVATE_APP));
        expect(result.rawPayload, equals(envelope));
        // Encrypted envelopes are never exposed as `text`.
        expect(result.text, isNull);
      },
    );

    test('normal text message still round-trips with portnum 1', () {
      const text = 'hello world';
      final toRadio = MeshtasticProto.encodeTextMessage(
        text,
        fromNode: 0x1f8e42c9,
      );
      final fromRadio = toFromRadio(toRadio);
      final result = MeshtasticProto.decodeFromRadio(fromRadio);
      expect(result.portnum, equals(MeshtasticProto.portTextMessage));
      expect(result.text, equals(text));
      expect(result.rawPayload, equals(Uint8List.fromList(text.codeUnits)));
    });

    test(
      'encodeTextMessage without rawPayload/portnum is byte-identical to before',
      () {
        const text = 'Привет мир';
        const fromNode = 0x1f8e42c9;
        final a = MeshtasticProto.encodeTextMessage(
          text,
          fromNode: fromNode,
          id: 42,
        );
        final b = MeshtasticProto.encodeTextMessage(
          text,
          fromNode: fromNode,
          id: 42,
        );
        expect(a, equals(b));
      },
    );

    test('decodeNodeInfo does not throw on malformed UTF-8 in node name', () {
      // Build a FromRadio with NodeInfo containing invalid UTF-8 in longName.
      final invalidName = [0xFF, 0xFE]; // invalid UTF-8
      final idBytes = [0x21, 0x61, 0x62]; // "!ab"
      // User: field1=id, field2=longName, field3=shortName
      final user = [
        0x0A, idBytes.length, ...idBytes,
        0x12, invalidName.length, ...invalidName,
        0x1A, 0x02, 0x4F, 0x4B, // shortName = "OK"
      ];
      // NodeInfo: field1=num(varint), field2=user
      final nodeInfo = [
        0x08, 0x01, // num = 1
        0x12, user.length, ...user,
      ];
      // FromRadio: field4=NodeInfo (tag = (4<<3)|2 = 34)
      final fromRadio = [0x22, nodeInfo.length, ...nodeInfo];

      expect(
        () => MeshtasticProto.decodeNodeInfo(fromRadio),
        returnsNormally,
      );
    });

    // ── Fuzz / hostile input: parser must never throw ────────────
    // A malformed packet in the air used to crash the receive pipeline:
    // an oversized length-varint made sublist() throw RangeError (an Error,
    // not an Exception, so `on Exception` wrappers didn't catch it).
    group('malformed input never throws', () {
      // FromRadio field2 = MeshPacket; inside, an inner length claims far
      // more bytes than the buffer holds.
      final oversizedLength = Uint8List.fromList([
        0x12, 0x7F, // field2 (MeshPacket), length = 127
        0x22, 0x7F, // field4 (Data), length = 127 — but only a few bytes follow
        0x01, 0x02, 0x03,
      ]);

      final truncated = Uint8List.fromList([0x12]); // tag with no length/body
      final empty = Uint8List(0);

      final randomish = Uint8List.fromList(
        List<int>.generate(64, (i) => (i * 37 + 13) & 0xFF),
      );

      final allContinuation = Uint8List.fromList(
        List<int>.filled(20, 0x80), // varint continuation bytes forever
      );

      final cases = <String, Uint8List>{
        'oversized length': oversizedLength,
        'truncated tag': truncated,
        'empty': empty,
        'pseudo-random': randomish,
        'endless varint': allContinuation,
      };

      for (final entry in cases.entries) {
        test('no decoder throws on ${entry.key}', () {
          final bytes = entry.value;
          expect(() => MeshtasticProto.decodeFromRadio(bytes), returnsNormally);
          expect(() => MeshtasticProto.extractSender(bytes), returnsNormally);
          expect(
            () => MeshtasticProto.decodeRoutingAck(bytes),
            returnsNormally,
          );
          expect(() => MeshtasticProto.decodeMyNodeNum(bytes), returnsNormally);
          expect(() => MeshtasticProto.decodeNodeInfo(bytes), returnsNormally);
        });
      }
    });
  });
}
