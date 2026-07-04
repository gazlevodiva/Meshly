import 'dart:async';

import 'package:flutter/material.dart';
import 'package:meshly/models/contact.dart';
import 'package:meshly/services/contact_store.dart';
import 'package:meshly/services/qr_service.dart';
import 'package:meshly/theme/app_theme.dart';
import 'package:meshly/widgets/section_card.dart';
import 'package:meshly/widgets/tab_header.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

class AddContactScreen extends StatefulWidget {
  const AddContactScreen({super.key});

  @override
  State<AddContactScreen> createState() => _AddContactScreenState();
}

class _AddContactScreenState extends State<AddContactScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  final ContactStore _store = ContactStore.instance;
  bool _scanned = false;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  void _onQrDetected(BarcodeCapture capture) {
    if (_scanned) return;
    final raw = capture.barcodes.firstOrNull?.rawValue;
    if (raw == null) return;
    _scanned = true;
    unawaited(_handleScannedData(raw));
  }

  Future<void> _handleScannedData(String raw) async {
    final type = QrService.detectType(raw);
    if (type == QrType.contact) {
      final data = QrService.decodeContact(raw);
      if (data != null) await _addContact(data);
    } else if (type == QrType.channel) {
      final data = QrService.decodeChannel(raw);
      if (data != null) await _addChannel(data);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Нераспознанный QR-код')),
        );
        setState(() => _scanned = false);
      }
    }
  }

  Future<void> _addContact(ContactQrData data) async {
    final contact = Contact(
      nodeId: data.nodeId,
      displayName: data.displayName,
      avatarEmoji: data.avatarEmoji,
    );

    // Показываем подтверждение с возможностью задать эмодзи
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _ConfirmContactDialog(contact: contact),
    );

    if (confirmed == true) {
      await _store.saveContact(contact);
      if (mounted) {
        Navigator.pop(context, contact);
      }
    } else {
      setState(() => _scanned = false);
    }
  }

  Future<void> _addChannel(ChannelQrData data) async {
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _ConfirmChannelDialog(data: data),
    );

    if (confirmed == true) {
      await _store.createChannel(
        name: data.name,
        slotIndex: data.slotIndex,
        avatarEmoji: data.avatarEmoji,
        psk: data.psk,
      );
      if (mounted) Navigator.pop(context);
    } else {
      setState(() => _scanned = false);
    }
  }

  Widget _buildScannerTab(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.s16,
        AppSpacing.s16,
        AppSpacing.s16,
        AppSpacing.s32,
      ),
      child: Column(
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.cardLarge),
              child: _scanned
                  ? const Center(child: CircularProgressIndicator())
                  : MobileScanner(
                      onDetect: _onQrDetected,
                      errorBuilder: (_, error) => Center(
                        child: Text('Ошибка камеры: $error',
                            textAlign: TextAlign.center),
                      ),
                    ),
            ),
          ),
          const SizedBox(height: AppSpacing.s12),
          Text(
            'Наведите камеру на QR-код контакта или канала',
            textAlign: TextAlign.center,
            style: AppTextStyles.subtitle(context),
          ),
        ],
      ),
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
        title: const Text('Добавить'),
      ),
      body: TabGradientBackground(
        child: Column(
          children: [
            SizedBox(height: topInset + AppSpacing.s8),
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: AppSpacing.s16),
              child: TabBar(
                controller: _tabs,
                tabs: const [
                  Tab(icon: Icon(Icons.qr_code_scanner), text: 'Скан QR'),
                  Tab(icon: Icon(Icons.keyboard), text: 'Вручную'),
                ],
              ),
            ),
            Expanded(
              child: TabBarView(
                controller: _tabs,
                children: [
                  // Tab 1: QR Scanner
                  _buildScannerTab(context),
                  // Tab 2: Manual input
                  _ManualInputTab(onAdd: (contact) async {
                    await _store.saveContact(contact);
                    if (context.mounted) Navigator.pop(context, contact);
                  }),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Диалог подтверждения контакта ────────────────────────────

class _ConfirmContactDialog extends StatefulWidget {
  const _ConfirmContactDialog({required this.contact});

  final Contact contact;

  @override
  State<_ConfirmContactDialog> createState() => _ConfirmContactDialogState();
}

class _ConfirmContactDialogState extends State<_ConfirmContactDialog> {
  late final TextEditingController _name;
  late String _emoji;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.contact.displayName);
    _emoji = widget.contact.avatarEmoji ?? '😊';
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  static const _emojis = [
    '😊','👩','👨','👵','👴','👦','👧',
    '🐕','🐈','🏕️','🏠','❤️','⭐','🔥',
  ];

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Добавить контакт?'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(widget.contact.nodeId, style: AppTextStyles.monoCaption(context)),
          const SizedBox(height: AppSpacing.s16),
          TextField(
            controller: _name,
            decoration: const InputDecoration(labelText: 'Имя'),
          ),
          const SizedBox(height: AppSpacing.s12),
          Wrap(
            spacing: AppSpacing.s6,
            children: _emojis.map((e) => GestureDetector(
              onTap: () => setState(() => _emoji = e),
              child: Container(
                width: AppSizes.emojiCellSmall, height: AppSizes.emojiCellSmall,
                decoration: BoxDecoration(
                  color: e == _emoji
                      ? Theme.of(context).colorScheme.primaryContainer
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(AppRadius.chipSmall),
                ),
                child: Center(child: Text(e,
                    style: const TextStyle(fontSize: AppSizes.emojiSmall))),
              ),
            )).toList(),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Отмена'),
        ),
        FilledButton(
          onPressed: () {
            widget.contact.displayName =
                _name.text.trim().isNotEmpty ? _name.text.trim() : widget.contact.displayName;
            widget.contact.avatarEmoji = _emoji;
            Navigator.pop(context, true);
          },
          child: const Text('Добавить'),
        ),
      ],
    );
  }
}

