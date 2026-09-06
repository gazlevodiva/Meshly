import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:meshly/l10n/l10n.dart';
import 'package:meshly/models/mesh_channel.dart';
import 'package:meshly/models/message.dart';
import 'package:meshly/services/contact_store.dart';
import 'package:meshly/services/mesh_service.dart';
import 'package:meshly/services/notification_settings.dart';
import 'package:meshly/services/qr_service.dart';
import 'package:meshly/theme/app_theme.dart';
import 'package:meshly/utils/date_format.dart';
import 'package:meshly/utils/system_event_text.dart';
import 'package:meshly/widgets/qr_card.dart';
import 'package:meshly/widgets/section_card.dart';
import 'package:meshly/widgets/tab_header.dart';

class ChannelInfoScreen extends StatelessWidget {
  const ChannelInfoScreen({
    required this.channel,
    required this.meshService,
    super.key,
  });

  final MeshChannel channel;
  final MeshService meshService;

  /// The conversation id this channel is stored under (see
  /// `Conversation.channel` / `ContactStore.deleteChannel`).
  String get _conversationId => 'ch_${channel.id}';

  String get _qrData => QrService.encodeChannel(channel);

  void _copyLink(BuildContext context) {
    unawaited(Clipboard.setData(ClipboardData(text: _qrData)));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(context.l10n.linkCopied)),
    );
  }

  Future<void> _deleteChannel(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(context.l10n.deleteChannelQuestion),
        content: Text(context.l10n.deleteChannelWarning(channel.name)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(context.l10n.cancel),
          ),
          TextButton(
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: Text(context.l10n.deleteAction),
          ),
        ],
      ),
    );
    if (confirmed == true && context.mounted) {
      // Announces "left" to the mesh (best effort) before deleting locally,
      // so leaving is no longer silent — see MeshService.leaveChannelConversation.
      await meshService.leaveChannelConversation(channel);
      // No result value: the chat screen below now closes itself once the
      // channel's conversation disappears from the store (see
      // ChatScreen._onStoreChanged), so nothing reads a return signal here
      // any more — this pop only needs to take this screen off the stack.
      if (context.mounted) Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final topInset = MediaQuery.paddingOf(context).top + kToolbarHeight;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      body: TabGradientBackground(
        child: ListView(
          padding: EdgeInsets.fromLTRB(
            AppSpacing.s16,
            topInset + AppSpacing.s8,
            AppSpacing.s16,
            AppSpacing.s32,
          ),
          children: [
            // Header
            Column(
              children: [
                Container(
                  width: AppSizes.avatarLarge,
                  height: AppSizes.avatarLarge,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primaryContainer,
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      channel.avatarEmoji ?? '📡',
                      style: const TextStyle(fontSize: AppSizes.emojiAvatar),
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.s12),
                Text(channel.name, style: AppTextStyles.headline),
              ],
            ),
            const SizedBox(height: AppSpacing.s24),

            // Invite — QR
            SectionCard(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.s16),
                child: Column(
                  children: [
                    Text(
                      context.l10n.shareQrToInvite,
                      textAlign: TextAlign.center,
                      style: AppTextStyles.subtitle(context),
                    ),
                    const SizedBox(height: AppSpacing.s16),
                    QrCard(data: _qrData, size: AppSizes.qrMedium),
                    const SizedBox(height: AppSpacing.s16),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () => _copyLink(context),
                        icon: const Icon(Icons.link),
                        label: Text(context.l10n.copyLinkButton),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.s12),

            // Why there is no member list
            SectionCard(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.s14),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.info_outline,
                      size: AppIconSizes.info,
                      color: context.appColors.iconSecondary,
                    ),
                    const SizedBox(width: AppSpacing.s10),
                    Expanded(
                      child: Text(
                        context.l10n.channelMembersInfo,
                        style: AppTextStyles.subtitle(context),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.s12),

            // Log of joins and leaves this device has seen — deliberately
            // not a member list, see channelEventsNote and the widget doc.
            _ChannelEventsCard(conversationId: _conversationId),
            const SizedBox(height: AppSpacing.s12),

            // Notifications
            SectionCard(
              child: ListenableBuilder(
                listenable: NotificationSettings.instance,
                builder: (context, _) {
                  final convId = _conversationId;
                  final settings = NotificationSettings.instance;
                  final muted = settings.isMuted(convId);
                  return SwitchListTile(
                    secondary: Icon(
                      muted
                          ? Icons.notifications_off_outlined
                          : Icons.notifications_outlined,
                    ),
                    title: Text(context.l10n.notificationsTitle),
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
            ),
            const SizedBox(height: AppSpacing.s12),

            // Info
            SectionCard(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.s16,
                  vertical: AppSpacing.s8,
                ),
                child: Column(
                  children: [
                    _InfoRow(
                      label: context.l10n.encryptionLabel,
                      value: context.l10n.encryptionValue,
                      icon: Icons.lock_outline,
                    ),
                    _InfoRow(
                      label: context.l10n.pskLabel,
                      value: _truncatePsk(channel.psk),
                      icon: Icons.key,
                      monospace: true,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.s12),

            // Danger zone
            SectionCard(
              child: ListTile(
                leading: Icon(
                  Icons.delete_outline,
                  color: Theme.of(context).colorScheme.error,
                ),
                title: Text(
                  context.l10n.deleteChannelAction,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
                onTap: () => _deleteChannel(context),
              ),
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
          Icon(
            icon,
            size: AppIconSizes.info,
            color: context.appColors.iconSecondary,
          ),
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

/// A history of the joins and leaves *this device* has seen — never a member
/// list. An announcement is a single unacknowledged broadcast, LoRa drops
/// packets routinely, and anyone who joined before this feature existed or
/// while this device was out of range never appears here. Framed honestly
/// via the `channelEventsTitle`/`channelEventsNote` ARB strings rather than
/// as a roster — see the sprint brief and CLAUDE.md → "Conversations are not
/// hardware channel slots".
class _ChannelEventsCard extends StatelessWidget {
  const _ChannelEventsCard({required this.conversationId});

  final String conversationId;

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.s16),
        child: ListenableBuilder(
          listenable: ContactStore.instance,
          builder: (context, _) {
            // Newest first: messagesFor returns chronological order, so the
            // filtered system events are reversed for display.
            final events = ContactStore.instance
                .messagesFor(conversationId)
                .where((m) => m.isSystemEvent)
                .toList()
                .reversed
                .toList();
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.l10n.channelEventsTitle,
                  style: AppTextStyles.cardTitle,
                ),
                const SizedBox(height: AppSpacing.s4),
                Text(
                  context.l10n.channelEventsNote,
                  style: AppTextStyles.caption(context),
                ),
                const SizedBox(height: AppSpacing.s12),
                if (events.isEmpty)
                  Text(
                    context.l10n.channelEventsEmpty,
                    style: AppTextStyles.caption(context),
                  )
                else
                  for (var i = 0; i < events.length; i++) ...[
                    if (i > 0) const SizedBox(height: AppSpacing.s10),
                    _EventRow(msg: events[i]),
                  ],
              ],
            );
          },
        ),
      ),
    );
  }
}

/// One row of the joins/leaves log: icon, the same localized line the chat
/// timeline shows, and when this device saw it.
class _EventRow extends StatelessWidget {
  const _EventRow({required this.msg});

  final Message msg;

  @override
  Widget build(BuildContext context) {
    final text = systemEventText(context, msg);
    final kind = msg.eventKind;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          kind == SystemEventKind.joined ? Icons.login : Icons.logout,
          size: AppIconSizes.info,
          color: context.appColors.iconSecondary,
        ),
        const SizedBox(width: AppSpacing.s10),
        // A Column, not a trailing fixed-width time next to the text: at a
        // large system font a same-line timestamp would either overflow the
        // card or force the text to fight it for width.
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(text, style: AppTextStyles.body),
              const SizedBox(height: AppSpacing.s2),
              Text(
                formatLastHeard(context.l10n, msg.time),
                style: AppTextStyles.label(context),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
