import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:meshly/models/contact.dart';
import 'package:meshly/services/contact_store.dart';
import 'package:meshly/services/mesh_service.dart';
import 'package:meshly/services/qr_service.dart';
import 'package:meshly/theme/app_theme.dart';
import 'package:meshly/widgets/qr_card.dart';
import 'package:meshly/widgets/section_card.dart';
import 'package:meshly/widgets/tab_header.dart';

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

  Widget _buildHeader(BuildContext context) {
    final contact = _myContact;
    return Column(
      children: [
        // Аватар-эмодзи (тап — выбор эмодзи)
        GestureDetector(
          onTap: _pickEmoji,
          child: Stack(
            alignment: Alignment.bottomRight,
            children: [
              Container(
                width: AppSizes.avatarLarge,
                height: AppSizes.avatarLarge,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primaryContainer,
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    _emoji,
                    style: const TextStyle(fontSize: AppSizes.emojiAvatar),
                  ),
                ),
              ),
              Container(
                width: AppSizes.avatarEditBadge,
                height: AppSizes.avatarEditBadge,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary,
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.edit,
                    size: AppIconSizes.banner,
                    color: context.appColors.onAccent),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.s12),

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
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                contact.displayName,
                style: AppTextStyles.headline,
              ),
              IconButton(
                icon: const Icon(Icons.edit, size: AppIconSizes.info),
                onPressed: () => setState(() => _editingName = true),
              ),
            ],
          ),

        // Node ID
        Text(
          _nodeId,
          style: AppTextStyles.monoCaption(context),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final topInset = MediaQuery.paddingOf(context).top + kToolbarHeight;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: const Text('Мой контакт'),
      ),
      body: TabGradientBackground(
        child: ListView(
          padding: EdgeInsets.fromLTRB(
            AppSpacing.s16,
            topInset + AppSpacing.s8,
            AppSpacing.s16,
            AppSpacing.s32,
          ),
          children: [
            // Аватар + имя + Node ID
            _buildHeader(context),
            const SizedBox(height: AppSpacing.s24),

            // QR + ссылка
            SectionCard(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.s16),
                child: Column(
                  children: [
                    Text(
                      'Попросите собеседника отсканировать этот QR\n'
                      'или поделитесь ссылкой',
                      textAlign: TextAlign.center,
                      style: AppTextStyles.subtitle(context),
                    ),
                    const SizedBox(height: AppSpacing.s16),
                    QrCard(data: _qrData, size: AppSizes.qrMedium),
                    const SizedBox(height: AppSpacing.s16),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: _copyLink,
                        icon: const Icon(Icons.link),
                        label: const Text('Скопировать ссылку'),
                      ),
                    ),
                  ],
                ),
              ),
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
        width: AppSizes.emojiDialogWidth,
        child: Wrap(
          spacing: AppSpacing.s8,
          runSpacing: AppSpacing.s8,
          children: _emojis.map((e) => GestureDetector(
            onTap: () => Navigator.pop(context, e),
            child: Container(
              width: AppSizes.emojiCell,
              height: AppSizes.emojiCell,
              decoration: BoxDecoration(
                color: e == current
                    ? Theme.of(context).colorScheme.primaryContainer
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(AppRadius.chip),
              ),
              child: Center(
                child: Text(e,
                    style: const TextStyle(fontSize: AppSizes.emojiMedium)),
              ),
            ),
          )).toList(),
        ),
      ),
    );
  }
}