// ── Диалог подтверждения канала ───────────────────────────────

class _ConfirmChannelDialog extends StatelessWidget {
  const _ConfirmChannelDialog({required this.data});

  final ChannelQrData data;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Добавить канал?'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('${data.avatarEmoji ?? '📡'} ${data.name}',
              style: AppTextStyles.title),
          const SizedBox(height: AppSpacing.s4),
          Text('Слот ${data.slotIndex}', style: AppTextStyles.secondary(context)),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Отмена'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, true),
          child: const Text('Добавить'),
        ),
      ],
    );
  }
}

// ── Ручной ввод ───────────────────────────────────────────────

class _ManualInputTab extends StatefulWidget {
  const _ManualInputTab({required this.onAdd});

  final Future<void> Function(Contact) onAdd;

  @override
  State<_ManualInputTab> createState() => _ManualInputTabState();
}

class _ManualInputTabState extends State<_ManualInputTab> {
  final _nodeIdCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();
  String _emoji = '😊';
  bool _loading = false;

  static const _emojis = [
    '😊','👩','👨','👵','👴','👦','👧',
    '🐕','🐈','🏕️','🏠','❤️','⭐','🔥',
  ];

  bool get _valid {
    final id = _nodeIdCtrl.text.trim();
    return (id.startsWith('!') && id.length == 9) &&
        _nameCtrl.text.trim().isNotEmpty;
  }

  Future<void> _save() async {
    if (!_valid) return;
    setState(() => _loading = true);
    final contact = Contact(
      nodeId: _nodeIdCtrl.text.trim(),
      displayName: _nameCtrl.text.trim(),
      avatarEmoji: _emoji,
    );
    await widget.onAdd(contact);
  }

  @override
  void dispose() {
    _nodeIdCtrl.dispose();
    _nameCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.s16,
        AppSpacing.s16,
        AppSpacing.s16,
        AppSpacing.s32,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Данные контакта
          SectionCard(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.s16),
              child: Column(
                children: [
                  TextField(
                    controller: _nodeIdCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Node ID',
                      hintText: '!1f8e42c9',
                      prefixText: '',
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                  const SizedBox(height: AppSpacing.s16),
                  TextField(
                    controller: _nameCtrl,
                    decoration: const InputDecoration(labelText: 'Имя'),
                    onChanged: (_) => setState(() {}),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.s12),

          // Эмодзи
          SectionCard(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.s16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Эмодзи', style: AppTextStyles.subtitle(context)),
                  const SizedBox(height: AppSpacing.s8),
                  Wrap(
                    spacing: AppSpacing.s8,
                    runSpacing: AppSpacing.s8,
                    children: _emojis.map((e) => GestureDetector(
                      onTap: () => setState(() => _emoji = e),
                      child: Container(
                        width: AppSizes.emojiCell, height: AppSizes.emojiCell,
                        decoration: BoxDecoration(
                          color: e == _emoji
                              ? Theme.of(context).colorScheme.primaryContainer
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(AppRadius.chip),
                        ),
                        child: Center(child: Text(e,
                            style: const TextStyle(
                                fontSize: AppSizes.emojiMedium))),
                      ),
                    )).toList(),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.s24),

          FilledButton(
            onPressed: _valid && !_loading ? _save : null,
            child: _loading
                ? Center(
                    child: SizedBox(
                      width: AppSizes.spinner, height: AppSizes.spinner,
                      child: CircularProgressIndicator(
                          strokeWidth: AppSizes.spinnerStroke,
                          color: context.appColors.onAccent),
                    ),
                  )
                : const Text('Добавить контакт'),
          ),
        ],
      ),
    );
  }
}
