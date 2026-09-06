import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:meshly/models/conversation.dart';
import 'package:meshly/models/mesh_channel.dart';
import 'package:meshly/models/message.dart';
import 'package:meshly/services/contact_store.dart';
import 'package:meshly/services/crypto_service.dart';
import 'package:meshly/services/lora_region.dart';
import 'package:meshly/services/meshtastic_proto.dart';
import 'package:meshly/services/notification_service.dart';
import 'package:meshly/services/notification_settings.dart';

// The undecryptable-message sentinel now lives in the model layer (so the
// store can use it without depending on BLE); re-exported here because
// screens and widgets import it from this file.
export 'package:meshly/models/message.dart' show kUndecryptableSentinel;

/// UUID of the Meshtastic BLE service. Public: the scan screen uses it to
/// tell Meshtastic devices apart from other BLE devices by their advertised
/// service UUID.
const String kMeshtasticServiceUuid = '6ba1b218-15a8-461f-9fa8-5dcae273eafd';
const String _meshServiceUuid = kMeshtasticServiceUuid;
const _toRadioCharUuid = 'f75c76d2-129e-4dad-a1dd-7866124401e7';
const _fromRadioCharUuid = '2c55e69e-4993-11ed-b878-0242ac120002';
const _fromNumCharUuid = 'ed9da18c-a800-4f66-a670-aa7547e34453';

/// Outcome of [MeshService.sendText]. Channel sends always resolve to
/// [sent] (or [noChannel] if the target channel doesn't exist). DM sends
/// resolve to [needsKey] when the peer contact has no known public key —
/// DMs are encrypted-only, so we refuse to send rather than fall back to
/// plaintext.
enum SendResult { sent, needsKey, noChannel }

/// Observable state of the BLE connection to the radio. Used by the UI
/// status pill and the auto-reconnect logic.
enum MeshConnectionStatus { disconnected, connecting, connected, reconnecting }

class MeshService {
  BluetoothDevice? _device;
  BluetoothCharacteristic? _toRadio;
  BluetoothCharacteristic? _fromRadio;
  BluetoothCharacteristic? _fromNum;
  Timer? _pollTimer;
  StreamSubscription<BluetoothConnectionState>? _connStateSub;
  StreamSubscription<List<int>>? _fromNumSub;
  bool _disposed = false;
  // Re-entrancy guard for [_drainFromRadio] (notify subscription + poll timer
  // both call it).
  bool _draining = false;

  // Auto-reconnect: an intentional disconnect() must not trigger the loop,
  // and concurrent reconnect loops are forbidden.
  bool _intentionalDisconnect = false;
  bool _reconnecting = false;

  int? _myNodeNum;
  final Map<String, DateTime> _lastHeard = {};
  static const _onlineThreshold = Duration(minutes: 15);

  // Rate limit for the key-mismatch notice: without it two devices whose
  // keys no longer match would answer each other's notices forever and
  // flood the (very slow) LoRa channel. Same window throttles the local
  // "couldn't read a message" notification so the user isn't spammed.
  final Map<String, DateTime> _lastKeyMismatchNotice = {};
  final Map<String, DateTime> _lastUndecryptableNotify = {};
  // Same window guards the verify handshake: a ping is only ever sent right
  // after a QR scan, and an ack only answers a ping (never another ack), so
  // this is belt-and-braces against a peer that spams pings.
  final Map<String, DateTime> _lastKeyVerifyPing = {};
  final Map<String, DateTime> _lastKeyVerifyAck = {};
  static const _keyMismatchNoticeInterval = Duration(seconds: 60);

  // Per-peer throttling alone is not enough for packets we emit in *reaction*
  // to received traffic: anyone can forge the `from` field, so N fake senders
  // used to buy N transmissions on a link that carries a few bytes per second.
  // Reactive service packets therefore also share one global budget.
  DateTime? _lastReactiveServicePacket;
  static const _reactiveServiceInterval = Duration(seconds: 60);

  bool isOnline(String nodeId) {
    final t = _lastHeard[nodeId];
    if (t == null) return false;
    return DateTime.now().difference(t) < _onlineThreshold;
  }

  DateTime? lastHeardFor(String nodeId) => _lastHeard[nodeId];

  // Stream for notifying the UI about new incoming messages
  final _incomingController = StreamController<Message>.broadcast();
  Stream<Message> get incomingMessages => _incomingController.stream;

  // Name of the connected device (null = no connection).
  // ValueNotifier instead of a broadcast stream: new subscribers (screens
  // created AFTER connect()) immediately see the current value.
  final ValueNotifier<String?> deviceName = ValueNotifier(null);

  // Observable connection status. deviceName is kept for UI backward
  // compatibility; both are updated consistently.
  final ValueNotifier<MeshConnectionStatus> connectionStatus = ValueNotifier(
    MeshConnectionStatus.disconnected,
  );

  /// Radio region: `null` — the device hasn't sent its config yet,
  /// [LoraRegion.unset] — the region isn't set and the board stays silent.
  ///
  /// The device sends its config on its own in response to want_config on
  /// connect, so no separate request is needed.
  final ValueNotifier<int?> loraRegion = ValueNotifier(null);

  /// Board model, as reported by the device (null — not reported yet).
  ///
  /// The device sends `DeviceMetadata` on its own as part of the config
  /// dump on connect, no separate request needed — same pattern as
  /// [loraRegion]. The model name does NOT indicate the board's frequency
  /// band (see the comment on `MeshtasticProto.decodeHwModel`), so the only
  /// guard against an incompatible region is [LoraRegion.compatibleWith].
  final ValueNotifier<String?> hwModel = ValueNotifier(null);

  // Raw LoRaConfig bytes exactly as sent by the device. Without them the
  // region can't be changed: set_config replaces the whole config (see
  // encodeSetRegion).
  Uint8List? _loraRaw;

  /// The region can only be changed once the device's config has already
  /// been received.
  bool get canSetRegion =>
      _loraRaw != null && _canTransmit && _myNodeNum != null;

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
    _intentionalDisconnect = false;
    // If this is an attempt from the reconnect loop — keep reconnecting so
    // the status pill doesn't flicker between connecting/reconnecting.
    if (connectionStatus.value != MeshConnectionStatus.reconnecting) {
      connectionStatus.value = MeshConnectionStatus.connecting;
    }
    await device.connect(license: License.nonprofit);
    _device = device;
    deviceName.value = device.platformName.isNotEmpty
        ? device.platformName
        : device.remoteId.str;

