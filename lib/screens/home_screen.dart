import 'dart:async';
import 'package:flutter/material.dart';
import '../models/conversation.dart';
import '../services/contact_store.dart';
import '../services/mesh_service.dart';
import '../services/notification_service.dart';
import '../widgets/conversation_tile.dart';
import 'add_contact_screen.dart';
import 'chat_screen.dart';
import 'my_card_screen.dart';
import 'new_channel_screen.dart';
import 'scan_screen.dart';

class HomeScreen extends StatefulWidget {
  final MeshService meshService;
  const HomeScreen({super.key, required this.meshService});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _store = ContactStore.instance;
  StreamSubscription? _msgSub;

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
    _msgSub?.cancel();
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
    _store.markRead(conv.id);
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChatScreen(
          meshService: widget.meshService,
          conversation: conv,
        ),
      ),
    ).then((_) => setState(() {}));
  }

  void _disconnect() async {
    await widget.meshService.disconnect();
    if (mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(
          builder: (_) => ScanScreen(meshService: widget.meshService),
        ),
        (_) => false,
      );
    }
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
        actions: [
          IconButton(
            icon: const Icon(Icons.bluetooth_disabled),
            tooltip: 'Отключиться',
            onPressed: _disconnect,
          ),
        ],
      ),
      body: convs.isEmpty
          ? _EmptyState(onAddContact: () => _showAddOptions(context))
          : ListView.separated(
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
    showModalBottomSheet(
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
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const AddContactScreen(),
                  ),
                ).then((_) => setState(() {}));
              },
            ),
            ListTile(
              leading: const Icon(Icons.group_add),
              title: const Text('Создать канал'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        NewChannelScreen(meshService: widget.meshService),
                  ),
                ).then((_) => setState(() {}));
              },
            ),
            ListTile(
              leading: const Icon(Icons.qr_code),
              title: const Text('Мой контакт'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => MyCardScreen(meshService: widget.meshService),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final VoidCallback onAddContact;
  const _EmptyState({required this.onAddContact});

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
