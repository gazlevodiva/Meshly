import 'package:flutter/material.dart';
import '../models/conversation.dart';
import '../models/message.dart';
import '../services/contact_store.dart';

class ConversationTile extends StatelessWidget {
  final Conversation conv;
  final String title;
  final String? emoji;
  final bool isOnline;
  final VoidCallback onTap;

  const ConversationTile({
    super.key,
    required this.conv,
    required this.title,
    required this.onTap,
    this.emoji,
    this.isOnline = false,
  });

  @override
  Widget build(BuildContext context) {
    final last = conv.lastMessage;
    final hasUnread = conv.unreadCount > 0;

    return ListTile(
      onTap: onTap,
      leading: _Avatar(emoji: emoji, title: title, isOnline: isOnline && conv.isDm),
      title: Text(
        title,
        style: TextStyle(fontWeight: hasUnread ? FontWeight.w700 : FontWeight.w500),
      ),
      subtitle: last != null ? _LastMessageRow(msg: last) : null,
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (last != null)
            Text(
              _formatTime(last.time),
              style: TextStyle(
                fontSize: 11,
                color: hasUnread
                    ? Theme.of(context).colorScheme.primary
                    : Colors.grey,
              ),
            ),
          if (hasUnread) ...[
            const SizedBox(height: 4),
            _Badge(count: conv.unreadCount),
          ],
        ],
      ),
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
  final String? emoji;
  final String title;
  final bool isOnline;

  const _Avatar({this.emoji, required this.title, this.isOnline = false});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        CircleAvatar(
          backgroundColor: Theme.of(context).colorScheme.primaryContainer,
          child: emoji != null
              ? Text(emoji!, style: const TextStyle(fontSize: 22))
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
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                color: Colors.green,
                shape: BoxShape.circle,
                border: Border.all(
                  color: Theme.of(context).scaffoldBackgroundColor,
                  width: 2,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _LastMessageRow extends StatelessWidget {
  final Message msg;

  const _LastMessageRow({required this.msg});

  @override
  Widget build(BuildContext context) {
    final store = ContactStore.instance;
    final prefix = msg.isMe ? 'Я: ' : '${store.displayNameFor(msg.fromNodeId)}: ';
    return Text(
      '$prefix${msg.text}',
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: const TextStyle(fontSize: 13),
    );
  }
}

class _Badge extends StatelessWidget {
  final int count;
  const _Badge({required this.count});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primary,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        count > 99 ? '99+' : '$count',
        style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
      ),
    );
  }
}