    // Meshtastic characteristics are encrypted: without pairing (bond),
    // subscribing to them hangs (setNotifyValue timeout). On Android we
    // explicitly initiate pairing — this shows the system PIN prompt (like
    // in the official app). iOS pairs on its own when a protected
    // characteristic is accessed; createBond isn't available there.
    if (Platform.isAndroid) {
      final bond = await device.bondState.first.timeout(
        const Duration(seconds: 2),
        onTimeout: () => BluetoothBondState.none,
      );
      if (bond != BluetoothBondState.bonded) {
        await device.createBond();
      }
    }

    final services = await device.discoverServices();
    final meshSvc = _findService(services, _meshServiceUuid);
    if (meshSvc == null) {
      final found = services.map((s) => '  ${s.serviceUuid}').join('\n');
      await device.disconnect();
      _cleanupConnection();
      throw Exception(
        'Meshtastic service not found.\nServices found:\n$found',
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
      throw Exception(
        'Required characteristics not found.\nAvailable:\n$found',
      );
    }

    if (_fromNum != null) {
      await _fromNum!.setNotifyValue(true);
      _fromNumSub = _fromNum!.onValueReceived.listen((_) => _drainFromRadio());
    }

    await _toRadio!.write(MeshtasticProto.encodeWantConfig());
    await _drainFromRadio();
    _pollTimer = Timer.periodic(
      const Duration(seconds: 3),
      (_) => _drainFromRadio(),
    );

    // Connection established — characteristics found, subscriptions live.
    connectionStatus.value = MeshConnectionStatus.connected;

    // Watch the actual BLE state: if the device drops out (went out of
    // range, ran out of battery) — reflect that in the UI and start
    // auto-reconnect (if the disconnect wasn't intentional).
    _connStateSub = device.connectionState.listen((state) {
      if (state == BluetoothConnectionState.disconnected) {
        debugPrint('[BLE] device disconnected');
        final d = _device;
        _cleanupConnection();
        if (!_disposed && !_intentionalDisconnect && d != null) {
          unawaited(_reconnectLoop(d));
        }
      }
    });
  }

  // Infinite reconnect loop with exponential backoff (2/4/8/16s, then capped
  // at 30s). Interrupted by an intentional disconnect() or dispose(). The
  // _reconnecting guard prevents two loops from running in parallel.
  Future<void> _reconnectLoop(BluetoothDevice device) async {
    if (_reconnecting) return;
    _reconnecting = true;
    connectionStatus.value = MeshConnectionStatus.reconnecting;
    var attempt = 0;
    try {
      while (true) {
        final seconds = attempt < 4 ? (1 << (attempt + 1)) : 30;
        attempt++;
        await Future<void>.delayed(Duration(seconds: seconds));
        if (_disposed || _intentionalDisconnect) break;
        try {
          await connect(device);
          return; // connect() already set connected itself
        } on Exception catch (e) {
          debugPrint('[BLE] reconnect attempt failed: $e');
        }
      }
    } finally {
      _reconnecting = false;
    }
  }

  // Send raw bytes to ToRadio (for AdminMessage etc.)
  Future<void> writeRaw(List<int> bytes) async {
    if (_toRadio == null) return;
    await _toRadio!.write(bytes);
  }

  Future<void> disconnect() async {
    // Intentional disconnect: the flag stops the reconnect loop (and cuts
    // short its backoff wait), the connectionState listener won't restart
    // it.
    _intentionalDisconnect = true;
    final device = _device;
    _cleanupConnection();
    if (!_disposed) connectionStatus.value = MeshConnectionStatus.disconnected;
    await device?.disconnect();
  }

  // Idempotent cleanup of connection state. Called both from disconnect()
  // and from the connectionState listener on an actual BLE disconnect —
  // a repeated call (e.g. disconnect() itself triggers the disconnected
  // event) is safe.
  void _cleanupConnection() {
    unawaited(_connStateSub?.cancel());
    _connStateSub = null;
    unawaited(_fromNumSub?.cancel());
    _fromNumSub = null;
    _pollTimer?.cancel();
    _pollTimer = null;
    _device = null;
    _toRadio = _fromRadio = _fromNum = null;
    // Our node number belongs to the radio we were talking to. Keeping it
    // after the link dies makes the next radio look like a stranger: every DM
    // is addressed to *its* node num, and the `decoded.to != _myNodeNum` gate
    // would silently drop them until (or unless) a MyNodeInfo arrives.
    _myNodeNum = null;
    // The config belongs to a specific device: after a disconnect it's
    // unknown, not "the same as it was" — otherwise the UI would show
    // someone else's region.
    _loraRaw = null;
    loraRegion.value = null;
    // The board model also belongs to a specific device — same as the region.
    hwModel.value = null;
    _lastHeard.clear();
    if (!_disposed) deviceName.value = null;
  }

  /// Sends the "I cannot decrypt you" service packet to [peerNodeId]:
  /// unicast, PRIVATE_APP, slot 0, payload = the single byte
  /// [kKeyMismatchNoticeVersion]. No key material is transmitted — the peer
  /// only learns that they should re-share their QR in person.
  ///
  /// No-op without a radio. Rate limited per peer (see
  /// [_keyMismatchNoticeInterval]) to keep two mismatched devices from
  /// ping-ponging notices over the air.
  /// Rate limited per peer (see [_keyMismatchNoticeInterval]) *and* globally
  /// (see [_reactiveServiceInterval]): this is the one packet we emit in
  /// answer to an unauthenticated stimulus, so a flood of forged senders must
  /// not turn into a flood of transmissions.
  ///
  /// Never throws: it is fired from the receive path, where nothing is waiting
  /// on the future.
  Future<void> sendKeyMismatchNotice(String peerNodeId) async {
    if (!_canTransmit) return;
    if (!allowKeyMismatchNotice(peerNodeId)) return;

    final encoded = MeshtasticProto.encodeTextMessage(
      '',
      to: _parseNodeId(peerNodeId),
      // channel: 0 (primary slot) — the encodeTextMessage default.
      fromNode: _myNodeNum,
      portnum: MeshtasticProto.PRIVATE_APP,
      rawPayload: keyMismatchNoticePayload(),
    );
    await _write(encoded, what: 'key mismatch notice → $peerNodeId');
  }

