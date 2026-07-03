import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:meshly/models/contact.dart';
import 'package:meshly/services/contact_store.dart';
import 'package:meshly/services/mesh_service.dart';
import 'package:meshly/services/qr_service.dart';
import 'package:qr_flutter/qr_flutter.dart';

class MyCardScreen extends StatefulWidget {
  const MyCardScreen({required this.meshService, super.key});

  final MeshService meshService;

  @override
  State<MyCardScreen> createState() => _MyCardScreenState();
}

class _MyCardScreenState extends State<MyCardScreen> {
  final ContactStore _store = ContactStore.instance;
  final _nameController = TextEditingController();
  String _emoji = '😊';
  bool _editingName = false;

  String get _nodeId => widget.meshService.myNodeId ?? '!????????';

  Contact get _myContact {
    final existing = _store.contactByNodeId(_nodeId);
    if (existing != null) return existing;
    return Contact(nodeId: _nodeId, displayName: 'Я', avatarEmoji: _emoji);
  }

  String get _qrData => QrService.encodeContact(_myContact, myNodeId: _nodeId);

  @override
  void initState() {
    super.initState();
    final c = _myContact;
    _nameController.text = c.displayName;
    _emoji = c.avatarEmoji ?? '😊';
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _saveName() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) return;
    setState(() => _editingName = false);
    final c = Contact(nodeId: _nodeId, displayName: name, avatarEmoji: _emoji);
    await _store.saveContact(c);
    setState(() {});
  }

  Future<void> _pickEmoji() async {
    final picked = await showDialog<String>(
      context: context,
      builder: (_) => _EmojiPickerDialog(current: _emoji),
    );
    if (picked != null) {
      setState(() => _emoji = picked);
      final c = Contact(
        nodeId: _nodeId,
        displayName: _nameController.text.trim().isNotEmpty
            ? _nameController.text.trim()
            : 'Я',
        avatarEmoji: picked,
      );
      await _store.saveContact(c);
    }
  }

  void _copyLink() {
    unawaited(Clipboard.setData(ClipboardData(text: _qrData)));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Ссылка скопирована')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final contact = _myContact;

    return Scaffold(
      appBar: AppBar(title: const Text('Мой контакт')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            // Аватар-эмодзи
            GestureDetector(
              onTap: _pickEmoji,
              child: CircleAvatar(
                radius: 40,
                backgroundColor:
                    Theme.of(context).colorScheme.primaryContainer,
                child: Text(_emoji, style: const TextStyle(fontSize: 40)),
              ),
            ),
            TextButton(
              onPressed: _pickEmoji,
              child: const Text('Сменить'),
            ),
            const SizedBox(height: 8),

            // Имя
            if (_editingName)
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _nameController,
                      autofocus: true,
                      decoration: const InputDecoration(hintText: 'Ваше имя'),
                      onSubmitted: (_) => _saveName(),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.check),
                    onPressed: _saveName,
                  ),
                ],
              )
            else
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    contact.displayName,
                    style: const TextStyle(
                        fontSize: 22, fontWeight: FontWeight.w600),
                  ),
                  IconButton(
                    icon: const Icon(Icons.edit, size: 18),
                    onPressed: () => setState(() => _editingName = true),
                  ),
                ],
              ),

            // Node ID
            Text(
              _nodeId,
              style: const TextStyle(fontSize: 12, color: Colors.grey,
                  fontFamily: 'monospace'),
            ),
            const SizedBox(height: 32),

            // QR
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
                size: 220,
              ),
            ),
            const SizedBox(height: 24),

            // Кнопки
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _copyLink,
                    icon: const Icon(Icons.link),
                    label: const Text('Скопировать ссылку'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Text(
              'Попросите собеседника отсканировать этот QR\nили поделитесь ссылкой',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmojiPickerDialog extends StatelessWidget {
  const _EmojiPickerDialog({required this.current});

  final String current;

  static const _emojis = [
    '😊', '👩', '👨', '👵', '👴', '👦', '👧',
    '🐕', '🐈', '🐇', '🦊', '🐻', '🦁', '🐯',
    '🏕️', '🏠', '🏔️', '🌲', '⛵', '🚀', '🎯',
    '❤️', '⭐', '🔥', '💎', '🎸', '📡', '🛡️',
  ];

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Выберите эмодзи'),
      content: SizedBox(
        width: 280,
        child: Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _emojis.map((e) => GestureDetector(
            onTap: () => Navigator.pop(context, e),
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: e == current
                    ? Theme.of(context).colorScheme.primaryContainer
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Center(
                child: Text(e, style: const TextStyle(fontSize: 26)),
              ),
            ),
          )).toList(),
        ),
      ),
    );
  }
}
