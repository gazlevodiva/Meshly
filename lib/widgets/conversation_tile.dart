import 'package:flutter/material.dart';
import 'package:meshly/models/conversation.dart';
import 'package:meshly/models/message.dart';
import 'package:meshly/services/contact_store.dart';
import 'package:meshly/services/notification_settings.dart';
import 'package:meshly/theme/app_theme.dart';

class ConversationTile extends StatelessWidget {
  const ConversationTile({
    required this.conv,
    required this.title,
    required this.onTap,
    super.key,
    this.emoji,
    this.isOnline = false,
  });

  final Conversation conv;
  final String title;
  final String? emoji;
  final bool isOnline;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final last = conv.lastMessage;
    final hasUnread = conv.unreadCount > 0;

    return ListenableBuilder(
      listenable: NotificationSettings.instance,
      builder: (context, _) {
        final muted = NotificationSettings.instance.isMuted(conv.id);
        return ListTile(
          onTap: onTap,
          leading:
              _Avatar(emoji: emoji, title: title, isOnline: isOnline && conv.isDm),
          title: Text(
            title,
            style: TextStyle(
                fontWeight: hasUnread ? FontWeight.w700 : FontWeight.w500),
            overflow: TextOverflow.ellipsis,
          ),
          subtitle: last != null ? _LastMessageRow(msg: last) : null,
          trailing: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (muted || last != null)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (muted)
                      const Padding(
                        padding: EdgeInsets.only(right: AppSpacing.s4),
                        child: Icon(Icons.notifications_off_outlined,
                            size: AppIconSizes.mute,
                            color: AppColors.iconSecondary),
                      ),
                    if (last != null)
                      Text(
                        _formatTime(last.time),
                        style: AppTextStyles.label.copyWith(
                          color: hasUnread
                              ? Theme.of(context).colorScheme.primary
                              : AppColors.textSecondary,
                        ),
                      ),
                  ],
                ),
              if (hasUnread) ...[
                const SizedBox(height: AppSpacing.s4),
                _Badge(count: conv.unreadCount),
              ],
            ],
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

class _Avatar extends StatelessWidget {
  const _Avatar({required this.title, this.emoji, this.isOnline = false});

  final String? emoji;
  final String title;
  final bool isOnline;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        CircleAvatar(
          backgroundColor: Theme.of(context).colorScheme.primaryContainer,
          child: emoji != null
              ? Text(emoji!, style: const TextStyle(fontSize: AppSizes.emojiSmall))
              : Text(
                  title.isNotEmpty ? title[0].toUpperCase() : '?',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.onPrimaryContainer,
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
                color: AppColors.online,
                shape: BoxShape.circle,
                border: Border.all(
                  color: Theme.of(context).scaffoldBackgroundColor,
                  width: AppSizes.statusDotBorder,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _LastMessageRow extends StatelessWidget {
  const _LastMessageRow({required this.msg});

  final Message msg;

  @override
  Widget build(BuildContext context) {
    final store = ContactStore.instance;
    final prefix = msg.isMe ? 'Я: ' : '${store.displayNameFor(msg.fromNodeId)}: ';
    return Text(
      '$prefix${msg.text}',
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: AppTextStyles.body,
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.s6, vertical: AppSpacing.s2),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primary,
        borderRadius: BorderRadius.circular(AppRadius.badge),
      ),
      child: Text(
        count > 99 ? '99+' : '$count',
        style: AppTextStyles.badge,
      ),
    );
  }
}