  /// THE rule for putting a verify ping on the air:
  ///
  /// > Send a verify ping whenever our view of a secret chat's health may
  /// > have drifted apart from the peer's view of it.
  ///
  /// This is the single entry point — there is deliberately no second way to
  /// emit a `[0x03]`. Three (and only three) situations qualify:
  ///
  /// * **(a) we just learned the peer's key** — their QR was scanned. Our
  ///   view just changed; theirs did not.
  /// * **(b) we opened a chat we consider broken** — LoRa acknowledges
  ///   nothing, so an earlier ping may simply have evaporated and left the
  ///   two sides disagreeing. Opening the chat is the natural retry moment.
  /// * **(c) our view just became healthy** — something of theirs decrypted,
  ///   so we know we are fine, but they have no way of knowing that. This is
  ///   the case that used to be missing: A scans B's QR, B heals and clears
  ///   its card, B's ack is lost in the air, and A's card hangs forever even
  ///   though both devices are technically fine.
  ///
  /// Mechanically the ping is an encrypted unicast (PRIVATE_APP, slot 0) that
  /// says "check whether we can read each other". The peer answers with an
  /// ack ([_sendKeyVerifyAck]); either packet decrypting proves both
  /// directions at once (ECDH is symmetric), so both recovery cards clear on
  /// their own within seconds.
  ///
  /// Termination: an ack is never answered in turn, and case (c) fires only
  /// on a real broken → healthy *transition*, so a peer that is already
  /// healthy answers a ping with one ack and nothing more. Per-peer
  /// throttling (60 s) is the second line of defence, not the first.
  ///
  /// No-op without a radio or without the contact's public key (nothing to
  /// encrypt to). Never throws — callers fire it and forget it.
  Future<void> announceSecureState(String peerNodeId) =>
      _sendKeyVerifyPacket(peerNodeId, ping: true);

  // The answer to a ping. Never answered in turn — that asymmetry is what
  // bounds the exchange at exactly two packets.
  Future<void> _sendKeyVerifyAck(String peerNodeId) =>
      _sendKeyVerifyPacket(peerNodeId, ping: false);

  Future<void> _sendKeyVerifyPacket(
    String peerNodeId, {
    required bool ping,
  }) async {
    if (!_canTransmit) return;
    final peerKey = ContactStore.instance
        .contactByNodeId(peerNodeId)
        ?.publicKey;
    if (peerKey == null) return;
    if (!allowKeyVerifyPacket(peerNodeId, ping: ping)) return;

    final crypto = CryptoService.instance;
    final Uint8List payload;
    try {
      payload = ping
          ? await crypto.buildKeyVerifyPing(peerKey)
          : await crypto.buildKeyVerifyAck(peerKey);
    } on Object catch (e) {
      // No identity yet, or a malformed stored key: a verify packet is a
      // nicety, never worth propagating to a fire-and-forget caller.
      debugPrint('[Mesh] key verify build failed for $peerNodeId: $e');
      return;
    }
    final encoded = MeshtasticProto.encodeTextMessage(
      '',
      to: _parseNodeId(peerNodeId),
      fromNode: _myNodeNum,
      portnum: MeshtasticProto.PRIVATE_APP,
      rawPayload: payload,
    );
    await _write(
      encoded,
      what: 'key verify ${ping ? "ping" : "ack"} → $peerNodeId',
    );
  }

  /// Writes a service packet, tolerating a link that died while we were busy
  /// encrypting.
  ///
  /// The characteristic is re-read here rather than captured before the
  /// `await`: a BLE drop in that window used to raise a *null check* error
  /// (an [Error], not an [Exception]), which the drain loop's `on Exception`
  /// handler would sail straight past.
  /// Test seam for the *send* path: when set, service packets go here instead
  /// of the BLE characteristic. Lets a test wire two [MeshService] instances
  /// radio-to-radio and watch the secure-chat handshake converge (and, more
  /// importantly, stop).
  @visibleForTesting
  void Function(Uint8List bytes)? debugRadioSink;

  // "There is somewhere to write to" — a real radio or the test sink.
  bool get _canTransmit => _toRadio != null || debugRadioSink != null;

  Future<void> _write(Uint8List bytes, {required String what}) async {
    final sink = debugRadioSink;
    if (sink != null) {
      sink(bytes);
      return;
    }
    final radio = _toRadio;
    if (radio == null) {
      debugPrint('[Mesh] $what dropped: link is down');
      return;
    }
    try {
      await radio.write(bytes);
      debugPrint('[Mesh] $what');
    } on Object catch (e) {
      // Fire-and-forget callers have nobody to hand this to.
      debugPrint('[Mesh] $what failed: $e');
    }
  }

  /// Sets the radio region: `begin_edit` → `set_config{lora}` → `commit_edit`.
  ///
  /// The region determines the frequency it's legal to transmit on, so this
  /// is only called on an explicit user choice — never guessed from their
  /// country.
  ///
  /// Returns `false` if the device's config hasn't been received yet:
  /// without the original bytes the region can't be changed, `set_config`
  /// would wipe out the rest of the settings.
  ///
  /// [loraRegion] is NOT updated here. After the region change the device
  /// reboots and sends its config again — that's the actual confirmation.
  /// Setting the value ahead of time would mean showing "configured" on a
  /// failed write.
  Future<bool> setRegion(int region) async {
    final lora = _loraRaw;
    final fromNode = _myNodeNum;
    if (lora == null || fromNode == null || !_canTransmit) {
      debugPrint('[Mesh] setRegion: no device config yet');
      return false;
    }
    final frames = MeshtasticProto.encodeSetRegion(
      currentLora: lora,
      region: region,
      fromNode: fromNode,
    );
    for (var i = 0; i < frames.length; i++) {
      await _write(frames[i], what: 'region frame ${i + 1}/${frames.length}');
    }
    debugPrint('[Mesh] region set to $region (${LoraRegion.codeOf(region)})');
    return true;
  }

  // True if enough time passed since the last event for [key] (and then
  // records "now"); false while still inside the throttle window. Entries
  // older than the window are dropped on the way, so the map cannot grow
  // past the number of distinct peers seen within one window.
  static bool _allowThrottled(Map<String, DateTime> log, String key) {
    final now = DateTime.now();
    final last = log[key];
    if (last != null && now.difference(last) < _keyMismatchNoticeInterval) {
      return false;
    }
    log.removeWhere(
      (_, t) => now.difference(t) >= _keyMismatchNoticeInterval,
    );
    log[key] = now;
    return true;
  }

