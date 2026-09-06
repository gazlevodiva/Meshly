import 'dart:typed_data';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meshly/models/message.dart';
import 'package:meshly/services/app_database.dart';
import 'package:meshly/services/channel_manager.dart';
import 'package:meshly/services/contact_store.dart';
import 'package:meshly/services/crypto_service.dart';
import 'package:meshly/services/mesh_service.dart';
import 'package:meshly/services/meshtastic_proto.dart';

// Re-wraps ToRadio { field1: MeshPacket } as FromRadio { field2: MeshPacket }
// so MeshtasticProto.decodeFromRadio (which expects a FromRadio-shaped
// frame) can read back what MeshService just sent — same helper as
// mesh_service_test.dart uses for the same purpose.
List<int> _toFromRadio(List<int> toRadioBytes) {
  final bytes = List<int>.from(toRadioBytes);
  var pos = 0;
  List<int>? packetBytes;
  while (pos < bytes.length) {
    final tagByte = bytes[pos++];
    final fieldNum = tagByte >> 3;
    final wireType = tagByte & 7;
    if (wireType != 2) break;
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
  }
  if (packetBytes == null) return [];
  var len = packetBytes.length;
  final lenBytes = <int>[];
  while (len > 0x7F) {
    lenBytes.add((len & 0x7F) | 0x80);
    len >>= 7;
  }
  lenBytes.add(len);
  return [18, ...lenBytes, ...packetBytes]; // tag: field 2, wire type 2
}

// FromRadio { my_info: MyNodeInfo { my_node_num } } — the first frame the
// radio sends after want_config. A service that has not seen it does not
// know its own node id, and the announced name falls back to that id.
List<int> _myNodeInfoFrame(int nodeNum) {
  final numVarint = <int>[];
  var v = nodeNum;
  while (v > 0x7F) {
    numVarint.add((v & 0x7F) | 0x80);
    v >>>= 7;
  }
  numVarint.add(v);
  final myInfo = <int>[0x08, ...numVarint]; // field 1, varint
  return [26, myInfo.length, ...myInfo]; // field 3, wire type 2
}

void main() {
  final store = ContactStore.instance;
  final manager = ChannelManager.instance;

  setUp(() async {
    store.resetForTesting(AppDatabase.forTesting(NativeDatabase.memory()));
    await store.init();
  });

  group('ChannelManager.create', () {
    test('generates 32-byte PSK and persists the channel', () async {
      final meshService = MeshService();
      final ch = await manager.create(
        name: 'Семья',
        avatarEmoji: '🏠',
        meshService: meshService,
      );

      expect(ch.psk.length, equals(32));
      expect(ch.name, equals('Семья'));
      expect(ch.avatarEmoji, equals('🏠'));

      // Persisted in the store.
      expect(store.channelById(ch.id), isNotNull);
      expect(store.channels.map((c) => c.id), contains(ch.id));
    });

    test(
      'not connected MeshService: create does not throw (no device write)',
      () async {
        final meshService = MeshService();
        expect(meshService.isConnected, isFalse);

        expect(
          () => manager.create(
            name: 'Test',
            avatarEmoji: null,
            meshService: meshService,
          ),
          returnsNormally,
        );
      },
    );

    // Slots no longer limit conversations: the seventh used to be the last
    // one created, now there can be any number of them (see the sprint
    // report "decoupling conversations from Meshtastic slots").
    test('more than seven conversations can be created', () async {
      final meshService = MeshService();
      for (var i = 0; i < 10; i++) {
        final ch = await manager.create(
          name: 'ch$i',
          avatarEmoji: null,
          meshService: meshService,
        );
        expect(ch.name, equals('ch$i'));
      }
      expect(store.channels, hasLength(10));
    });
  });

  group('ChannelManager.addFromQr', () {
    Uint8List psk() => Uint8List.fromList(List.generate(32, (i) => i));

    test('adds a channel without any slot argument', () async {
      final meshService = MeshService();
      final ch = await manager.addFromQr(
        name: 'Any',
        psk: psk(),
        avatarEmoji: null,
        meshService: meshService,
      );
      expect(ch.name, equals('Any'));
      expect(store.channels, hasLength(1));
    });

    test('preserves the given PSK bytes exactly', () async {
      final meshService = MeshService();
      final givenPsk = psk();
      final ch = await manager.addFromQr(
        name: 'PskCheck',
        psk: givenPsk,
        avatarEmoji: null,
        meshService: meshService,
      );
      expect(ch.psk, equals(givenPsk));
    });

    // Scanning a QR is how the user *joins* an existing conversation, so it
    // must leave a "joined" system event behind — otherwise the very first
    // entry in a conversation's history would silently be missing (our own
    // broadcast never comes back to us over the air).
    test(
      'records a local "joined" event carrying the name we announced',
      () async {
        final meshService = MeshService();
        addTearDown(meshService.dispose);
        await meshService.handleIncomingBytes(_myNodeInfoFrame(0x1f8e42c9));

        final ch = await manager.addFromQr(
          name: 'Hikers',
          psk: psk(),
          avatarEmoji: null,
          meshService: meshService,
        );

        final conv = store.conversationById('ch_${ch.id}');
        expect(conv, isNotNull);
        final messages = store.messagesFor(conv!.id);
        expect(messages, hasLength(1));
        expect(messages.single.isSystemEvent, isTrue);
        expect(messages.single.eventKind, equals(SystemEventKind.joined));
        expect(messages.single.isMe, isTrue);
        // The name matters: an empty one renders as a line that starts with
        // the verb and has no subject.
        expect(messages.single.text, equals(meshService.myAnnouncedName));
        expect(messages.single.text, isNotEmpty);
        // Not a message from a person: must not have inflated the badge.
        expect(conv.unreadCount, equals(0));
      },
    );

    test(
      'records nothing when our own name is not known yet: an empty name '
      'would render as a subjectless line',
      () async {
        final meshService = MeshService();
        addTearDown(meshService.dispose);
        // No MyNodeInfo yet — the window between connecting and the radio
        // telling us who we are.
        expect(meshService.myAnnouncedName, isEmpty);

        final ch = await manager.addFromQr(
          name: 'Hikers',
          psk: psk(),
          avatarEmoji: null,
          meshService: meshService,
        );

        final conv = store.conversationById('ch_${ch.id}');
        expect(store.messagesFor(conv!.id), isEmpty);
      },
    );

    test(
      'broadcasts a "joined" announcement over the air when connected',
      () async {
        final meshService = MeshService();
        addTearDown(meshService.dispose);
        await meshService.handleIncomingBytes(_myNodeInfoFrame(0x1f8e42c9));
        final sent = <Uint8List>[];
        meshService.debugRadioSink = sent.add;

        final givenPsk = psk();
        await manager.addFromQr(
          name: 'Hikers',
          psk: givenPsk,
          avatarEmoji: null,
          meshService: meshService,
        );

        expect(sent, hasLength(1));
        final packet = MeshtasticProto.decodeFromRadio(
          _toFromRadio(sent.single),
        );
        expect(packet.portnum, equals(MeshtasticProto.PRIVATE_APP));
        expect(packet.rawPayload, isNotNull);
        final decoded = await CryptoService.instance.decryptForChannel(
          psk: givenPsk,
          envelope: packet.rawPayload!,
        );
        expect(decoded, isNotNull);
        final event = decodeSystemEvent(decoded!);
        expect(event, isNotNull);
        expect(event!.kind, equals(SystemEventKind.joined));
      },
    );
  });
}
