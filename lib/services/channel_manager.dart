import 'dart:math';
import 'dart:typed_data';

import 'package:meshly/models/mesh_channel.dart';
import 'package:meshly/services/contact_store.dart';
import 'package:meshly/services/mesh_service.dart';

/// Thin wrapper over [ContactStore.createChannel].
///
/// This used to also pick a free hardware slot (1-7, slot 0 is reserved by
/// the firmware) and write the channel to the device
/// (`MeshtasticProto.encodeSetChannel` — now removed). Both parts went away
/// together with decoupling conversations from slots (see the sprint
/// report): writing to the device never actually worked (wrong field number
/// and port), so the slot was never configured anyway — a conversation is
/// identified on receive by trying PSKs, not by slot, and there can now be
/// any number of conversations.
///
/// The class is kept (not collapsed into a static function) on purpose:
/// screens (`new_channel_screen.dart`) call `ChannelManager.instance.create(...)`
/// directly, and per sprint rules screens must not be touched — the
/// signature and entry point have to stay the same.
class ChannelManager {
  ChannelManager._();
  static final ChannelManager instance = ChannelManager._();

  // Create a conversation: save it locally. The device is no longer touched.
  // ContactStore.createChannel always succeeds (there's no "all slots taken"
  // case anymore — there are no slots), so the return value is never null.
  Future<MeshChannel> create({
    required String name,
    required String? avatarEmoji,
    required MeshService meshService,
  }) async {
    final store = ContactStore.instance;
    final psk = _randomPsk();
    return store.createChannel(
      name: name,
      avatarEmoji: avatarEmoji,
      psk: psk,
    );
  }

  /// Add a conversation received via QR (PSK already known).
  Future<MeshChannel> addFromQr({
    required String name,
    required Uint8List psk,
    required String? avatarEmoji,
    required MeshService meshService,
  }) async {
    final store = ContactStore.instance;
    return store.createChannel(
      name: name,
      avatarEmoji: avatarEmoji,
      psk: psk,
    );
  }

  static Uint8List _randomPsk() {
    final rng = Random.secure();
    return Uint8List.fromList(List.generate(32, (_) => rng.nextInt(256)));
  }
}