  /// May a `[0x02]` notice go to [peerNodeId] right now? Per-peer *and*
  /// global: this is the one packet we emit in answer to an unauthenticated
  /// stimulus, so forged senders must not buy transmissions.
  ///
  /// Exposed only so tests can observe the two budgets without a radio.
  @visibleForTesting
  bool allowKeyMismatchNotice(String peerNodeId) =>
      _allowReactive(_lastKeyMismatchNotice, peerNodeId);

  /// May a verify ping/ack go to [peerNodeId] right now? Per-peer throttling
  /// only, in both directions.
  ///
  /// A ping is initiated locally — see [announceSecureState] for the one rule
  /// that decides when, and its three legitimate occasions. An ack is
  /// a reply, but an *authenticated* one — sent only after
  /// [CryptoService.verifyControlPacket] succeeded — so it cannot be provoked
  /// by a forged sender and needs no share of the global anti-flood budget.
  /// While it did share that budget, any noise source that spent the budget
  /// stalled automatic recovery for every contact at once.
  ///
  /// Exposed only so tests can observe this without a radio.
  @visibleForTesting
  bool allowKeyVerifyPacket(String peerNodeId, {required bool ping}) =>
      _allowThrottled(
        ping ? _lastKeyVerifyPing : _lastKeyVerifyAck,
        peerNodeId,
      );

  // [_allowThrottled] plus the shared budget for packets emitted in reaction
  // to received traffic. The global window is checked *before* the per-peer
  // one so a rejected attempt leaves no trace in either.
  bool _allowReactive(Map<String, DateTime> log, String key) {
    final now = DateTime.now();
    final last = _lastReactiveServicePacket;
    if (last != null && now.difference(last) < _reactiveServiceInterval) {
      return false;
    }
    if (!_allowThrottled(log, key)) return false;
    _lastReactiveServicePacket = now;
    return true;
  }

