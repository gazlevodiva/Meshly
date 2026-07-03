import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:meshly/models/mesh_channel.dart';
import 'package:meshly/services/contact_store.dart';
import 'package:meshly/services/qr_service.dart';
import 'package:qr_flutter/qr_flutter.dart';

class ChannelInfoScreen extends StatelessWidget {
  const ChannelInfoScreen({required this.channel, super.key});

  final MeshChannel channel;

  String get _qrData => QrService.encodeChannel(channel);

  void _copyLink(BuildContext context) {
    unawaited(Clipboard.setData(ClipboardData(text: _qrData)));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Ссылка скопирована')),
    );
  }

  Future<void> _deleteChannel(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Удалить канал?'),
        content: Text('Канал "${channel.name}" будет удалён локально. '
            'Другие участники продолжат его видеть.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Отмена'),
          ),
          TextButton(
            style: TextButton.styleFrom(
                foregroundColor: Theme.of(context).colorScheme.error),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Удалить'),
          ),
        ],
      ),
    );
    if (confirmed == true && context.mounted) {
      await ContactStore.instance.deleteChannel(channel.id);
      if (context.mounted) Navigator.pop(context, 'deleted');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${channel.avatarEmoji ?? '📡'} ${channel.name}'),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline),
            tooltip: 'Удалить канал',
            onPressed: () => _deleteChannel(context),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            // Шапка
            CircleAvatar(
              radius: 36,
              backgroundColor:
                  Theme.of(context).colorScheme.primaryContainer,
              child: Text(
                channel.avatarEmoji ?? '📡',
                style: const TextStyle(fontSize: 36),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              channel.name,
              style: const TextStyle(
                  fontSize: 22, fontWeight: FontWeight.w600),
            ),
            Text(
              'Слот ${channel.slotIndex}',
              style: const TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 32),

            // Приглашение — QR
            const Text(
              'Поделитесь QR-кодом чтобы пригласить участника',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey, fontSize: 13),
            ),
            const SizedBox(height: 16),
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withAlpha(20),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              padding: const EdgeInsets.all(16),
              child: QrImageView(
                data: _qrData,
                size: 200,
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => _copyLink(context),
                icon: const Icon(Icons.link),
                label: const Text('Скопировать ссылку'),
              ),
            ),
            const SizedBox(height: 32),

            // Инфо
            const _InfoRow(
              label: 'Шифрование',
              value: 'AES-256, уникальный ключ',
              icon: Icons.lock_outline,
            ),
            _InfoRow(
              label: 'Ключ (PSK)',
              value: _truncatePsk(channel.psk),
              icon: Icons.key,
              monospace: true,
            ),
          ],
        ),
      ),
    );
  }

  static String _truncatePsk(List<int> psk) {
    final hex = psk.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    return '${hex.substring(0, 8)}…${hex.substring(hex.length - 8)}';
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.label,
    required this.value,
    required this.icon,
    this.monospace = false,
  });

  final String label;
  final String value;
  final IconData icon;
  final bool monospace;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, size: 18, color: Colors.grey),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style:
                        const TextStyle(fontSize: 11, color: Colors.grey)),
                Text(
                  value,
                  style: TextStyle(
                    fontFamily: monospace ? 'monospace' : null,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
