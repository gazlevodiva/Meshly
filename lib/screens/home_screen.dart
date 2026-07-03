import 'dart:async';

import 'package:flutter/material.dart';
import 'package:meshly/models/conversation.dart';
import 'package:meshly/models/message.dart';
import 'package:meshly/screens/add_contact_screen.dart';
import 'package:meshly/screens/chat_screen.dart';
import 'package:meshly/screens/my_card_screen.dart';
import 'package:meshly/screens/new_channel_screen.dart';
import 'package:meshly/services/contact_store.dart';
import 'package:meshly/services/mesh_service.dart';
import 'package:meshly/services/notification_service.dart';
import 'package:meshly/widgets/conversation_tile.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({required this.meshService, super.key});

  final MeshService meshService;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final ContactStore _store = ContactStore.instance;
  StreamSubscription<Message>? _msgSub;

  @override
  void initState() {
    super.initState();
    // Обновляем список при каждом новом сообщении
    _msgSub = widget.meshService.incomingMessages.listen((_) {
      if (mounted) setState(() {});
    });

    // Навигация при тапе на уведомление
    NotificationService.instance.onNotificationTap = (convId) {
      final conv = _store.conversations.where((c) => c.id == convId).firstOrNull;
      if (conv != null) _openChat(conv);
    };
  }

  @override
  void dispose() {
    unawaited(_msgSub?.cancel());
    super.dispose();
  }

  List<Conversation> get _conversations => _store.conversations;

  String _titleFor(Conversation conv) {
    if (conv.isDm && conv.peerId != null) {
      return _store.contactByNodeId(conv.peerId!)?.displayName ?? conv.peerId!;
    }
    if (conv.isChannel && conv.channelId != null) {
      return _store.channelById(conv.channelId!)?.name ?? conv.channelId!;
    }
    return '—';
  }

  String? _emojiFor(Conversation conv) {
    if (conv.isDm && conv.peerId != null) {
      return _store.contactByNodeId(conv.peerId!)?.avatarEmoji;
    }
    if (conv.isChannel && conv.channelId != null) {
      return _store.channelById(conv.channelId!)?.avatarEmoji;
    }
    return null;
  }

  void _openChat(Conversation conv) {
    unawaited(_store.markRead(conv.id));
    unawaited(Navigator.push<void>(
      context,
      MaterialPageRoute<void>(
        builder: (_) => ChatScreen(
          meshService: widget.meshService,
          conversation: conv,
        ),
      ),
    ).then((_) => setState(() {})));
  }

  @override
  Widget build(BuildContext context) {
    final convs = _conversations;

    return Scaffold(
      appBar: AppBar(
        title: StreamBuilder<String?>(
          stream: widget.meshService.connectedDeviceName,
          builder: (_, snap) => Text(snap.data != null ? 'Meshly · ${snap.data}' : 'Meshly'),
        ),
      ),
      body: convs.isEmpty
          ? _EmptyState(onAddContact: () => _showAddOptions(context))
          : ListView.separated(
              padding: const EdgeInsets.only(bottom: 96),
              itemCount: convs.length,
              separatorBuilder: (_, _) => const Divider(height: 1, indent: 72),
              itemBuilder: (_, i) {
                final conv = convs[i];
                final peerId = conv.isDm ? conv.peerId : null;
                return ConversationTile(
                  conv: conv,
                  title: _titleFor(conv),
                  emoji: _emojiFor(conv),
                  isOnline: peerId != null && widget.meshService.isOnline(peerId),
                  onTap: () => _openChat(conv),
                );
              },
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddOptions(context),
        child: const Icon(Icons.edit),
      ),
    );
  }

  void _showAddOptions(BuildContext context) {
    unawaited(showModalBottomSheet(
      context: context,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.person_add),
              title: const Text('Добавить контакт'),
              onTap: () {
                Navigator.pop(context);
                unawaited(Navigator.push<void>(
                  context,
                  MaterialPageRoute<void>(
                    builder: (_) => const AddContactScreen(),
                  ),
                ).then((_) => setState(() {})));
              },
            ),
            ListTile(
              leading: const Icon(Icons.group_add),
              title: const Text('Создать канал'),
              onTap: () {
                Navigator.pop(context);
                unawaited(Navigator.push<void>(
                  context,
                  MaterialPageRoute<void>(
                    builder: (_) =>
                        NewChannelScreen(meshService: widget.meshService),
                  ),
                ).then((_) => setState(() {})));
              },
            ),
            ListTile(
              leading: const Icon(Icons.qr_code),
              title: const Text('Мой контакт'),
              onTap: () {
                Navigator.pop(context);
                unawaited(Navigator.push<void>(
                  context,
                  MaterialPageRoute<void>(
                    builder: (_) => MyCardScreen(meshService: widget.meshService),
                  ),
                ));
              },
            ),
          ],
        ),
      ),
    ));
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onAddContact});

  final VoidCallback onAddContact;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('👋', style: TextStyle(fontSize: 56)),
          const SizedBox(height: 16),
          const Text(
            'Пока нет чатов',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          const Text(
            'Добавьте контакт или создайте канал',
            style: TextStyle(color: Colors.grey),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: onAddContact,
            icon: const Icon(Icons.person_add),
            label: const Text('Добавить контакт'),
          ),
        ],
      ),
    );
  }
}
