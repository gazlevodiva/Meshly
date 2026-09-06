import 'dart:math';
import 'dart:typed_data';

import 'package:meshly/models/mesh_channel.dart';
import 'package:meshly/models/message.dart';
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

  /// Add a conversation received via QR (PSK already known). Scanning the QR
  /// is how the user *joins* an existing conversation (as opposed to
  /// [create], which starts a brand new one nobody else knows about yet), so
  /// this also broadcasts a "joined" announcement and records the same event
  /// in our own history — our own broadcast never comes back to us over the
  /// air, so without a local record the very first entry in a conversation
  /// we join would silently be missing. The broadcast is best effort (see
  /// [MeshService.announceChannelEvent]): a disconnected radio still leaves
  /// the conversation usable, just without the announcement.
  Future<MeshChannel> addFromQr({
    required String name,
    required Uint8List psk,
    required String? avatarEmoji,
    required MeshService meshService,
  }) async {
    final store = ContactStore.instance;
    final channel = await store.createChannel(
      name: name,
      avatarEmoji: avatarEmoji,
      psk: psk,
    );
    await meshService.announceChannelEvent(channel, SystemEventKind.joined);
    // Skip the local record when we do not know our own name yet, for the
    // same reason announceChannelEvent skips the broadcast: an empty name
    // would render as a line that starts with the verb and no subject.
    final conv = store.conversationById('ch_${channel.id}');
    if (conv != null && meshService.myAnnouncedName.isNotEmpty) {
      await store.addMessage(
        Message.systemEvent(
          kind: SystemEventKind.joined,
          announcedName: meshService.myAnnouncedName,
          fromNodeId: meshService.myNodeId ?? '!00000000',
          conversationId: conv.id,
          time: DateTime.now(),
          isMe: true,
        ),
      );
    }
    return channel;
  }

  static Uint8List _randomPsk() {
    final rng = Random.secure();
    return Uint8List.fromList(List.generate(32, (_) => rng.nextInt(256)));
  }
}
