import 'dart:typed_data';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meshly/models/contact.dart';
import 'package:meshly/models/conversation.dart';
import 'package:meshly/models/message.dart';
import 'package:meshly/services/app_database.dart' hide Contact, Conversation;
import 'package:meshly/services/contact_store.dart';
import 'package:meshly/services/crypto_service.dart';
import 'package:meshly/services/mesh_service.dart';
import 'package:meshly/services/meshtastic_proto.dart';
import 'package:meshly/services/notification_settings.dart';
import 'package:shared_preferences/shared_preferences.dart';

// FromRadio { my_info: MyNodeInfo { my_node_num } } — the first frame the
// radio sends after want_config. A service that has not seen it does not
// know its own node id.
List<int> announceNodeInfoFrame(int nodeNum) {
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
  TestWidgetsFlutterBinding.ensureInitialized();

  // Every service built by a test is torn down with it: an undisposed
  // MeshService leaves a stream controller and two ValueNotifiers alive for
  // the rest of the run. dispose() is idempotent, so tests that dispose
  // explicitly still work.
  MeshService newService() {
    final service = MeshService();
    addTearDown(service.dispose);
    return service;
  }

  // The in-memory database is closed with the test that opened it, instead of
  // being abandoned on the next resetForTesting.
  AppDatabase newTestDb() {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    return db;
  }

  group('MeshService', () {
    test('fresh instance has no device name and is not connected', () {
      final service = newService();
      expect(service.deviceName.value, isNull);
      expect(service.isConnected, isFalse);
    });

    test('fresh instance has no myNodeId', () {
      final service = newService();
      expect(service.myNodeId, isNull);
    });

    test('fresh instance: isOnline is false for any nodeId', () {
      final service = newService();
      expect(service.isOnline('!aabbccdd'), isFalse);
      expect(service.isOnline('!00000000'), isFalse);
    });

    test('fresh instance: lastHeardFor is null for any nodeId', () {
      final service = newService();
      expect(service.lastHeardFor('!aabbccdd'), isNull);
    });

    test(
      'writeRaw on a disconnected instance no-ops without throwing',
      () async {
        final service = newService();
        await expectLater(
          service.writeRaw([1, 2, 3]),
          completes,
        );
      },
    );

    test(
      'incomingMessages stream is available before any connection',
      () async {
        final service = newService();
        expect(service.incomingMessages, isA<Stream<Object?>>());
      },
    );

    test('dispose is idempotent-safe and clears deviceName', () {
      final service = newService()..dispose();
      // deviceName was already null; dispose should not throw or leave it
      // in an unexpected state.
      expect(service.deviceName.value, isNull);
    });

    // ── Auto-reconnect: connectionStatus observable ─────────────
    test('fresh instance starts disconnected', () {
      final service = newService();
      expect(
        service.connectionStatus.value,
        equals(MeshConnectionStatus.disconnected),
      );
    });

    test(
      'disconnect() on a non-connected instance leaves status disconnected '
      'and does not throw',
      () async {
        final service = newService();
        await expectLater(service.disconnect(), completes);
        expect(
          service.connectionStatus.value,
          equals(MeshConnectionStatus.disconnected),
        );
        expect(service.isConnected, isFalse);
      },
    );

    test('dispose leaves status disconnected and does not throw', () {
      final service = newService();
      expect(service.dispose, returnsNormally);
      expect(
        service.connectionStatus.value,
        equals(MeshConnectionStatus.disconnected),
      );
    });

    // ── Phase 3: sendText DM-without-key guard ──────────────
    // No BLE radio needed: sendText checks the peer's publicKey before it
    // ever touches _toRadio, so this works against a disconnected instance.
    group('sendText DM without contact publicKey', () {
      final store = ContactStore.instance;

      setUp(() async {
        store.resetForTesting(newTestDb());
        await store.init();
      });

      test(
        'returns SendResult.needsKey when peer contact has no publicKey',
        () async {
          final contact = Contact(nodeId: '!aabbccdd', displayName: 'No Key');
          await store.saveContact(contact);
          final conv = Conversation.dm('!aabbccdd');
          await store.saveConversation(conv);

          final service = newService();
          final result = await service.sendText('hello', conv);
          expect(result, equals(SendResult.needsKey));
        },
      );

      test(
        'returns SendResult.needsKey when peer contact is unknown entirely',
        () async {
          final conv = Conversation.dm('!deadbeef');
          final service = newService();
          final result = await service.sendText('hello', conv);
          expect(result, equals(SendResult.needsKey));
        },
      );
    });

    // ── Broken secure chat blocks sending into the void ────────
    // Same reasoning as above: the guard runs before _toRadio is touched.
    group('sendText DM with a broken secure chat', () {
      final store = ContactStore.instance;

      setUp(() async {
        store.resetForTesting(newTestDb());
        await store.init();
        // Own identity: sends that pass the guard reach encryptToContact,
        // and secure storage has no plugin under flutter_test.
        final (priv, pub) = await CryptoService.instance.generateKeyPair();
        CryptoService.instance.setIdentityForTesting(priv, pub);
      });

      tearDown(CryptoService.instance.resetForTesting);

      Future<Uint8List> peerKey() async {
        final (_, pub) = await CryptoService.instance.generateKeyPair();
        return pub;
      }

      Future<Conversation> dmWithKey(String nodeId) async {
        await store.saveContact(
          Contact(
            nodeId: nodeId,
            displayName: 'Переустановился',
            publicKey: await peerKey(),
          ),
        );
        return store.dmForNode(nodeId)!;
      }

      test('returns needsKey when we cannot read the peer', () async {
        final conv = await dmWithKey('!br0ken10');
        await store.setICanReadPeer(conv.id, value: false);

        final service = newService();
        expect(
          await service.sendText('в пустоту', conv),
          equals(SendResult.needsKey),
        );
      });

      // Regression: the peer deleted us, we got their [0x02] and kept happily
      // writing messages nobody could read.
      test('returns needsKey when the peer cannot read us', () async {
        final conv = await dmWithKey('!br0ken13');
        await store.setPeerCanReadUs(conv.id, value: false);
        // Our own half is fine — the block must still apply.
        expect(conv.iCanReadPeer, isTrue);

        final service = newService();
        expect(
          await service.sendText('в пустоту', conv),
          equals(SendResult.needsKey),
        );
      });

      test('force: true sends anyway despite a broken half', () async {
        final conv = await dmWithKey('!br0ken12');
        await store.setPeerCanReadUs(conv.id, value: false);
        final service = newService();
        // No radio → stored as failed, but NOT refused with needsKey.
        expect(
          await service.sendText('всё равно', conv, force: true),
          equals(SendResult.sent),
        );
      });

      test('force: true does NOT bypass a missing public key', () async {
        // Nothing to encrypt to: the escape hatch cannot conjure a key.
        await store.saveContact(
          Contact(nodeId: '!nokey01', displayName: 'Без ключа'),
        );
        final conv = store.dmForNode('!nokey01')!;
        final service = newService();
        expect(
          await service.sendText('никак', conv, force: true),
          equals(SendResult.needsKey),
        );
      });

      test('does not block once both halves are verified again', () async {
        final conv = await dmWithKey('!br0ken11');
        await store.setICanReadPeer(conv.id, value: false);
        await store.markSecureVerified(conv.id);

        final service = newService();
        // No radio → the message is stored as failed, but crucially the
        // send was NOT refused with needsKey.
        expect(
          await service.sendText('снова на связи', conv),
          equals(SendResult.sent),
        );
      });

      test('a healthy chat with a key is not blocked', () async {
        final conv = await dmWithKey('!healthy1');
        expect(conv.secureOk, isTrue);

        final service = newService();
        expect(
          await service.sendText('привет', conv),
          equals(SendResult.sent),
        );
      });
    });

    // ── Key mismatch notice ───────────────────────────────────
    test('sendKeyMismatchNotice without a radio is a silent no-op', () async {
      final service = newService();
      await expectLater(service.sendKeyMismatchNotice('!aabbccdd'), completes);
    });

    // ── Anti-flood budgets ────────────────────────────────────
    //
    // `[0x02]` answers an unauthenticated stimulus, so it shares one global
    // budget across all peers. A verify ack answers only a packet that
    // already authenticated, so it must NOT — while it did, one noisy source
    // stalled automatic recovery for every contact at once.
    group('service packet throttling', () {
      test('[0x02] shares a global budget across peers', () {
        final service = newService();
        expect(service.allowKeyMismatchNotice('!peer0001'), isTrue);
        // Different peer, per-peer window untouched — still refused.
        expect(service.allowKeyMismatchNotice('!peer0002'), isFalse);
      });

      test('[0x02] is throttled per peer as well', () {
        final service = newService();
        expect(service.allowKeyMismatchNotice('!peer0003'), isTrue);
        expect(service.allowKeyMismatchNotice('!peer0003'), isFalse);
      });

      test('an ack is not blocked by an exhausted global budget', () {
        final service = newService();
        // Spend the global budget on a notice...
        expect(service.allowKeyMismatchNotice('!peer0004'), isTrue);
        // ...the ack to a different peer must still go out.
        expect(
          service.allowKeyVerifyPacket('!peer0005', ping: false),
          isTrue,
        );
        expect(service.allowKeyVerifyPacket('!peer0006', ping: false), isTrue);
      });

      test('an ack does not spend the global budget either', () {
        final service = newService();
        expect(service.allowKeyVerifyPacket('!peer0007', ping: false), isTrue);
        expect(service.allowKeyMismatchNotice('!peer0008'), isTrue);
      });

      test('an ack is still throttled per peer', () {
        final service = newService();
        expect(service.allowKeyVerifyPacket('!peer0009', ping: false), isTrue);
        expect(service.allowKeyVerifyPacket('!peer0009', ping: false), isFalse);
      });

      test('pings and acks are throttled independently', () {
        final service = newService();
        expect(service.allowKeyVerifyPacket('!peer000a', ping: true), isTrue);
        expect(service.allowKeyVerifyPacket('!peer000a', ping: false), isTrue);
      });
    });

    // ── Verify handshake (post-scan ping) ─────────────────────
    group('announceSecureState', () {
      final store = ContactStore.instance;

      setUp(() async {
        store.resetForTesting(newTestDb());
        await store.init();
      });

      tearDown(CryptoService.instance.resetForTesting);

      // "No-op" is asserted through the throttle budget, not just through
      // "it didn't throw": a ping that actually went out would have spent the
      // per-peer window, so an untouched window proves nothing was sent.
      test('without a radio is a silent no-op', () async {
        // No identity is set either: the radio check must come first, so
        // nothing tries to encrypt.
        final service = newService();
        await service.announceSecureState('!aabbccdd');
        expect(
          service.allowKeyVerifyPacket('!aabbccdd', ping: true),
          isTrue,
          reason: 'nothing was sent, so the ping window is still open',
        );
      });

      test('unknown contact is a no-op', () async {
        final service = newService();
        await service.announceSecureState('!n0such01');
        expect(service.allowKeyVerifyPacket('!n0such01', ping: true), isTrue);
      });

      test('contact without a public key is a no-op', () async {
        final (priv, pub) = await CryptoService.instance.generateKeyPair();
        CryptoService.instance.setIdentityForTesting(priv, pub);
        await store.saveContact(
          Contact(nodeId: '!n0key001', displayName: 'Без ключа'),
        );
        expect(store.contactByNodeId('!n0key001')!.publicKey, isNull);

        final service = newService();
        await service.announceSecureState('!n0key001');
        expect(service.allowKeyVerifyPacket('!n0key001', ping: true), isTrue);
      });
    });

    // ── Offline send: message must be kept, not silently lost ──────
    // With no radio (_toRadio == null) sendText used to return sent
    // without persisting anything. Now it stores the message as failed so
    // the user sees it in the thread and can retry.
    group('sendText while disconnected keeps the message', () {
      final store = ContactStore.instance;

      setUp(() async {
        store.resetForTesting(newTestDb());
        await store.init();
      });

      test(
        'channel send with no radio persists a failed message and clears input',
        () async {
          final ch = await store.createChannel(name: 'Hikers');
          final conv = Conversation.channel(ch.id);

          final service = newService();
          final result = await service.sendText('are we there yet', conv);

          // Returned sent so the UI clears the input field...
          expect(result, equals(SendResult.sent));
          // ...but the message is saved as failed, not lost.
          final msgs = store.messagesFor(conv.id);
          expect(msgs, hasLength(1));
          expect(msgs.single.text, equals('are we there yet'));
          expect(msgs.single.isMe, isTrue);
          expect(msgs.single.status, equals(MessageStatus.failed));
        },
      );
    });

    // ── Conversations are decoupled from Meshtastic hardware slots ────
    //
    // Sending always goes out on channel=0 (the slot on the device was
    // never actually configured — encodeSetChannel was broken), and on
    // receive the conversation is identified by iterating over known PSKs:
    // we try to decrypt the envelope with each conversation's key, and the
    // first successful decryption is the conversation we're looking for.
    // See the sprint report "decoupling conversations from Meshtastic
    // slots".
    group('channel messages are slot-free', () {
      final store = ContactStore.instance;

      setUp(() async {
        SharedPreferences.setMockInitialValues({});
        // An incoming conversation message raises a local notification, and
        // flutter_local_notifications has no plugin for flutter_test.
        await NotificationSettings.instance.setEnabled(value: false);
        store.resetForTesting(newTestDb());
        await store.init();
      });

      tearDown(NotificationSettings.instance.resetForTesting);

      // Re-wraps ToRadio { field1: MeshPacket } as FromRadio { field2:
      // MeshPacket } — same helper as the DM group below (duplicated here
      // because that one is scoped to its own group).
      List<int> toFromRadio(List<int> toRadioBytes) {
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

      // A broadcast ToRadio frame carrying a raw (already-encrypted) payload
      // on PRIVATE_APP — exactly the shape an incoming channel message has.
      List<int> broadcastFrame(Uint8List payload) => toFromRadio(
        MeshtasticProto.encodeTextMessage(
          '',
          portnum: MeshtasticProto.PRIVATE_APP,
          rawPayload: payload,
        ),
      );

      test(
        'sendText for a conversation sends broadcast with channel = 0',
        () async {
          // The MeshChannel model no longer stores a slot at all (see the
          // sprint report "decoupling conversations from slots") —
          // sending broadcasts on channel = 0 regardless of the
          // conversation.
          final ch = await store.createChannel(name: 'Hikers');
          final conv = Conversation.channel(ch.id);

          final service = newService();
          final sent = <Uint8List>[];
          service.debugRadioSink = sent.add;

          final result = await service.sendText('идём в 9', conv);
          expect(result, equals(SendResult.sent));
          expect(sent, hasLength(1));

          final packet = MeshtasticProto.decodeFromRadio(
            toFromRadio(sent.single),
          );
          expect(packet.channel, equals(0));
          expect(packet.isDm, isFalse, reason: 'still a broadcast');
          expect(packet.portnum, equals(MeshtasticProto.PRIVATE_APP));
        },
      );

      test(
        'incoming broadcast is matched to the right conversation by trying '
        'every known PSK',
        () async {
          final chA = await store.createChannel(name: 'A');
          final chB = await store.createChannel(name: 'B');
          final convA = Conversation.channel(chA.id);
          final convB = Conversation.channel(chB.id);

          final envelope = await CryptoService.instance.encryptForChannel(
            psk: chB.psk,
            plaintext: 'только для B',
          );

          final service = newService();
          await service.handleIncomingBytes(broadcastFrame(envelope));

          expect(store.messagesFor(convB.id), hasLength(1));
          expect(
            store.messagesFor(convB.id).single.text,
            equals('только для B'),
          );
          expect(store.messagesFor(convA.id), isEmpty);
        },
      );

      test(
        'a broadcast encrypted with an unknown key is ignored, joins no '
        'conversation',
        () async {
          final ch = await store.createChannel(name: 'A');
          final conv = Conversation.channel(ch.id);
          final unknownPsk = Uint8List.fromList(
            List.generate(32, (i) => 255 - i),
          );

          final envelope = await CryptoService.instance.encryptForChannel(
            psk: unknownPsk,
            plaintext: 'чужая беседа',
          );

          final service = newService();
          await service.handleIncomingBytes(broadcastFrame(envelope));

          expect(store.messagesFor(conv.id), isEmpty);
        },
      );

      test(
        'a garbage broadcast is dropped by the cheap envelope check, never '
        'reaches key trial',
        () async {
          // At least one conversation must exist — otherwise the loop over
          // keys is empty anyway and the test proves nothing.
          await store.createChannel(name: 'A');

          final service = newService();

          // A payload that is too short: version+nonce+mac requires at
          // least 41 bytes, this one is shorter — the cheap check must drop
          // the packet BEFORE the code gets to checking PSKs.
          await expectLater(
            service.handleIncomingBytes(
              broadcastFrame(
                Uint8List.fromList([kMessageEnvelopeVersion, 1, 2, 3]),
              ),
            ),
            completes,
          );

          // A wrong version byte with otherwise sufficient length.
          await expectLater(
            service.handleIncomingBytes(
              broadcastFrame(Uint8List.fromList(List.filled(41, 0x7f))),
            ),
            completes,
          );

          expect(
            store.conversations.every((c) => c.lastMessage == null),
            isTrue,
          );
        },
      );
    });

    // ── Join/leave announcements: control plaintext inside an ordinary
    // channel broadcast (see models/message.dart's encodeSystemEvent) ──────
    group('conversation join/leave announcements', () {
      final store = ContactStore.instance;

      setUp(() async {
        SharedPreferences.setMockInitialValues({});
        await NotificationSettings.instance.setEnabled(value: false);
        store.resetForTesting(newTestDb());
        await store.init();
      });

      tearDown(NotificationSettings.instance.resetForTesting);

      List<int> toFromRadio(List<int> toRadioBytes) {
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
        return [18, ...lenBytes, ...packetBytes];
      }

      List<int> broadcastFrame(Uint8List payload) => toFromRadio(
        MeshtasticProto.encodeTextMessage(
          '',
          portnum: MeshtasticProto.PRIVATE_APP,
          rawPayload: payload,
        ),
      );

      test(
        'announceChannelEvent broadcasts an encrypted "joined" announcement',
        () async {
          final ch = await store.createChannel(name: 'Hikers');

          final service = newService();
          // Tell the service who it is: the announced name falls back to the
          // node id, and without MyNodeInfo there is nothing to announce.
          await service.handleIncomingBytes(announceNodeInfoFrame(0x1f8e42c9));
          final sent = <Uint8List>[];
          service.debugRadioSink = sent.add;

          await service.announceChannelEvent(ch, SystemEventKind.joined);
          expect(sent, hasLength(1));

          final packet = MeshtasticProto.decodeFromRadio(
            toFromRadio(sent.single),
          );
          expect(packet.portnum, equals(MeshtasticProto.PRIVATE_APP));
          final plaintext = await CryptoService.instance.decryptForChannel(
            psk: ch.psk,
            envelope: packet.rawPayload!,
          );
          final event = decodeSystemEvent(plaintext!);
          expect(event, isNotNull);
          expect(event!.kind, equals(SystemEventKind.joined));

          // Announcing does not touch local storage — that's the caller's
          // job (ChannelManager.addFromQr records "joined" separately).
          expect(store.messagesFor(Conversation.channel(ch.id).id), isEmpty);
        },
      );

      test('announceChannelEvent is a silent no-op with no radio', () async {
        final ch = await store.createChannel(name: 'Hikers');
        final service = newService();
        expect(service.isConnected, isFalse);

        await expectLater(
          service.announceChannelEvent(ch, SystemEventKind.left),
          completes,
        );
      });

      test(
        'an incoming "joined" announcement is stored as a system event, '
        'raises no notification and does not bump the unread count',
        () async {
          final ch = await store.createChannel(name: 'Hikers');
          final conv = Conversation.channel(ch.id);

          final envelope = await CryptoService.instance.encryptForChannel(
            psk: ch.psk,
            plaintext: encodeSystemEvent(SystemEventKind.joined, 'Boris'),
          );

          final service = newService();
          await service.handleIncomingBytes(broadcastFrame(envelope));

          final messages = store.messagesFor(conv.id);
          expect(messages, hasLength(1));
          expect(messages.single.isSystemEvent, isTrue);
          expect(messages.single.eventKind, equals(SystemEventKind.joined));
          expect(messages.single.text, equals('Boris'));
          expect(messages.single.isMe, isFalse);

          // Not a message from a person: the unread badge must not move.
          expect(store.conversationById(conv.id)!.unreadCount, equals(0));
        },
      );

      test(
        'an incoming "left" announcement in an unknown conversation is '
        'dropped like any other undecryptable broadcast',
        () async {
          final ch = await store.createChannel(name: 'Hikers');
          final conv = Conversation.channel(ch.id);
          final unknownPsk = Uint8List.fromList(
            List.generate(32, (i) => 200 - i),
          );
          final envelope = await CryptoService.instance.encryptForChannel(
            psk: unknownPsk,
            plaintext: encodeSystemEvent(SystemEventKind.left, 'Boris'),
          );

          final service = newService();
          await service.handleIncomingBytes(broadcastFrame(envelope));

          expect(store.messagesFor(conv.id), isEmpty);
        },
      );

      test(
        'leaveChannelConversation announces "left" and deletes the '
        'conversation locally',
        () async {
          final ch = await store.createChannel(name: 'Hikers');
          final conv = Conversation.channel(ch.id);

          final service = newService();
          await service.handleIncomingBytes(announceNodeInfoFrame(0x1f8e42c9));
          final sent = <Uint8List>[];
          service.debugRadioSink = sent.add;

          await service.leaveChannelConversation(ch);

          expect(sent, hasLength(1));
          final packet = MeshtasticProto.decodeFromRadio(
            toFromRadio(sent.single),
          );
          final plaintext = await CryptoService.instance.decryptForChannel(
            psk: ch.psk,
            envelope: packet.rawPayload!,
          );
          expect(
            decodeSystemEvent(plaintext!)!.kind,
            equals(SystemEventKind.left),
          );

          expect(store.channelById(ch.id), isNull);
          expect(store.conversationById(conv.id), isNull);
        },
      );

      test(
        'leaveChannelConversation still deletes the conversation when the '
        'radio is not connected (best effort announcement)',
        () async {
          final ch = await store.createChannel(name: 'Hikers');
          final service = newService();
          expect(service.isConnected, isFalse);

          await service.leaveChannelConversation(ch);

          expect(store.channelById(ch.id), isNull);
        },
      );
    });

    // ── Incoming DM dispatch (the secure-chat state machine) ───────
    //
    // Reached through handleIncomingBytes, the test seam over the private
    // receive path. No radio is involved: every assertion below is about what
    // the *arrival* of a packet does to stored state, and a disconnected
    // service simply drops the service packets it would otherwise emit.
    group('handleIncomingBytes: DM state machine', () {
      final store = ContactStore.instance;
      final crypto = CryptoService.instance;

      // Us. Any unicast destination works — the radio only forwards packets
      // it already considers ours.
      const usNodeNum = 0x11223344;

      late Uint8List myPriv;
      late Uint8List myPub;

      setUp(() async {
        SharedPreferences.setMockInitialValues({});
        // The undecryptable path raises a local notification, and
        // flutter_local_notifications has no plugin under flutter_test.
        await NotificationSettings.instance.setEnabled(value: false);
        store.resetForTesting(newTestDb());
        await store.init();
        final (priv, pub) = await crypto.generateKeyPair();
        myPriv = priv;
        myPub = pub;
        crypto.setIdentityForTesting(priv, pub);
      });

      tearDown(() async {
        crypto.resetForTesting();
        NotificationSettings.instance.resetForTesting();
      });

      // encodeTextMessage emits ToRadio { field1: MeshPacket }; the receive
      // path parses FromRadio { field2: MeshPacket }. Re-wrap field 1 as
      // field 2 (same helper as meshtastic_proto_test).
      List<int> toFromRadio(List<int> toRadioBytes) {
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

      // A unicast packet claiming to come from [from], addressed to us
      // unless [to] says otherwise.
      List<int> dmFrame({
        required String from,
        required int portnum,
        Uint8List? payload,
        String text = '',
        int to = usNodeNum,
      }) => toFromRadio(
        MeshtasticProto.encodeTextMessage(
          text,
          to: to,
          fromNode: int.parse(from.substring(1), radix: 16),
          portnum: portnum,
          rawPayload: payload,
        ),
      );

      // FromRadio { my_info(3): MyNodeInfo { my_node_num(1) } } — the frame
      // the radio sends first after want_config. The DM path compares
      // MeshPacket.to against this, so every service under test must be told
      // who it is before it will look at a unicast.
      List<int> myNodeInfoFrame(int nodeNum) {
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

      /// A service that already knows its own node num.
      Future<MeshService> connectedService() async {
        final service = newService();
        await service.handleIncomingBytes(myNodeInfoFrame(usNodeNum));
        return service;
      }

      /// Saves a contact with a fresh keypair and returns its private key —
      /// the peer's side of the conversation, for building packets they
      /// would have sent us.
      Future<Uint8List> addContact(String nodeId) async {
        final (peerPriv, peerPub) = await crypto.generateKeyPair();
        await store.saveContact(
          Contact(nodeId: nodeId, displayName: 'Пётр', publicKey: peerPub),
        );
        return peerPriv;
      }

      test('[0x02] from a known contact breaks only their half', () async {
        const peer = '!aabb0001';
        await addContact(peer);
        final service = await connectedService();

        await service.handleIncomingBytes(
          dmFrame(
            from: peer,
            portnum: MeshtasticProto.PRIVATE_APP,
            payload: keyMismatchNoticePayload(),
          ),
        );

        final conv = store.dmForNode(peer)!;
        expect(conv.peerCanReadUs, isFalse);
        expect(conv.iCanReadPeer, isTrue, reason: 'our own half is untouched');
      });

      // Regression: any unicast used to create a conversation *before* the
      // decryption attempt, so a stranger (or a forged `from`) produced a
      // phantom chat flagged "secure chat interrupted" in the chat list.
      test(
        '[0x02] from a stranger changes nothing and creates no chat',
        () async {
          const stranger = '!badcafe1';
          final service = await connectedService();

          await service.handleIncomingBytes(
            dmFrame(
              from: stranger,
              portnum: MeshtasticProto.PRIVATE_APP,
              payload: keyMismatchNoticePayload(),
            ),
          );

          expect(store.dmForNode(stranger), isNull);
          expect(store.conversations, isEmpty);
        },
      );

      test('a plaintext TEXT_MESSAGE_APP DM is ignored entirely', () async {
        const peer = '!aabb0002';
        await addContact(peer);
        final service = await connectedService();

        await service.handleIncomingBytes(
          dmFrame(
            from: peer,
            portnum: MeshtasticProto.portTextMessage,
            text: 'hello from stock Meshtastic',
          ),
        );

        final conv = store.dmForNode(peer)!;
        expect(conv.secureOk, isTrue, reason: 'healthy chat stays healthy');
        expect(store.messagesFor(conv.id), isEmpty);
      });

      test('a stranger cannot conjure a chat with a plaintext DM', () async {
        const stranger = '!badcafe2';
        final service = await connectedService();

        await service.handleIncomingBytes(
          dmFrame(
            from: stranger,
            portnum: MeshtasticProto.portTextMessage,
            text: 'hi',
          ),
        );

        expect(store.conversations, isEmpty);
      });

      // Regression: `[0x03]` + garbage under a forged `from` used to mark the
      // chat broken AND fire a `[0x02]` back, so one packet blocked the
      // conversation on both devices.
      test('an unreadable [0x03] ping does not break our half', () async {
        const peer = '!aabb0003';
        await addContact(peer);
        final service = await connectedService();

        await service.handleIncomingBytes(
          dmFrame(
            from: peer,
            portnum: MeshtasticProto.PRIVATE_APP,
            payload: Uint8List.fromList([
              kKeyVerifyPingVersion,
              ...List<int>.filled(48, 0xAB),
            ]),
          ),
        );

        final conv = store.dmForNode(peer)!;
        expect(conv.iCanReadPeer, isTrue);
        expect(conv.secureOk, isTrue);
      });

      // Was: an unreadable [0x03] optimistically set peerCanReadUs ("they
      // must have scanned us"). The byte travels in the clear, so a forged
      // packet painted a false green check and — once we scanned them back —
      // a false "secure chat restored" that unblocked sending into a chat the
      // peer cannot read. The hint is gone: an unreadable ping is pure noise.
      test('an unreadable [0x03] never moves a flag, broken or not', () async {
        const peer = '!aabb0004';
        await addContact(peer);
        final conv = store.dmForNode(peer)!;
        await store.setICanReadPeer(conv.id, value: false);
        await store.setPeerCanReadUs(conv.id, value: false);
        final service = await connectedService();

        await service.handleIncomingBytes(
          dmFrame(
            from: peer,
            portnum: MeshtasticProto.PRIVATE_APP,
            payload: Uint8List.fromList([
              kKeyVerifyPingVersion,
              ...List<int>.filled(48, 0xAB),
            ]),
          ),
        );

        expect(conv.peerCanReadUs, isFalse, reason: 'no unauthenticated hint');
        expect(conv.iCanReadPeer, isFalse);
        expect(conv.secureOk, isFalse);
      });

      /// An envelope from a stranger's identity: a well-formed `[0x01]` that
      /// authenticates against nothing we hold.
      Future<Uint8List> unreadableEnvelope() async {
        final (strangerPriv, _) = await crypto.generateKeyPair();
        final (_, strangerPub) = await crypto.generateKeyPair();
        crypto.setIdentityForTesting(strangerPriv, strangerPub);
        final envelope = await crypto.encryptToContact(
          peerPublicKey: strangerPub,
          plaintext: 'нечитаемо',
        );
        crypto.setIdentityForTesting(myPriv, myPub);
        return envelope;
      }

      // No "N failures in a row" threshold: whoever can forge one packet can
      // forge three, so a threshold bought no security — it only made the
      // honest case (the peer reinstalled) cost several messages sent into
      // the void before the user saw the recovery card. The defence is that
      // being wrong is cheap: "write anyway" unblocks the chat for good.
      test('a single unreadable [0x01] breaks our half at once', () async {
        const peer = '!aabb0005';
        await addContact(peer);
        final envelope = await unreadableEnvelope();

        final service = await connectedService();
        await service.handleIncomingBytes(
          dmFrame(
            from: peer,
            portnum: MeshtasticProto.PRIVATE_APP,
            payload: envelope,
          ),
        );

        final conv = store.dmForNode(peer)!;
        expect(conv.iCanReadPeer, isFalse);
        expect(conv.peerCanReadUs, isTrue, reason: 'proves nothing about them');
        expect(conv.secureOk, isFalse);
        expect(
          store.messagesFor(conv.id),
          isEmpty,
          reason: 'no placeholder bubbles',
        );
      });

      // Junk from one contact says nothing about another one.
      test("an unreadable [0x01] breaks only that sender's chat", () async {
        const peerA = '!aabb000a';
        const peerB = '!aabb000b';
        await addContact(peerA);
        await addContact(peerB);
        final envelope = await unreadableEnvelope();

        final service = await connectedService();
        await service.handleIncomingBytes(
          dmFrame(
            from: peerA,
            portnum: MeshtasticProto.PRIVATE_APP,
            payload: envelope,
          ),
        );

        expect(store.dmForNode(peerA)!.iCanReadPeer, isFalse);
        expect(store.dmForNode(peerB)!.iCanReadPeer, isTrue);
      });

      // Regression: `isDm` only means "unicast". The radio also hands up
      // unicasts between two *other* nodes, so an ordinary conversation
      // between two of our own contacts used to fail to decrypt here and
      // flagged our chat with them broken — no attacker involved.
      test(
        'an unreadable [0x01] addressed elsewhere changes nothing',
        () async {
          const peer = '!aabb000c';
          await addContact(peer);
          final envelope = await unreadableEnvelope();

          final service = await connectedService();
          await service.handleIncomingBytes(
            dmFrame(
              from: peer,
              portnum: MeshtasticProto.PRIVATE_APP,
              payload: envelope,
              to: 0x77778888, // someone else's node
            ),
          );

          final conv = store.dmForNode(peer)!;
          expect(conv.iCanReadPeer, isTrue);
          expect(conv.secureOk, isTrue);
          // The `[0x02]` answer is emitted only when our half breaks, so an
          // untouched flag also means nothing went on the air.
          expect(service.allowKeyMismatchNotice(peer), isTrue);
        },
      );

      // A `[0x02]` overheard from someone else's conversation must not block
      // our sending either.
      test('a [0x02] addressed elsewhere changes nothing', () async {
        const peer = '!aabb000d';
        await addContact(peer);

        final service = await connectedService();
        await service.handleIncomingBytes(
          dmFrame(
            from: peer,
            portnum: MeshtasticProto.PRIVATE_APP,
            payload: keyMismatchNoticePayload(),
            to: 0x77778888,
          ),
        );

        expect(store.dmForNode(peer)!.secureOk, isTrue);
      });

      // Before MyNodeInfo arrives there is nothing to compare `to` against.
      // Dropping the packet is the conservative half of the trade-off: the
      // window is a few frames wide (MyNodeInfo is the first thing the radio
      // sends), while guessing the other way would let overheard traffic
      // break chats exactly where we cannot tell.
      test('a unicast before MyNodeInfo is ignored', () async {
        const peer = '!aabb000e';
        await addContact(peer);
        final envelope = await unreadableEnvelope();

        final service = newService(); // node num still unknown
        await service.handleIncomingBytes(
          dmFrame(
            from: peer,
            portnum: MeshtasticProto.PRIVATE_APP,
            payload: envelope,
          ),
        );

        expect(store.dmForNode(peer)!.secureOk, isTrue);
      });

      // Real Meshtastic node numbers are unsigned 32-bit and routinely have
      // the top bit set. If either side of the `decoded.to != _myNodeNum`
      // comparison were sign-extended or truncated, every DM to such a radio
      // would be dropped as "not for us".
      test('a DM to a node num with the high bit set is ours', () async {
        const usHighBit = 0x9abcdef0;
        const peer = '!aabb00f1';
        final peerPriv = await addContact(peer);

        final peerPub = store.contactByNodeId(peer)!.publicKey!;
        crypto.setIdentityForTesting(peerPriv, peerPub);
        final envelope = await crypto.encryptToContact(
          peerPublicKey: myPub,
          plaintext: 'старший бит',
        );
        crypto.setIdentityForTesting(myPriv, myPub);

        final service = newService();
        await service.handleIncomingBytes(myNodeInfoFrame(usHighBit));
        expect(service.myNodeId, equals('!9abcdef0'));

        await service.handleIncomingBytes(
          dmFrame(
            from: peer,
            portnum: MeshtasticProto.PRIVATE_APP,
            payload: envelope,
            to: usHighBit,
          ),
        );

        final msgs = store.messagesFor(store.dmForNode(peer)!.id);
        expect(msgs, hasLength(1));
        expect(msgs.single.text, equals('старший бит'));
      });

      test('a readable DM is stored and heals both halves', () async {
        const peer = '!aabb0006';
        final peerPriv = await addContact(peer);
        final conv = store.dmForNode(peer)!;
        await store.setICanReadPeer(conv.id, value: false);
        await store.setPeerCanReadUs(conv.id, value: false);

        // The peer encrypts to us with their own identity.
        final peerPub = store.contactByNodeId(peer)!.publicKey!;
        crypto.setIdentityForTesting(peerPriv, peerPub);
        final envelope = await crypto.encryptToContact(
          peerPublicKey: myPub,
          plaintext: 'я на связи',
        );
        crypto.setIdentityForTesting(myPriv, myPub);

        final service = await connectedService();
        await service.handleIncomingBytes(
          dmFrame(
            from: peer,
            portnum: MeshtasticProto.PRIVATE_APP,
            payload: envelope,
          ),
        );

        expect(conv.secureOk, isTrue);
        final msgs = store.messagesFor(conv.id);
        expect(msgs, hasLength(1));
        expect(msgs.single.text, equals('я на связи'));
        expect(msgs.single.isMe, isFalse);
      });

      // ── What actually goes on the air ───────────────────────
      //
      // Everything above asserts stored state; the tests below watch the
      // send path through the radio sink, because both bugs being fixed here
      // are about packets that were (or weren't) transmitted.

      /// Wires a service's radio to [captured] so the test can see what it
      /// emits. Returns the first version byte of each outgoing payload.
      List<int> versionsOf(List<Uint8List> captured) => captured
          .map(
            (b) => MeshtasticProto.decodeFromRadio(toFromRadio(b)).rawPayload,
          )
          .whereType<Uint8List>()
          .map((p) => p[0])
          .toList();

      Future<(MeshService, List<Uint8List>)> wiredService() async {
        final service = await connectedService();
        final captured = <Uint8List>[];
        service.debugRadioSink = captured.add;
        return (service, captured);
      }

      // The user's scenario: B wiped their data, A writes to B. B used to
      // drop the packet in silence, so A saw two ticks from its own radio and
      // believed the message had arrived. Now B answers `[0x02]` — and still
      // creates nothing.
      test('an unknown sender gets [0x02] but conjures no state', () async {
        const stranger = '!badcafe3';
        final envelope = await unreadableEnvelope();
        final (service, sent) = await wiredService();

        await service.handleIncomingBytes(
          dmFrame(
            from: stranger,
            portnum: MeshtasticProto.PRIVATE_APP,
            payload: envelope,
          ),
        );

        expect(versionsOf(sent), equals([kKeyMismatchNoticeVersion]));
        final packet = MeshtasticProto.decodeFromRadio(
          toFromRadio(sent.single),
        );
        expect(packet.portnum, equals(MeshtasticProto.PRIVATE_APP));
        expect(packet.to, equals(0xbadcafe3));
        // The invariant: nothing about an unknown node is ever stored.
        expect(store.contactByNodeId(stranger), isNull);
        expect(store.dmForNode(stranger), isNull);
        expect(store.conversations, isEmpty);
      });

      test('an unknown sender gets nothing for a service packet', () async {
        const stranger = '!badcafe4';
        final (service, sent) = await wiredService();

        for (final payload in [
          keyMismatchNoticePayload(), // [0x02]
          Uint8List.fromList([kKeyVerifyPingVersion, ...List.filled(48, 7)]),
          Uint8List.fromList([kKeyVerifyAckVersion, ...List.filled(48, 7)]),
          Uint8List.fromList([0x7f, 1, 2, 3]), // unknown version = noise
        ]) {
          await service.handleIncomingBytes(
            dmFrame(
              from: stranger,
              portnum: MeshtasticProto.PRIVATE_APP,
              payload: payload,
            ),
          );
        }

        expect(sent, isEmpty);
        expect(store.conversations, isEmpty);
      });

      test('an unknown sender addressed elsewhere gets nothing', () async {
        const stranger = '!badcafe5';
        final envelope = await unreadableEnvelope();
        final (service, sent) = await wiredService();

        await service.handleIncomingBytes(
          dmFrame(
            from: stranger,
            portnum: MeshtasticProto.PRIVATE_APP,
            payload: envelope,
            to: 0x77778888,
          ),
        );

        expect(sent, isEmpty);
      });

      test('a blocked unknown sender gets nothing', () async {
        const stranger = '!badcafe6';
        await store.blockNode(stranger);
        final envelope = await unreadableEnvelope();
        final (service, sent) = await wiredService();

        await service.handleIncomingBytes(
          dmFrame(
            from: stranger,
            portnum: MeshtasticProto.PRIVATE_APP,
            payload: envelope,
          ),
        );

        expect(sent, isEmpty);
        expect(store.conversations, isEmpty);
      });

      /// Builds an envelope [peer] would have sent us, then restores our
      /// identity.
      Future<Uint8List> envelopeFrom(String peer, Uint8List peerPriv) async {
        final peerPub = store.contactByNodeId(peer)!.publicKey!;
        crypto.setIdentityForTesting(peerPriv, peerPub);
        final envelope = await crypto.encryptToContact(
          peerPublicKey: myPub,
          plaintext: 'привет',
        );
        crypto.setIdentityForTesting(myPriv, myPub);
        return envelope;
      }

      // Occasion (c) of the one ping rule: our view just became healthy, and
      // the peer has no way of knowing that. This is what used to leave a
      // recovery card hanging on the other device after its ack was lost.
      test('healing on an incoming packet announces the new state', () async {
        const peer = '!aabb0011';
        final peerPriv = await addContact(peer);
        final conv = store.dmForNode(peer)!;
        await store.setPeerCanReadUs(conv.id, value: false);
        final envelope = await envelopeFrom(peer, peerPriv);
        final (service, sent) = await wiredService();

        await service.handleIncomingBytes(
          dmFrame(
            from: peer,
            portnum: MeshtasticProto.PRIVATE_APP,
            payload: envelope,
          ),
        );

        expect(conv.secureOk, isTrue);
        expect(versionsOf(sent), equals([kKeyVerifyPingVersion]));
      });

      // ...and the other half of that rule, the one that bounds the exchange:
      // a chat that was ALREADY healthy announces nothing. Without this the
      // ping → ack → ping loop would never stop.
      test('an already healthy chat announces nothing', () async {
        const peer = '!aabb0012';
        final peerPriv = await addContact(peer);
        expect(store.dmForNode(peer)!.secureOk, isTrue);
        final envelope = await envelopeFrom(peer, peerPriv);
        final (service, sent) = await wiredService();

        await service.handleIncomingBytes(
          dmFrame(
            from: peer,
            portnum: MeshtasticProto.PRIVATE_APP,
            payload: envelope,
          ),
        );

        expect(sent, isEmpty);
      });

      // Two "devices": two databases, two identities, two services, radios
      // wired to each other. ContactStore and CryptoService are singletons,
      // so a device is "activated" (its database and identity swapped in)
      // before anything runs on its behalf.
      //
      // The point of the test is termination: every packet either heals a
      // side (a state transition, which may announce once) or finds it
      // already healthy (which announces nothing), so the queue must drain.
      test('two devices converge and the exchange stops', () async {
        const aNum = 0x0a0a0a0a;
        const bNum = 0x0b0b0b0b;
        const aId = '!0a0a0a0a';
        const bId = '!0b0b0b0b';

        final dbA = newTestDb();
        final dbB = newTestDb();
        final (aPriv, aPub) = await crypto.generateKeyPair();
        final (bPriv, bPub) = await crypto.generateKeyPair();

        Future<void> activate(
          AppDatabase db,
          Uint8List priv,
          Uint8List pub,
        ) async {
          store.resetForTesting(db);
          await store.init();
          crypto.setIdentityForTesting(priv, pub);
        }

        // Both sides scanned each other's QR (so each holds the other's key)
        // but neither has heard anything back yet: both recovery cards are up.
        await activate(dbA, aPriv, aPub);
        await store.saveContact(
          Contact(nodeId: bId, displayName: 'Б', publicKey: bPub),
        );
        await store.setPeerCanReadUs('dm_$bId', value: false);
        await activate(dbB, bPriv, bPub);
        await store.saveContact(
          Contact(nodeId: aId, displayName: 'А', publicKey: aPub),
        );
        await store.setPeerCanReadUs('dm_$aId', value: false);

        final serviceA = newService();
        await serviceA.handleIncomingBytes(myNodeInfoFrame(aNum));
        final serviceB = newService();
        await serviceB.handleIncomingBytes(myNodeInfoFrame(bNum));

        // The air: each entry is (destination, ToRadio bytes).
        final inFlight = <(String, Uint8List)>[];
        serviceA.debugRadioSink = (b) => inFlight.add(('B', b));
        serviceB.debugRadioSink = (b) => inFlight.add(('A', b));

        // Occasion (a): A has just scanned B.
        await activate(dbA, aPriv, aPub);
        await serviceA.announceSecureState(bId);
        expect(inFlight, hasLength(1), reason: 'the scan sends one ping');

        var delivered = 0;
        while (inFlight.isNotEmpty) {
          delivered++;
          expect(
            delivered,
            lessThan(20),
            reason: 'the verify handshake must terminate, not loop',
          );
          final (dest, bytes) = inFlight.removeAt(0);
          if (dest == 'A') {
            await activate(dbA, aPriv, aPub);
            await serviceA.handleIncomingBytes(toFromRadio(bytes));
          } else {
            await activate(dbB, bPriv, bPub);
            await serviceB.handleIncomingBytes(toFromRadio(bytes));
          }
        }

        await activate(dbA, aPriv, aPub);
        expect(store.dmForNode(bId)!.secureOk, isTrue, reason: 'A healed');
        await activate(dbB, bPriv, bPub);
        expect(store.dmForNode(aId)!.secureOk, isTrue, reason: 'B healed');
      });
    });
  });
}
