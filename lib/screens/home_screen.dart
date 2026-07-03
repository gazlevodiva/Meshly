import 'dart:async';

import 'package:flutter/material.dart';
import 'package:meshly/models/conversation.dart';
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
  final TextEditingController _searchController = TextEditingController();
  bool _searching = false;
  String _query = '';

  @override
  void initState() {
    super.initState();
    // List rebuilds via ListenableBuilder on ContactStore changes.
    // We still need the stream to drive scroll-to-bottom in ChatScreen,
    // but HomeScreen itself reacts to ContactStore notifications.
    NotificationService.instance.onNotificationTap = (convId) {
      if (!mounted) return;
      final conv = _store.conversations.where((c) => c.id == convId).firstOrNull;
      if (conv != null) _openChat(conv);
    };
  }

  @override
  void dispose() {
    // Clear the callback so it doesn't reference this disposed widget.
    NotificationService.instance.onNotificationTap = null;
    _searchController.dispose();
    super.dispose();
  }

  void _startSearch() {
    setState(() => _searching = true);
  }

  void _stopSearch() {
    _searchController.clear();
    setState(() {
      _searching = false;
      _query = '';
    });
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
    ));
    // No setState needed — ContactStore.notifyListeners() triggers rebuild.
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: _searching
            ? TextField(
                controller: _searchController,
                autofocus: true,
                decoration: const InputDecoration(
                  hintText: 'Поиск...',
                  border: InputBorder.none,
                ),
                onChanged: (value) => setState(() => _query = value),
              )
            : ValueListenableBuilder<String?>(
                valueListenable: widget.meshService.deviceName,
                builder: (_, deviceName, _) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('Meshly'),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color:
                                  deviceName != null ? Colors.green : Colors.grey,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            deviceName ?? 'нет подключения',
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.grey,
                            ),
                          ),
                        ],
                      ),
                    ],
                  );
                },
              ),
        actions: _searching
            ? [
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: _stopSearch,
                ),
              ]
            : [
                IconButton(
                  icon: const Icon(Icons.search),
                  onPressed: _startSearch,
                ),
                IconButton(
                  icon: const Icon(Icons.add),
                  onPressed: () => _showAddOptions(context),
                ),
              ],
      ),
      body: ListenableBuilder(
        listenable: _store,
        builder: (context, _) {
          final query = _query.trim().toLowerCase();
          final convs = query.isEmpty
              ? _conversations
              : _conversations
                  .where(
                      (c) => _titleFor(c).toLowerCase().contains(query))
                  .toList();
          if (convs.isEmpty) {
            return query.isNotEmpty
                ? const Center(
                    child: Text(
                      'Ничего не найдено',
                      style: TextStyle(color: Colors.grey),
                    ),
                  )
                : _EmptyState(onAddContact: () => _showAddOptions(context));
          }
          return ListView.separated(
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
                isOnline:
                    peerId != null && widget.meshService.isOnline(peerId),
                onTap: () => _openChat(conv),
              );
            },
          );
        },
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
                ));
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
                ));
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
