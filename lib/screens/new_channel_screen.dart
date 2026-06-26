import 'package:flutter/material.dart';
import '../services/channel_manager.dart';
import '../services/mesh_service.dart';

class NewChannelScreen extends StatefulWidget {
  final MeshService meshService;
  const NewChannelScreen({super.key, required this.meshService});

  @override
  State<NewChannelScreen> createState() => _NewChannelScreenState();
}

class _NewChannelScreenState extends State<NewChannelScreen> {
  final _nameCtrl = TextEditingController();
  String _emoji = '📡';
  bool _loading = false;

  static const _emojis = [
    '📡', '🏕️', '🏠', '🏔️', '⛵', '🚀', '🎯',
    '🔥', '❤️', '⭐', '💎', '🎸', '🛡️', '🌲',
    '👨‍👩‍👧', '👨‍👩‍👦', '🐕', '🐈', '🎉', '📻', '🗺️',
  ];

  bool get _valid => _nameCtrl.text.trim().isNotEmpty;

  Future<void> _create() async {
    if (!_valid) return;
    setState(() => _loading = true);

    final ch = await ChannelManager.instance.create(
      name: _nameCtrl.text.trim(),
      avatarEmoji: _emoji,
      meshService: widget.meshService,
    );

    if (!mounted) return;
    setState(() => _loading = false);

    if (ch == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Все слоты заняты (максимум 7 каналов)')),
      );
      return;
    }

    Navigator.pop(context, ch);
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Новый канал')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Эмодзи + название
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                GestureDetector(
                  onTap: _pickEmoji,
                  child: CircleAvatar(
                    radius: 28,
                    backgroundColor:
                        Theme.of(context).colorScheme.primaryContainer,
                    child: Text(_emoji, style: const TextStyle(fontSize: 28)),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: TextField(
                    controller: _nameCtrl,
                    autofocus: true,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: const InputDecoration(
                      labelText: 'Название канала',
                      hintText: 'Горная группа',
                    ),
                    onChanged: (_) => setState(() {}),
                    onSubmitted: (_) => _create(),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 32),

            // Сетка эмодзи
            const Text('Иконка канала',
                style: TextStyle(color: Colors.grey, fontSize: 13)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _emojis.map((e) => GestureDetector(
                onTap: () => setState(() => _emoji = e),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: e == _emoji
                        ? Theme.of(context).colorScheme.primaryContainer
                        : Theme.of(context).colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(
                    child: Text(e, style: const TextStyle(fontSize: 26)),
                  ),
                ),
              )).toList(),
            ),
            const SizedBox(height: 40),

            // Инфо
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.info_outline, size: 18, color: Colors.grey),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Канал создастся с уникальным ключом шифрования. '
                      'Поделитесь QR-кодом канала с теми кого хотите добавить.',
                      style: TextStyle(fontSize: 13, color: Colors.grey),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),

            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _valid && !_loading ? _create : null,
                icon: _loading
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.add),
                label: const Text('Создать канал'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickEmoji() async {
    final picked = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Выберите иконку'),
        content: SizedBox(
          width: 280,
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _emojis.map((e) => GestureDetector(
              onTap: () => Navigator.pop(context, e),
              child: SizedBox(
                width: 44,
                height: 44,
                child: Center(
                  child: Text(e, style: const TextStyle(fontSize: 28)),
                ),
              ),
            )).toList(),
          ),
        ),
      ),
    );
    if (picked != null) setState(() => _emoji = picked);
  }
}
