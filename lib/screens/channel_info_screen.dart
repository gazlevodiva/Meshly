import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:meshly/models/mesh_channel.dart';
import 'package:meshly/services/contact_store.dart';
import 'package:meshly/services/notification_settings.dart';
import 'package:meshly/services/qr_service.dart';
import 'package:meshly/theme/app_theme.dart';
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
        padding: const EdgeInsets.all(AppSpacing.s24),
        child: Column(
          children: [
            // Шапка
            CircleAvatar(
              radius: 36,
              backgroundColor:
                  Theme.of(context).colorScheme.primaryContainer,
              child: Text(
                channel.avatarEmoji ?? '📡',
                style: const TextStyle(fontSize: AppSizes.emojiHeader),
              ),
            ),
            const SizedBox(height: AppSpacing.s12),
            Text(
              channel.name,
              style: AppTextStyles.headline,
            ),
            Text(
              'Слот ${channel.slotIndex}',
              style: AppTextStyles.secondary(context),
            ),
            const SizedBox(height: AppSpacing.s32),

            // Приглашение — QR
            Text(
              'Поделитесь QR-кодом чтобы пригласить участника',
              textAlign: TextAlign.center,
              style: AppTextStyles.subtitle(context),
            ),
            const SizedBox(height: AppSpacing.s16),
            Container(
              decoration: BoxDecoration(
                color: context.appColors.qrCardBackground,
                borderRadius: BorderRadius.circular(AppRadius.qrCard),
                boxShadow: [
                  BoxShadow(
                    color: context.appColors.qrCardShadow,
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              padding: const EdgeInsets.all(AppSpacing.s16),
              child: QrImageView(
                data: _qrData,
                size: AppSizes.qrMedium,
              ),
            ),
            const SizedBox(height: AppSpacing.s16),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => _copyLink(context),
                icon: const Icon(Icons.link),
                label: const Text('Скопировать ссылку'),
              ),
            ),
            const SizedBox(height: AppSpacing.s32),

            // Уведомления
            ListenableBuilder(
              listenable: NotificationSettings.instance,
              builder: (context, _) {
                final convId = 'ch_${channel.id}';
                final settings = NotificationSettings.instance;
                final muted = settings.isMuted(convId);
                return SwitchListTile(
                  secondary: Icon(muted
                      ? Icons.notifications_off_outlined
                      : Icons.notifications_outlined),
                  title: const Text('Уведомления'),
                  value: !muted,
                  onChanged: (v) async {
                    if (v) {
                      await settings.unmuteConversation(convId);
                    } else {
                      await settings.muteConversation(convId);
                    }
                  },
                );
              },
            ),
            const SizedBox(height: AppSpacing.s16),

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
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.s8),
      child: Row(
        children: [
          Icon(icon,
              size: AppIconSizes.info, color: context.appColors.iconSecondary),
          const SizedBox(width: AppSpacing.s12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: AppTextStyles.label(context)),
                Text(
                  value,
                  style: AppTextStyles.body.copyWith(
                    fontFamily: monospace ? AppTextStyles.monoFamily : null,
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
