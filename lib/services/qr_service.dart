import 'dart:convert';
import 'dart:typed_data';

import 'package:meshly/models/contact.dart';
import 'package:meshly/models/mesh_channel.dart';

// URL схема:
// mesh://contact/!1f8e42c9?name=Dentro&emoji=👩
// mesh://channel/gazchannel?psk=base64&slot=2&emoji=🏕️

class QrService {
  static const _scheme = 'mesh';

  // ── Encode ────────────────────────────────────────────────

  static String encodeContact(Contact c, {String? myNodeId}) {
    final nodeId = myNodeId ?? c.nodeId;
    final params = {'name': c.displayName};
    if (c.avatarEmoji != null) params['emoji'] = c.avatarEmoji!;
    if (c.publicKey != null) params['pk'] = base64Url.encode(c.publicKey!);
    return Uri(
      scheme: _scheme,
      host: 'contact',
      path: '/$nodeId',
      queryParameters: params,
    ).toString();
  }

  static String encodeChannel(MeshChannel ch) {
    return Uri(
      scheme: _scheme,
      host: 'channel',
      path: '/${Uri.encodeComponent(ch.name)}',
      queryParameters: {
        'psk': base64Url.encode(ch.psk),
        'slot': ch.slotIndex.toString(),
        if (ch.avatarEmoji != null) 'emoji': ch.avatarEmoji,
      },
    ).toString();
  }

  // ── Decode ────────────────────────────────────────────────

  static ContactQrData? decodeContact(String raw) {
    try {
      final uri = Uri.parse(raw);
      if (uri.scheme != _scheme || uri.host != 'contact') return null;
      final nodeId = uri.pathSegments.isNotEmpty
          ? uri.pathSegments.first
          : null;
      if (nodeId == null || !nodeId.startsWith('!')) return null;
      final pkStr = uri.queryParameters['pk'];
      return ContactQrData(
        nodeId: nodeId,
        displayName: uri.queryParameters['name'] ?? nodeId,
        avatarEmoji: uri.queryParameters['emoji'],
        publicKey: pkStr != null ? base64Url.decode(pkStr) : null,
      );
    } on Exception catch (_) {
      return null;
    }
  }

  static ChannelQrData? decodeChannel(String raw) {
    try {
      final uri = Uri.parse(raw);
      if (uri.scheme != _scheme || uri.host != 'channel') return null;
      final name = uri.pathSegments.isNotEmpty ? uri.pathSegments.first : null;
      final pskStr = uri.queryParameters['psk'];
      final slotStr = uri.queryParameters['slot'];
      if (name == null || pskStr == null || slotStr == null) return null;
      final slotIndex = int.tryParse(slotStr);
      if (slotIndex == null || slotIndex < 1 || slotIndex > 7) return null;
      return ChannelQrData(
        name: name,
        psk: base64Url.decode(pskStr),
        slotIndex: slotIndex,
        avatarEmoji: uri.queryParameters['emoji'],
      );
    } on Exception catch (_) {
      return null;
    }
  }

  // Определяем тип QR по содержимому
  static QrType? detectType(String raw) {
    try {
      final uri = Uri.parse(raw);
      if (uri.scheme != _scheme) return null;
      if (uri.host == 'contact') return QrType.contact;
      if (uri.host == 'channel') return QrType.channel;
      return null;
    } on Exception catch (_) {
      return null;
    }
  }
}

enum QrType { contact, channel }

class ContactQrData {
  const ContactQrData({
    required this.nodeId,
    required this.displayName,
    this.avatarEmoji,
    this.publicKey,
  });

  final String nodeId;
  final String displayName;
  final String? avatarEmoji;
  final Uint8List? publicKey;
}

class ChannelQrData {
  const ChannelQrData({
    required this.name,
    required this.psk,
    required this.slotIndex,
    this.avatarEmoji,
  });

  final String name;
  final Uint8List psk;
  final int slotIndex;
  final String? avatarEmoji;
}
