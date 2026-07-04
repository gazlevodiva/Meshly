import 'package:flutter/material.dart';
import 'package:meshly/models/conversation.dart';
import 'package:meshly/models/message.dart';
import 'package:meshly/services/contact_store.dart';
import 'package:meshly/services/notification_settings.dart';
import 'package:meshly/theme/app_theme.dart';
import 'package:meshly/utils/date_format_ru.dart';

/// A conversation rendered as a rounded surface card:
/// 48px emoji avatar (with online dot), title + last-message preview
/// (+ presence line for DMs), and time / unread badge on the right.
class ConversationTile extends StatelessWidget {
  const ConversationTile({
    required this.conv,
    required this.title,
    required this.onTap,
    super.key,
    this.emoji,
    this.isOnline = false,
    this.lastHeard,
  });

  final Conversation conv;
  final String title;
  final String? emoji;
  final bool isOnline;
  final VoidCallback onTap;

  /// When the DM peer was last heard on the mesh (drives the
  /// "Был(а) в сети ..." line while offline).
  final DateTime? lastHeard;

  @override
  Widget build(BuildContext context) {
    final last = conv.lastMessage;
    final hasUnread = conv.unreadCount > 0;
    final radius = BorderRadius.circular(AppRadius.cardLarge);
    final heard = lastHeard;
    final showPresence = conv.isDm && !isOnline && heard != null;

    return ListenableBuilder(
      listenable: NotificationSettings.instance,
      builder: (context, _) {
        final muted = NotificationSettings.instance.isMuted(conv.id);
        return Material(
          color: Theme.of(context).colorScheme.surfaceContainer,
          borderRadius: radius,
          child: InkWell(
            onTap: onTap,
            borderRadius: radius,
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.s12),
              // IntrinsicHeight lets the trailing time/mute column pin to the
              // top edge while the avatar stays vertically centered.
              child: IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(
                      child: ListAvatar(
                        emoji: emoji,
                        title: title,
                        isOnline: isOnline && conv.isDm,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.s12),
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: AppTextStyles.cardTitle.copyWith(
                              fontWeight: hasUnread
                                  ? FontWeight.w700
                                  : FontWeight.w600,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (last != null) ...[
                            const SizedBox(height: AppSpacing.s2),
                            _LastMessageRow(msg: last),
                          ],
                          if (showPresence) ...[
                            const SizedBox(height: AppSpacing.s2),
                            PresenceLine(lastHeard: heard),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(width: AppSpacing.s8),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        if (muted || last != null)
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (muted)
                                Padding(
                                  padding: const EdgeInsets.only(
                                    right: AppSpacing.s4,
                                  ),
                                  child: Icon(
                                    Icons.notifications_off_outlined,
                                    size: AppIconSizes.mute,
                                    color: context.appColors.iconSecondary,
                                  ),
                                ),
                              if (last != null)
                                Text(
                                  _formatTime(last.time),
                                  style: AppTextStyles.label(context).copyWith(
                                    color: hasUnread && !muted
                                        ? Theme.of(context).colorScheme.primary
                                        : context.appColors.textSecondary,
                                  ),
                                ),
                            ],
                          ),
                        if (hasUnread) ...[
                          const SizedBox(height: AppSpacing.s6),
                          _Badge(count: conv.unreadCount, muted: muted),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  static String _formatTime(DateTime t) {
    final now = DateTime.now();
    if (now.difference(t).inDays == 0) {
      return '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
    }
    return '${t.day}.${t.month.toString().padLeft(2, '0')}';
  }
}

/// 48px circular list avatar with an emoji (or initial letter) and an
/// optional green online dot on the edge. Shared by chats and contacts.
class ListAvatar extends StatelessWidget {
  const ListAvatar({
    required this.title,
    super.key,
    this.emoji,
    this.isOnline = false,
  });

  final String? emoji;
  final String title;
  final bool isOnline;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Stack(
      children: [
        Container(
          width: AppSizes.avatarList,
          height: AppSizes.avatarList,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: scheme.primaryContainer,
            shape: BoxShape.circle,
          ),
          child: emoji != null
              ? Text(
                  emoji!,
                  style: const TextStyle(fontSize: AppSizes.emojiLarge),
                )
              : Text(
                  title.isNotEmpty ? title[0].toUpperCase() : '?',
                  style: AppTextStyles.title.copyWith(
                    color: scheme.onPrimaryContainer,
                  ),
                ),
        ),
        if (isOnline)
          Positioned(
            right: 0,
            bottom: 0,
            child: Container(
              width: AppSizes.statusDot,
              height: AppSizes.statusDot,
              decoration: BoxDecoration(
                color: context.appColors.online,
                shape: BoxShape.circle,
                border: Border.all(
                  color: scheme.surfaceContainer,
                  width: AppSizes.statusDotBorder,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// Presence line for a DM peer: green "В сети" while online, otherwise
/// grey "Был(а) в сети <когда>" when the last-heard time is known.
class PresenceLine extends StatelessWidget {
  const PresenceLine({required this.lastHeard, super.key});

  // Online state is shown by the green dot on the avatar; this line only
  // appears for offline peers with a known last-heard time.
  final DateTime lastHeard;

  @override
  Widget build(BuildContext context) {
    return Text(
      'Был(а) в сети ${formatLastHeardRu(lastHeard)}',
      style: AppTextStyles.label(context),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }
}

class _LastMessageRow extends StatelessWidget {
  const _LastMessageRow({required this.msg});

  final Message msg;

  @override
  Widget build(BuildContext context) {
    final store = ContactStore.instance;
    final prefix = msg.isMe
        ? 'Я: '
        : '${store.displayNameFor(msg.fromNodeId)}: ';
    return Text(
      '$prefix${msg.text}',
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: AppTextStyles.subtitle(context),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.count, this.muted = false});

  final int count;

  /// Muted conversations get a grey badge instead of the primary blue.
  final bool muted;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.s6,
        vertical: AppSpacing.s2,
      ),
      decoration: BoxDecoration(
        color: muted
            ? context.appColors.iconSecondary
            : Theme.of(context).colorScheme.primary,
        borderRadius: BorderRadius.circular(AppRadius.badge),
      ),
      child: Text(
        count > 99 ? '99+' : '$count',
        style: AppTextStyles.badge(context),
      ),
    );
  }
}
