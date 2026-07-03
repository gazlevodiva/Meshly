import 'dart:async';

import 'package:flutter/material.dart';
import 'package:meshly/models/contact.dart';
import 'package:meshly/models/conversation.dart';
import 'package:meshly/models/message.dart';
import 'package:meshly/screens/channel_info_screen.dart';
import 'package:meshly/screens/edit_contact_screen.dart';
import 'package:meshly/services/contact_store.dart';
import 'package:meshly/services/mesh_service.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({
    required this.meshService,
    required this.conversation,
    super.key,
  });

  final MeshService meshService;
  final Conversation conversation;

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  final ContactStore _store = ContactStore.instance;
  StreamSubscription<Message>? _sub;

  List<Message> get _messages => _store.messagesFor(widget.conversation.id);

  @override
  void initState() {
    super.initState();
    unawaited(_store.markRead(widget.conversation.id));
    _sub = widget.meshService.incomingMessages.listen((msg) {
      if (msg.conversationId == widget.conversation.id && mounted) {
        setState(() {});
        _scrollToBottom();
      }
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
  }

  @override
  void dispose() {
    unawaited(_sub?.cancel());
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        unawaited(_scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        ));
      }
    });
  }

  String _shortNodeId(String nodeId) {
    if (nodeId.startsWith('!') && nodeId.length > 9) {
      return '!${nodeId.substring(nodeId.length - 8)}';
    }
    return nodeId;
  }

  Future<void> _showAddContactDialog() async {
    final conv = widget.conversation;
    final nodeId = conv.peerId!;
    final nameCtrl = TextEditingController();
    var selectedEmoji = '😊';

    const emojis = [
      '😊', '👩', '👨', '👵', '👴', '👦', '👧',
      '🐕', '🐈', '🏕️', '🏠', '❤️', '⭐', '🔥',
    ];

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Добавить контакт'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(nodeId,
                  style: const TextStyle(
                      fontSize: 12,
                      color: Colors.grey,
                      fontFamily: 'monospace')),
              const SizedBox(height: 16),
              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(labelText: 'Имя'),
                autofocus: true,
                onChanged: (_) => setDialogState(() {}),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 6,
                children: emojis.map((e) => GestureDetector(
                  onTap: () => setDialogState(() => selectedEmoji = e),
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: e == selectedEmoji
                          ? Theme.of(ctx).colorScheme.primaryContainer
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Center(
                        child: Text(e,
                            style: const TextStyle(fontSize: 22))),
                  ),
                )).toList(),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Отмена'),
            ),
            FilledButton(
              onPressed: nameCtrl.text.trim().isNotEmpty
                  ? () => Navigator.pop(ctx, true)
                  : null,
              child: const Text('Добавить'),
            ),
          ],
        ),
      ),
    );

    if (confirmed == true && mounted) {
      final name = nameCtrl.text.trim();
      if (name.isNotEmpty) {
        final contact = Contact(
          nodeId: nodeId,
          displayName: name,
          avatarEmoji: selectedEmoji,
        );
        await _store.saveContact(contact);
        if (mounted) setState(() {});
      }
    }
    nameCtrl.dispose();
  }

  Future<void> _openEditContact() async {
    final conv = widget.conversation;
    if (conv.peerId == null) return;
    final contact = _store.contactByNodeId(conv.peerId!);
    if (contact == null) return;
    final result = await Navigator.push<String>(
      context,
      MaterialPageRoute(
        builder: (_) => EditContactScreen(
              contact: contact,
              meshService: widget.meshService,
            ),
      ),
    );
    if (!mounted) return;
    if (result == 'deleted') {
      Navigator.pop(context);
    } else {
      setState(() {});
    }
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    _controller.clear();
    await widget.meshService.sendText(text, widget.conversation);
    setState(() {});
    _scrollToBottom();
  }

  String get _title {
    final conv = widget.conversation;
    if (conv.isDm && conv.peerId != null) {
      final c = _store.contactByNodeId(conv.peerId!);
      return c?.displayLabel ?? conv.peerId!;
    }
    if (conv.isChannel && conv.channelId != null) {
      final ch = _store.channelById(conv.channelId!);
      if (ch != null) return '${ch.avatarEmoji != null ? "${ch.avatarEmoji} " : ""}${ch.name}';
    }
    return 'Чат';
  }

  bool get _isUnknownDm {
    final conv = widget.conversation;
    return conv.isDm &&
        conv.peerId != null &&
        _store.contactByNodeId(conv.peerId!) == null;
  }

  @override
  Widget build(BuildContext context) {
    final conv = widget.conversation;
    return Scaffold(
      appBar: AppBar(
        title: Text(_title),
        actions: [
          if (conv.isChannel)
            IconButton(
              icon: const Icon(Icons.info_outline),
              onPressed: () {
                final ch = _store.channelById(conv.channelId!);
                if (ch != null) {
                  unawaited(Navigator.push(
                    context,
                    MaterialPageRoute<void>(
                      builder: (_) => ChannelInfoScreen(channel: ch),
                    ),
                  ));
                }
              },
            ),
          if (conv.isDm &&
              conv.peerId != null &&
              _store.contactByNodeId(conv.peerId!) != null)
            IconButton(
              icon: const Icon(Icons.edit),
              onPressed: _openEditContact,
            ),
        ],
      ),
      body: Column(
        children: [
          if (_isUnknownDm)
            Container(
              color: Theme.of(context).colorScheme.primaryContainer,
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Незнакомец · ${_shortNodeId(conv.peerId!)}',
                    ),
                  ),
                  TextButton(
                    onPressed: _showAddContactDialog,
                    child: const Text('Добавить'),
                  ),
                ],
              ),
            ),
          Expanded(
            child: ListenableBuilder(
              listenable: _store,
              builder: (context, _) {
                final messages = _messages;
                return messages.isEmpty
                    ? const Center(
                        child: Text('Напишите первое сообщение!',
                            style: TextStyle(color: Colors.grey)))
                    : ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.all(12),
                        itemCount: messages.length,
                        itemBuilder: (_, i) =>
                            _MessageBubble(msg: messages[i], store: _store),
                      );
              },
            ),
          ),
          _InputBar(controller: _controller, onSend: _send),
        ],
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({required this.msg, required this.store});

  final Message msg;
  final ContactStore store;

  @override
  Widget build(BuildContext context) {
    final isMe = msg.isMe;
    final color = isMe
        ? Theme.of(context).colorScheme.primary
        : Theme.of(context).colorScheme.surfaceContainerHighest;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment:
            isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          if (!isMe)
            Padding(
              padding: const EdgeInsets.only(left: 4, bottom: 2),
              child: Text(
                store.displayNameFor(msg.fromNodeId),
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ),
          Container(
            constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.75),
            padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Text(msg.text,
                style: TextStyle(color: isMe ? Colors.white : null)),
          ),
          if (isMe)
            Padding(
              padding: const EdgeInsets.only(right: 4, top: 2),
              child: _StatusIcon(status: msg.status),
            ),
        ],
      ),
    );
  }
}

class _StatusIcon extends StatelessWidget {
  const _StatusIcon({required this.status});

  final MessageStatus status;

  @override
  Widget build(BuildContext context) {
    switch (status) {
      case MessageStatus.sending:
        return const Icon(Icons.access_time, size: 12, color: Colors.grey);
      case MessageStatus.sent:
        return const Icon(Icons.check, size: 12, color: Colors.grey);
      case MessageStatus.acked:
        return const Icon(Icons.done_all, size: 12, color: Colors.blue);
      case MessageStatus.failed:
        return const Icon(Icons.error_outline, size: 12, color: Colors.red);
    }
  }
}

class _InputBar extends StatelessWidget {
  const _InputBar({required this.controller, required this.onSend});

  final TextEditingController controller;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: controller,
                onSubmitted: (_) => onSend(),
                decoration: InputDecoration(
                  hintText: 'Сообщение...',
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24)),
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 10),
                ),
              ),
            ),
            const SizedBox(width: 8),
            FloatingActionButton(
              mini: true,
              onPressed: onSend,
              child: const Icon(Icons.send),
            ),
          ],
        ),
      ),
    );
  }
}
