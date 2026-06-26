import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../models/contact.dart';
import '../services/contact_store.dart';
import '../services/qr_service.dart';

class EditContactScreen extends StatefulWidget {
  final Contact contact;
  const EditContactScreen({super.key, required this.contact});

  @override
  State<EditContactScreen> createState() => _EditContactScreenState();
}

class _EditContactScreenState extends State<EditContactScreen> {
  final _store = ContactStore.instance;
  late final TextEditingController _nameCtrl;
  late String _emoji;
  bool _saving = false;

  static const _emojis = [
    '😊', '👩', '👨', '👵', '👴', '👦', '👧',
    '🐕', '🐈', '🏕️', '🏠', '❤️', '⭐', '🔥',
  ];

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.contact.displayName);
    _emoji = widget.contact.avatarEmoji ?? '😊';
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) return;
    setState(() => _saving = true);
    widget.contact.displayName = name;
    widget.contact.avatarEmoji = _emoji;
    await _store.saveContact(widget.contact);
    if (mounted) Navigator.pop(context, 'saved');
  }

  Future<void> _shareContact() async {
    final qrUrl = QrService.encodeContact(widget.contact);
    if (!mounted) return;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 36,
              height: 4,
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Text(
              'Поделиться контактом',
              style: Theme.of(ctx).textTheme.titleLarge,
            ),
            const SizedBox(height: 20),
            QrImageView(
              data: qrUrl,
              version: QrVersions.auto,
              size: 220,
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Theme.of(ctx).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                qrUrl,
                style: const TextStyle(
                  fontSize: 11,
                  fontFamily: 'monospace',
                ),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                icon: const Icon(Icons.copy),
                label: const Text('Скопировать ссылку'),
                onPressed: () async {
                  await Clipboard.setData(ClipboardData(text: qrUrl));
                  if (!ctx.mounted) return;
                  Navigator.pop(ctx);
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Ссылка скопирована')),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _deleteContact() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Удалить контакт?'),
        content: Text(
          'Контакт «${widget.contact.displayName}» будет удалён.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Отмена'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.error,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Удалить'),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      await _store.deleteContact(widget.contact.nodeId);
      if (mounted) Navigator.pop(context, 'deleted');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Редактировать контакт'),
        actions: [
          TextButton(
            onPressed: _nameCtrl.text.trim().isNotEmpty && !_saving ? _save : null,
            child: const Text('Сохранить'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          // Avatar
          Center(
            child: GestureDetector(
              onTap: () {
                showModalBottomSheet(
                  context: context,
                  builder: (ctx) => Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Выберите эмодзи',
                            style: Theme.of(ctx).textTheme.titleMedium),
                        const SizedBox(height: 16),
                        Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          children: _emojis.map((e) => GestureDetector(
                            onTap: () {
                              setState(() => _emoji = e);
                              Navigator.pop(ctx);
                            },
                            child: Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                color: e == _emoji
                                    ? Theme.of(ctx).colorScheme.primaryContainer
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Center(
                                child: Text(e,
                                    style: const TextStyle(fontSize: 26)),
                              ),
                            ),
                          )).toList(),
                        ),
                        const SizedBox(height: 24),
                      ],
                    ),
                  ),
                );
              },
              child: Stack(
                alignment: Alignment.bottomRight,
                children: [
                  Container(
                    width: 96,
                    height: 96,
                    decoration: BoxDecoration(
                      color: Theme.of(context)
                          .colorScheme
                          .primaryContainer,
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(_emoji,
                          style: const TextStyle(fontSize: 52)),
                    ),
                  ),
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primary,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.edit,
                        size: 16, color: Colors.white),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Name field
          TextField(
            controller: _nameCtrl,
            decoration: const InputDecoration(
              labelText: 'Имя',
              border: OutlineInputBorder(),
            ),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 20),

          // Emoji grid
          const Text('Эмодзи',
              style: TextStyle(color: Colors.grey, fontSize: 13)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _emojis.map((e) => GestureDetector(
              onTap: () => setState(() => _emoji = e),
              child: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: e == _emoji
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

          const SizedBox(height: 32),
          const Divider(),

          // Share
          ListTile(
            leading: const Icon(Icons.share),
            title: const Text('Поделиться контактом'),
            onTap: _shareContact,
          ),

          // Delete
          ListTile(
            leading: Icon(Icons.delete,
                color: Theme.of(context).colorScheme.error),
            title: Text('Удалить контакт',
                style:
                    TextStyle(color: Theme.of(context).colorScheme.error)),
            onTap: _deleteContact,
          ),
        ],
      ),
    );
  }
}
