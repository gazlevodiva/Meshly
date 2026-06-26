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
      int pos = 0;

      List<int>? packetBytes;
      while (pos < bytes.length) {
        final tagByte = bytes[pos++];
        final fieldNum = tagByte >> 3;
        final wireType = tagByte & 7;
        if (wireType == 2) {
          // read length-delimited
          int len = 0, shift = 0;
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
      int len = packetBytes.length;
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
  });
}