  // Send text to a conversation (DM or channel).
  //
  // [force] bypasses the "secure chat is broken" block: the breakage signal
  // is unauthenticated (a stranger on the air could block the chat
  // permanently), so the user always has an "send anyway" button as an
  // escape hatch. [force] does NOT bypass a missing public key — there's
  // nothing to encrypt with.
  Future<SendResult> sendText(
    String text,
    Conversation conv, {
    bool force = false,
  }) async {
    final store = ContactStore.instance;
    int? toNode;
    int channelSlot;
    var portnum = MeshtasticProto.portTextMessage;
    Uint8List? rawPayload;

    if (conv.isDm && conv.peerId != null) {
      // DM: unicast to a specific node, primary channel (slot 0).
      // DMs are encrypted-only: without the contact's public key we don't send.
      final contact = store.contactByNodeId(conv.peerId!);
      final peerKey = contact?.publicKey;
      if (peerKey == null) {
        debugPrint(
          '[Mesh] sendText: no public key for ${conv.peerId}, needs QR rescan',
        );
        return SendResult.needsKey;
      }
      // Secure chat is known broken in at least one direction: writing into
      // the void helps nobody. [force] is the escape hatch (the breakage
      // signal can be unauthenticated, see the doc comment above).
      if (!force && !conv.secureOk) {
        debugPrint(
          '[Mesh] sendText: secure chat ${conv.id} broken, needs fresh QR',
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
      // Conversation: broadcast. The hardware channel slot no longer affects
      // anything here (see the sprint report "decoupling conversations from
      // Meshtastic slots") — the slot was never configured in the firmware
      // anyway (encodeSetChannel didn't work), and the conversation is
      // identified on receive by trying PSKs, not by slot. We always send on
      // channel=0: a conversation is a label of our own Meshly-AEAD, not a
      // hardware channel.
      final ch = store.channelById(conv.channelId!);
      if (ch == null) {
        debugPrint(
          '[Mesh] sendText: channel ${conv.channelId} not found, aborting',
        );
        return SendResult.noChannel;
      }
      // Channel: our own Meshly-AEAD (key derived from the channel's PSK),
      // portnum PRIVATE_APP — same as in DMs, so the official app can't see
      // the text.
      channelSlot = 0;
      portnum = MeshtasticProto.PRIVATE_APP;
      rawPayload = await CryptoService.instance.encryptForChannel(
        psk: ch.psk,
        plaintext: text,
      );
    } else {
      return SendResult.noChannel;
    }

    // Generate the packet id up front and pass it into encodeTextMessage, so
    // the radio sends the packet with OUR id — then the ROUTING ACK
    // (request_id) will match the saved message's meshId and the status
    // will update to acked.
    final msgId = DateTime.now().millisecondsSinceEpoch & 0x7FFFFFFF;

    // No connection to the radio (and no test seam — see _canTransmit): we
    // don't lose the user's text. Save the message with failed status
    // (shown in the thread as unsent, retry-on-tap is already implemented
    // in chat_screen) and tell the UI that the input can be cleared
    // (SendResult.sent).
    if (!_canTransmit) {
      final failedMsg = Message(
        meshId: msgId,
        fromNodeId: myNodeId ?? '!00000000',
        conversationId: conv.id,
        text: text,
        time: DateTime.now(),
        isMe: true,
        status: MessageStatus.failed,
      );
      await store.addMessage(failedMsg);
      _incomingController.add(failedMsg.copyWith());
      return SendResult.sent;
    }

    final encoded = MeshtasticProto.encodeTextMessage(
      text,
      to: toNode,
      channel: channelSlot,
      fromNode: _myNodeNum,
      id: msgId,
      portnum: portnum,
      rawPayload: rawPayload,
    );

    // The same seam (_write/debugRadioSink) as for service packets — this
    // way tests see the actual bytes going out over the air, and
    // conversations, not just DMs.
    await _write(encoded, what: 'sendText → ${conv.id}');

    // Add the outgoing message to the store (locally always plaintext —
    // it's our own text before encryption)
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

  // ── Conversation join/leave announcements ───────────────────
  //
  // See models/message.dart (encodeSystemEvent/decodeSystemEvent) for why
  // this rides as plaintext inside an ordinary encrypted broadcast rather
  // than a distinct packet type, and CLAUDE.md's sprint brief for why it
  // never carries a public key.

  /// The name this device announces when joining or leaving a conversation.
  ///
  /// Public so a caller recording a "joined" event locally (see
  /// `ChannelManager.addFromQr`) uses the exact same name that went out over
  /// the air, instead of recomputing it and risking the two drifting apart.
  ///
  /// Falls back to the node id rather than to any wording: the announcement
  /// travels as data, so the receiver cannot localize it. A word like "Me"
  /// would also read from the wrong side — everyone else would see "Me
  /// joined". The self-contact only exists once the user has opened their
  /// own card and saved a name, and a conversation can be joined before
  /// that, so this fallback is a normal case rather than an edge one.
  String get myAnnouncedName {
    final id = myNodeId;
    final saved = id == null
        ? null
        : ContactStore.instance.contactByNodeId(id)?.displayName;
    return saved ?? id ?? '';
  }

  /// Broadcasts a join/leave announcement on [channel]. Best effort and
  /// fire-and-forget, exactly like [sendKeyMismatchNotice]: if the radio
  /// isn't connected there is nothing to retry (one broadcast, no
  /// acknowledgement — see the sprint brief's "log of what this device saw,
  /// not a roster"), so this silently does nothing rather than queuing
  /// anything.
  ///
  /// Does not touch local storage — callers decide separately whether to
  /// also record the event for themselves (see `ChannelManager.addFromQr`
  /// for "joined", and [leaveChannelConversation] for why "left" does not).
  Future<void> announceChannelEvent(
    MeshChannel channel,
    SystemEventKind kind,
  ) async {
    if (!_canTransmit) return;
    final name = myAnnouncedName;
    // Nothing meaningful to announce yet: this happens in the window between
    // connecting and MyNodeInfo arriving, when we do not even know our own
    // node id. Sending an empty name would spend airtime on a packet no
    // receiver can parse.
    if (name.isEmpty) {
      debugPrint('[Mesh] channel event not announced: own name unknown');
      return;
    }
    final plaintext = encodeSystemEvent(kind, name);
    final rawPayload = await CryptoService.instance.encryptForChannel(
      psk: channel.psk,
      plaintext: plaintext,
    );
    final encoded = MeshtasticProto.encodeTextMessage(
      plaintext,
      // Broadcast, channel = 0 — same as every conversation send, see
      // sendText above.
      fromNode: _myNodeNum,
      portnum: MeshtasticProto.PRIVATE_APP,
      rawPayload: rawPayload,
    );
    await _write(
      encoded,
      what: 'announce ${kind.wireName} → ${channel.id}',
    );
  }

  /// Leaves a group conversation: announces "left" to the mesh (best
  /// effort — deletion proceeds even if the radio isn't connected) and then
  /// deletes it locally, same as a bare [ContactStore.deleteChannel] call
  /// did before this sprint. UI code that lets the user delete a
  /// conversation they are a member of should call this instead of
  /// `ContactStore.instance.deleteChannel` directly, so the mesh hears about
  /// it before the local record disappears.
  Future<void> leaveChannelConversation(MeshChannel channel) async {
    // The goodbye is best effort; the deletion is not. _write already
    // swallows radio failures, but encryption and packet building sit
    // outside it, and a user who pressed "delete" must not be left with the
    // conversation still in their list because the farewell failed.
    try {
      await announceChannelEvent(channel, SystemEventKind.left);
    } on Object catch (e) {
      debugPrint('[Mesh] leave announcement failed, deleting anyway: $e');
    }
    await ContactStore.instance.deleteChannel(channel.id);
  }

  // ── Incoming packet dispatch ───────────────────────────────

  Future<void> _drainFromRadio() async {
    if (_disposed || _fromRadio == null) return;
    // Two callers (the FromNum notify subscription and the 3-second poll
    // timer) can fire while a drain is still awaiting a read. Two loops
    // reading the same characteristic interleave their reads: packets arrive
    // out of order, and id-less ones (meshId 0, which dedup cannot catch)
    // show up twice in the thread.
    if (_draining) return;
    _draining = true;
    try {
      for (var i = 0; i < 20; i++) {
        // Re-read the characteristic every pass: a BLE drop mid-drain nulls
        // it, and `_fromRadio!` would then raise a null-check *Error*.
        final radio = _fromRadio;
        if (radio == null) break;
        try {
          final bytes = await radio.read();
          if (bytes.isEmpty) break;
          await _onBytesReceived(bytes);
        } on Object catch (e) {
          // `on Object`, not `on Exception`: the drain runs from a
          // Timer.periodic, so an [Error] out of the parsing path (a
          // RangeError on a truncated packet, say) would become an unhandled
          // async error and take the receive loop down. Logged, never
          // swallowed silently — but without packet contents.
          debugPrint('[BLE] drain error: $e');
          break;
        }
      }
    } finally {
      _draining = false;
    }
  }

  /// Test seam for the receive path: [_onBytesReceived] is where the whole
  /// secure-chat state machine lives, and it is otherwise reachable only
  /// through a live BLE characteristic.
  @visibleForTesting
  Future<void> handleIncomingBytes(List<int> bytes) => _onBytesReceived(bytes);

  Future<void> _onBytesReceived(List<int> bytes) async {
    final store = ContactStore.instance;

    // Track lastHeard from any MeshPacket sender
    final sender = MeshtasticProto.extractSender(bytes);
    if (sender != null && sender != myNodeId) {
      _lastHeard[sender] = DateTime.now();
    }

    // MyNodeInfo → save our own node ID
    final myNum = MeshtasticProto.decodeMyNodeNum(bytes);
    if (myNum != null) {
      _myNodeNum = myNum;
      debugPrint('[Mesh] my node = $myNodeId');
    }

    // Config.lora → radio region
    final lora = MeshtasticProto.decodeLoraConfig(bytes);
    if (lora != null) {
      _loraRaw = lora.raw;
      loraRegion.value = lora.region;
    }

    // DeviceMetadata → board model
    final model = MeshtasticProto.decodeHwModel(bytes);
    if (model != null) {
      hwModel.value = model;
      debugPrint('[Mesh] hw_model = $model');
    }

    // NodeInfo — just log it, the contact's name is set by the user themself
    final nodeInfo = MeshtasticProto.decodeNodeInfo(bytes);
    if (nodeInfo != null) {
      debugPrint('[Mesh] node ${nodeInfo.nodeId} info received');
    }

    // ROUTING ACK (portnum=5) → update the message status.
    // errorName is a human-readable name (NOT_AUTHORIZED,
    // ADMIN_BAD_SESSION_KEY etc. from mesh.proto Routing.Error), needed
    // specifically for diagnosing silent admin commands — the log used to
    // only have the bare error code.
    final ack = MeshtasticProto.decodeRoutingAck(bytes);
    if (ack != null) {
      debugPrint(
        '[Mesh] routing ack meshId=${ack.meshId} '
        'error=${ack.errorCode} (${ack.errorName})',
      );
      final status = ack.errorCode == 0
          ? MessageStatus.acked
          : MessageStatus.failed;
      await store.updateMessageStatus(ack.meshId, status);
    }

    // Reply to an admin command (portnum=ADMIN_APP), if the device sent one
    // — e.g. get_config_response etc. This log's mere appearance is already
    // diagnostically valuable: it means AdminModule saw the packet.
    final adminResp = MeshtasticProto.decodeAdminResponse(bytes);
    if (adminResp != null) {
      debugPrint(
        '[Mesh] admin response meshId=${adminResp.meshId} '
        'variantTag=${adminResp.variantTag}',
      );
    }

    // MESSAGE (portnum=1 plaintext text, or portnum=PRIVATE_APP encrypted DM)
    final decoded = MeshtasticProto.decodeFromRadio(bytes);
    final portnum = decoded.portnum;
    if (portnum != MeshtasticProto.portTextMessage &&
        portnum != MeshtasticProto.PRIVATE_APP) {
      return;
    }

    final fromNodeId = decoded.from ?? '!00000000';

    // Don't show our own echo packets
    if (fromNodeId == myNodeId) return;

    // Ignore messages from blocked nodes
    if (store.isBlocked(fromNodeId)) return;

    // Unicast → DM. The whole secure-chat state machine lives there, and it
    // is deliberately picky about what it is willing to react to.
    if (decoded.isDm) {
      // …but only if the unicast is addressed to US. The radio also hands up
      // unicasts it merely overheard or relayed, so two of *our own* contacts
      // chatting with each other used to land here: their envelope is
      // encrypted to a key that is not ours, decryption fails, and a
      // perfectly healthy chat got flagged broken with a `[0x02]` bounced
      // back — no attacker required.
      //
      // While our own node num is still unknown (MyNodeInfo not received yet)
      // there is nothing to compare against, so we drop the packet: the
      // conservative half of the trade-off. Missing a message costs one
      // message during the first seconds after connecting; guessing wrong the
      // other way would let overheard traffic break chats exactly in the
      // window where we cannot tell. The radio replays its queue after
      // want_config, and MyNodeInfo is the first frame it sends, so in
      // practice this window is empty.
      if (_myNodeNum == null || decoded.to != _myNodeNum) {
        debugPrint(
          '[Mesh] unicast to 0x${decoded.to?.toRadixString(16)} '
          'is not for us — ignoring',
        );
        return;
      }
      await _onDmPacket(
        fromNodeId: fromNodeId,
        portnum: portnum,
        payload: decoded.rawPayload,
        meshId: decoded.meshId,
      );
      return;
    }

    // Broadcast → this is conversation (group chat) traffic. The hardware
    // channel slot no longer affects anything (see the sprint report
    // "decoupling conversations from Meshtastic slots"): it was never
    // configured in the device (encodeSetChannel never worked), so we find
    // the right conversation by trying known PSKs — we try to decrypt the
    // envelope with each conversation's key, and the first successful
    // decryption is the conversation we're looking for. Poly1305 rejects
    // the wrong key, so false matches are impossible.
    //
    // Channel: we only accept our own Meshly-AEAD (PRIVATE_APP + the
    // conversation's PSK). Someone else's plaintext (TEXT_MESSAGE_APP) and
    // any failed decryption are silently dropped — we don't show the
    // shared/official channel in Meshly.
    if (portnum != MeshtasticProto.PRIVATE_APP || decoded.rawPayload == null) {
      return;
    }
    final payload = decoded.rawPayload!;

    // Cheap check BEFORE trying keys: any node in range can send junk
    // broadcasts, and each such packet would otherwise force N decryption
    // attempts (one per conversation). We cheaply reject what's obviously
    // not ours — by envelope structure, same as for DMs (see the version
    // byte check on payload[0] above in _onDmPacket): the envelope version
    // must match, and the length must be no less than
    // version(1) + nonce(24) + Poly1305 mac(16), otherwise there's nothing
    // to decrypt with any key.
    const minEnvelopeLength = 1 + 24 + 16;
    if (payload.length < minEnvelopeLength ||
        payload[0] != kMessageEnvelopeVersion) {
      return;
    }

    // Unsorted view: conversation order doesn't matter here, and sorting on
    // every incoming broadcast (including other people's traffic) is wasted
    // work on the hot path (see the sprint report). The UI has
    // store.channels for that.
    for (final ch in store.channelsUnsorted) {
      final conv = store.conversationById('ch_${ch.id}');
      if (conv == null) continue;
      final text = await CryptoService.instance.decryptForChannel(
        psk: ch.psk,
        envelope: payload,
      );
      if (text == null) continue;

      final event = decodeSystemEvent(text);
      if (event != null) {
        await _storeSystemEvent(
          conv: conv,
          fromNodeId: fromNodeId,
          meshId: decoded.meshId,
          kind: event.kind,
          announcedName: event.name,
        );
        return;
      }

      await _storeIncoming(
        conv: conv,
        fromNodeId: fromNodeId,
        meshId: decoded.meshId,
        text: text,
      );
      return;
    }
    debugPrint(
      '[Mesh] broadcast from $fromNodeId decrypts with no known channel key — ignoring',
    );
  }

  /// Handles a unicast packet — the only path that can move the secure-chat
  /// flags or put a service packet on the air.
  ///
  /// SECURITY: every stimulus here is unauthenticated until something
  /// decrypts, and `from` is trivially forgeable, so the entry conditions are
  /// deliberately narrow. Anything else is silently dropped: no flags move,
  /// no `[0x02]` goes out, and — importantly — no conversation is created, so
  /// strangers and stock-Meshtastic traffic cannot conjure phantom chats
  /// (least of all ones flagged "secure chat interrupted") in the chat list.
  ///
  /// The caller has already checked that MeshPacket.to is our own node num,
  /// so overheard/relayed unicasts between other nodes never reach here.
  Future<void> _onDmPacket({
    required String fromNodeId,
    required int? portnum,
    required Uint8List? payload,
    required int? meshId,
  }) async {
    // Our own port only. A plaintext TEXT_MESSAGE_APP unicast is ordinary
    // Meshtastic traffic, not a broken Meshly chat — the channel branch has
    // always ignored it, and so does this one now.
    if (portnum != MeshtasticProto.PRIVATE_APP) return;
    if (payload == null || payload.isEmpty) return;

    final store = ContactStore.instance;
    // Only contacts we have actually met (scanned) take part: their identity
    // key is what every decision below rests on. The one thing a stranger can
    // still get out of us is a `[0x02]` — see [_onUnknownSenderDm].
    final contact = store.contactByNodeId(fromNodeId);
    if (contact == null) {
      await _onUnknownSenderDm(fromNodeId, payload);
      return;
    }
    final conv = store.dmForNode(fromNodeId);
    if (conv == null) return;

    // Service packet [0x02]: the peer cannot read us (we've apparently been
    // reinstalled). Not a message — flag the conversation as broken and
    // return.
    if (isKeyMismatchNotice(payload)) {
      debugPrint('[Mesh] key mismatch notice from $fromNodeId');
      // [0x02] speaks to exactly one direction: the PEER cannot read us —
      // it's THEM who needs to scan. Our own "I scanned them" step isn't
      // undone by this, so we don't touch iCanReadPeer.
      //
      // SECURITY: the signal is unauthenticated (the byte travels in the
      // clear), but the worst it can do is block sending, and that block
      // can be bypassed with the "send anyway" button.
      await store.setPeerCanReadUs(conv.id, value: false);
      return;
    }

    // Verify handshake [0x03]/[0x04]: not messages — they don't land in the
    // chat and don't generate notifications.
    if (isKeyVerifyPing(payload) || isKeyVerifyAck(payload)) {
      await _onKeyVerifyPacket(conv, fromNodeId, payload);
      return;
    }

    // Anything that is not a regular message envelope is noise: an unknown
    // version byte proves nothing about our keys, so it must not be able to
    // declare the chat broken.
    if (payload[0] != kMessageEnvelopeVersion) return;

    final senderKey = contact.publicKey;
    final text = senderKey == null
        ? null
        : await CryptoService.instance.decryptFromContact(
            senderPublicKey: senderKey,
            envelope: payload,
          );
    if (text == null) {
      // A real message we cannot read — the one honest proof that our copy of
      // the peer's key is stale.
      await _onUndecryptableDm(conv, fromNodeId);
      return;
    }

    // Decrypted → BOTH directions are healthy. ECDH is symmetric:
    // ECDH(our private, their public) == ECDH(their private, our public).
    // So one successful decryption proves BOTH directions at once — our
    // stored copy of the peer's key is correct, and the peer encrypted
    // using our current public key (meaning they scanned us).
    await _markSecureVerified(conv, fromNodeId);
    await _storeIncoming(
      conv: conv,
      fromNodeId: fromNodeId,
      meshId: meshId,
      text: text,
    );
  }

  /// Persists a decrypted incoming message and raises the local notification.
  Future<void> _storeIncoming({
    required Conversation conv,
    required String fromNodeId,
    required int? meshId,
    required String text,
  }) async {
    final store = ContactStore.instance;
    final msg = Message(
      meshId: meshId ?? 0,
      fromNodeId: fromNodeId,
      conversationId: conv.id,
      text: text,
      time: DateTime.now(),
      isMe: false,
    );

    await store.addMessage(msg);
    _incomingController.add(msg.copyWith());
    debugPrint(
      '[Mesh] message in ${conv.id} from $fromNodeId (${msg.text.length} chars)',
    );

    // Local notification for incoming messages
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

  /// Persists an incoming join/leave announcement as a system-event row.
  ///
  /// Deliberately does NOT call [NotificationService] and relies on
  /// [ContactStore.addMessage] to skip the unread-count bump for a
  /// [Message.isSystemEvent] row — it is not a message from a person, see
  /// the sprint brief. Still pushed onto [_incomingController] like a real
  /// message so a chat screen already open updates live.
  Future<void> _storeSystemEvent({
    required Conversation conv,
    required String fromNodeId,
    required int? meshId,
    required SystemEventKind kind,
    required String announcedName,
  }) async {
    final msg = Message.systemEvent(
      kind: kind,
      announcedName: announcedName,
      fromNodeId: fromNodeId,
      conversationId: conv.id,
      time: DateTime.now(),
      isMe: false,
      meshId: meshId ?? 0,
    );
    await ContactStore.instance.addMessage(msg);
    _incomingController.add(msg.copyWith());
    debugPrint(
      '[Mesh] system event ${kind.wireName} in ${conv.id} from '
      '$fromNodeId: $announcedName',
    );
  }

  /// Handles an incoming verify ping/ack ([kKeyVerifyPingVersion] /
  /// [kKeyVerifyAckVersion]). Never stores a message and never notifies.
  ///
  /// Success (the packet authenticates) proves both directions — ECDH is
  /// symmetric — so the chat is marked healthy. A ping is answered with an
  /// ack; an ack is answered with nothing, which is what makes a loop
  /// impossible.
  ///
  /// A verify packet we cannot read is treated as *noise*, never as proof of
  /// breakage. The version byte travels in the clear, so anyone can emit
  /// `[0x03]` + garbage under a forged `from`; letting that mark the chat
  /// broken (and answer with `[0x02]`) handed a single packet the power to
  /// block the conversation on both devices at once. Only a real message
  /// (`[0x01]`) that fails to decrypt proves anything.
  Future<void> _onKeyVerifyPacket(
    Conversation conv,
    String fromNodeId,
    Uint8List payload,
  ) async {
    final store = ContactStore.instance;
    final isPing = isKeyVerifyPing(payload);

    final senderKey = store.contactByNodeId(fromNodeId)?.publicKey;
    final ok =
        senderKey != null &&
        await CryptoService.instance.verifyControlPacket(
          senderPublicKey: senderKey,
          payload: payload,
        );

    // An unreadable verify packet is pure noise — neither flag moves, no
    // `[0x02]` goes out, nothing is answered. The version byte travels in the
    // clear, so treating `[0x03]` + garbage as a hint that "the peer scanned
    // us" let a forged packet paint a false green check, and — once we
    // scanned them back — a false "secure chat restored" plus unblocked
    // sending into a chat the peer still cannot read. It barely helped in the
    // real reinstall case anyway: a peer who reinstalled has no contact entry
    // for us, so their packet is dropped before it ever gets here.
    if (!ok) return;

    debugPrint(
      '[Mesh] key verify ${isPing ? "ping" : "ack"} from $fromNodeId OK',
    );
    await _markSecureVerified(conv, fromNodeId);
    if (isPing) await _sendKeyVerifyAck(fromNodeId);
  }

  /// [ContactStore.markSecureVerified] plus occasion (c) of the one ping rule
  /// (see [announceSecureState]): when *this* call is what turned the chat
  /// from broken into healthy, our view just moved and the peer's did not, so
  /// we tell them.
  ///
  /// The **transition** is what matters, never the state. Announcing on every
  /// healthy packet would turn ping → ack → ping into an endless exchange
  /// over a link that carries a few bytes per second. [ContactStore] returns
  /// early when nothing changes, so it cannot report the transition after the
  /// fact — the flags are read here *before* the write instead.
  ///
  /// Announcing even while we are also about to answer a ping with an ack is
  /// deliberate: the two packets carry the same news, and the whole reason
  /// this occasion exists is that a single packet gets lost. Termination does
  /// not depend on it — the peer only re-announces on a transition of its
  /// own, which it has already made.
  Future<void> _markSecureVerified(Conversation conv, String peerNodeId) async {
    final wasOk = conv.secureOk;
    await ContactStore.instance.markSecureVerified(conv.id);
    if (wasOk) return;
    // A failed persist rolls the flags back — then nothing changed after all.
    if (!conv.secureOk) return;
    await announceSecureState(peerNodeId);
  }

  /// A packet on our port, addressed to us, from a node we have never
  /// scanned. Normally dropped in silence; the single exception is a
  /// well-formed ordinary Meshly envelope (`[0x01]`), which we answer with a
  /// `[0x02]` "I cannot read you".
  ///
  /// Why the exception exists: if the peer wiped their data, *we* are the
  /// stranger to them and they are the stranger to us. Dropping their message
  /// silently left the sender staring at two ticks from their own radio,
  /// convinced the message arrived, while nobody learned anything. The
  /// `[0x02]` is what puts the recovery card on their screen.
  ///
  /// Invariant this preserves: **we never create state for unknown nodes** —
  /// no conversation, no contact, no message, no notification. Nothing
  /// appears in the UI. The `[0x02]` reply is the only thing an unknown node
  /// can ever get out of us, and only for a packet that looks like a genuine
  /// Meshly DM attempt: service bytes (`[0x02]`/`[0x03]`/`[0x04]`) and
  /// anything with an unknown version byte are noise and are answered with
  /// nothing.
  ///
  /// SECURITY: `from` is forgeable, so an attacker can make us send a
  /// `[0x02]` to a third node. That grants no new capability — the attacker
  /// can send that very packet to that node directly, and it is
  /// unauthenticated either way. The airtime cost is bounded by the same
  /// global reactive-packet budget as every other answer we emit, and
  /// blocked nodes are filtered out before the packet ever reaches here.
  Future<void> _onUnknownSenderDm(String fromNodeId, Uint8List payload) async {
    if (payload[0] != kMessageEnvelopeVersion) return;
    await sendKeyMismatchNotice(fromNodeId);
  }

  /// A real Meshly message envelope from a known contact that we cannot
  /// decrypt — they reinstalled and our copy of their identity key is stale.
  ///
  /// Only ever called for a contact we have scanned and on our own port: the
  /// caller ([_onDmPacket]) filters everything else out, so neither the flag
  /// nor the `[0x02]` notice can be triggered by a stranger or by stray
  /// traffic on another port.
  ///
  /// Nothing is stored: one placeholder bubble per junk packet used to flood
  /// the thread. Instead the conversation is flagged broken once, old
  /// placeholders left by earlier versions are purged, and the sender is
  /// told (rate limited) that we cannot read them.
  ///
  /// The very first unreadable message breaks the chat — deliberately, with
  /// no "N in a row" threshold. `from` is forgeable, but so are N packets:
  /// a threshold buys no security against anyone who can forge one packet,
  /// while it made the honest case (the peer reinstalled) cost several
  /// messages sent into the void before the user saw the recovery card. The
  /// defence is that being wrong is *cheap* — the card explains itself and
  /// "send anyway" unblocks the chat for good.
  Future<void> _onUndecryptableDm(Conversation conv, String fromNodeId) async {
    final store = ContactStore.instance;
    debugPrint('[Mesh] undecryptable DM from $fromNodeId → ${conv.id} broken');

    await store.setICanReadPeer(conv.id, value: false);
    await store.deleteUndecryptableMessages(conv.id);
    await sendKeyMismatchNotice(fromNodeId);

    // A soft notification with no content. Throttled by the same window as
    // the service packet: otherwise every junk packet would be a separate
    // push.
    if (!_allowThrottled(_lastUndecryptableNotify, fromNodeId)) return;
    if (!NotificationSettings.instance.shouldNotify(
      convId: conv.id,
      isDm: true,
    )) {
      return;
    }
    await NotificationService.instance.showMessage(
      title: store.contactByNodeId(fromNodeId)?.displayName ?? fromNodeId,
      // TODO(l10n): MeshService has no BuildContext, so this stays a Russian
      // literal until localization is plumbed through.
      body: 'Не удалось прочитать сообщение',
      conversationId: conv.id,
    );
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
    // Idempotent: the two ValueNotifiers below throw if disposed twice, and
    // both an owner and a teardown may reasonably call this.
    if (_disposed) return;
    _disposed = true;
    _intentionalDisconnect = true;
    connectionStatus.value = MeshConnectionStatus.disconnected;
    unawaited(_connStateSub?.cancel());
    _connStateSub = null;
    unawaited(_fromNumSub?.cancel());
    _fromNumSub = null;
    _pollTimer?.cancel();
    unawaited(_incomingController.close());
    deviceName.dispose();
    connectionStatus.dispose();
  }
}
