import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:meshly/models/contact.dart';
import 'package:meshly/services/contact_store.dart';
import 'package:meshly/services/mesh_service.dart';
import 'package:meshly/services/notification_settings.dart';
import 'package:meshly/services/qr_service.dart';
import 'package:meshly/theme/app_theme.dart';
import 'package:meshly/utils/date_format_ru.dart';
import 'package:meshly/widgets/sheet_drag_handle.dart';
import 'package:qr_flutter/qr_flutter.dart';

class EditContactScreen extends StatefulWidget {
  const EditContactScreen({
    required this.contact,
    required this.meshService,
    super.key,
  });

  final Contact contact;
  final MeshService meshService;

  @override
  State<EditContactScreen> createState() => _EditContactScreenState();
}

class _EditContactScreenState extends State<EditContactScreen> {
  final ContactStore _store = ContactStore.instance;
  late String _name;
  String? _selectedEmoji;
  bool _saving = false;

  static const _emojis = [
    '😊', '👩', '👨', '👵', '👴', '👦', '👧',
    '🐕', '🐈', '🏕️', '🏠', '❤️', '⭐', '🔥',
  ];

  @override
  void initState() {
    super.initState();
    _name = widget.contact.displayName;
    _selectedEmoji = widget.contact.avatarEmoji ?? '😊';
  }

  Future<void> _save() async {
    if (_name.trim().isEmpty) return;
    setState(() => _saving = true);
    try {
      widget.contact.displayName = _name.trim();
      widget.contact.avatarEmoji = _selectedEmoji;
      await _store.saveContact(widget.contact);
      if (mounted) Navigator.pop(context, 'saved');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _shareContact() async {
    final qrUrl = QrService.encodeContact(widget.contact);
    if (!mounted) return;
    unawaited(showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: AppShapes.bottomSheet,
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(
            AppSpacing.s24, AppSpacing.s20, AppSpacing.s24, AppSpacing.s40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SheetDragHandle(),
            Text(
              'Поделиться контактом',
              style: Theme.of(ctx).textTheme.titleLarge,
            ),
            const SizedBox(height: AppSpacing.s20),
            QrImageView(data: qrUrl, size: AppSizes.qrLarge),
            const SizedBox(height: AppSpacing.s16),
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.s12, vertical: AppSpacing.s8),
              decoration: BoxDecoration(
                color: Theme.of(ctx).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(AppRadius.chip),
              ),
              child: Text(
                qrUrl,
                style: AppTextStyles.monoLabel,
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: AppSpacing.s16),
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
    ));
  }

  Future<void> _blockNode() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Заблокировать?'),
        content: const Text(
          'Нода больше не будет отображаться в мессенджере. '
          'Сообщения от неё будут игнорироваться.',
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
            child: const Text('Заблокировать'),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      await _store.blockNode(widget.contact.nodeId);
      if (mounted) Navigator.pop(context, 'deleted');
    }
  }

  Future<void> _deleteContact() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Удалить контакт?'),
        content: Text('Контакт «${widget.contact.displayName}» будет удалён.'),
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

  void _openEmojiAndNameEditor() {
    final emojiCtrl = TextEditingController(text: _selectedEmoji);
    final nameCtrl = TextEditingController(text: _name);

    unawaited(
      showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        shape: AppShapes.bottomSheet,
        builder: (ctx) => Padding(
          padding: EdgeInsets.fromLTRB(
            AppSpacing.s24,
            AppSpacing.s20,
            AppSpacing.s24,
            MediaQuery.of(ctx).viewInsets.bottom + AppSpacing.s24,
          ),
          child: StatefulBuilder(
            builder: (ctx, setSheetState) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SheetDragHandle(bottomMargin: AppSpacing.s16),
                  Text(
                    'Редактировать',
                    style: Theme.of(ctx).textTheme.titleMedium,
                  ),
                  const SizedBox(height: AppSpacing.s16),
                  TextField(
                    controller: nameCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Имя',
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (v) {
                      setState(() => _name = v);
                      setSheetState(() {}); // обновляет disabled-состояние кнопки
                    },
                  ),
                  const SizedBox(height: AppSpacing.s16),
                  TextField(
                    controller: emojiCtrl,
                    decoration: const InputDecoration(
                      hintText: 'Введите любой эмодзи...',
                      border: OutlineInputBorder(),
                      labelText: 'Иконка',
                    ),
                    maxLength: 2,
                    onChanged: (v) {
                      if (v.isNotEmpty) {
                        setState(() => _selectedEmoji = v);
                        setSheetState(() {}); // обновляет подсветку пресетов
                      }
                    },
                  ),
                  const SizedBox(height: AppSpacing.s8),
                  Wrap(
                    spacing: AppSpacing.s10,
                    runSpacing: AppSpacing.s10,
                    children: _emojis.map((e) {
                      final isSelected = e == _selectedEmoji;
                      return GestureDetector(
                        onTap: () {
                          emojiCtrl.text = e;
                          setState(() => _selectedEmoji = e);
                          setSheetState(() {});
                        },
                        child: Container(
                          width: AppSizes.emojiCell,
                          height: AppSizes.emojiCell,
                          decoration: BoxDecoration(
                            color: isSelected
                                ? Theme.of(ctx).colorScheme.primaryContainer
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(AppRadius.chip),
                          ),
                          child: Center(
                            child: Text(e,
                                style: const TextStyle(
                                    fontSize: AppSizes.emojiMedium)),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: AppSpacing.s16),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: nameCtrl.text.trim().isEmpty
                          ? null
                          : () => Navigator.pop(ctx),
                      child: const Text('Готово'),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ).whenComplete(() {
        emojiCtrl.dispose();
        nameCtrl.dispose();
      }),
    );
  }

  void _showAdditionalInfo() {
    final nodeId = widget.contact.nodeId;
    final lastHeard = widget.meshService.lastHeardFor(nodeId);

    unawaited(showModalBottomSheet<void>(
      context: context,
      shape: AppShapes.bottomSheet,
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(
            AppSpacing.s24, AppSpacing.s20, AppSpacing.s24, AppSpacing.s40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SheetDragHandle(),
            Text('Дополнительно', style: Theme.of(ctx).textTheme.titleLarge),
            const SizedBox(height: AppSpacing.s20),
            _InfoRow(label: 'Node ID', value: nodeId),
            const SizedBox(height: AppSpacing.s12),
            _InfoRow(
              label: 'Добавлен',
              value: formatAddedRu(widget.contact.addedAt),
            ),
            if (lastHeard != null) ...[
              const SizedBox(height: AppSpacing.s12),
              _InfoRow(
                label: 'Последний раз в сети',
                value: formatLastHeardRu(lastHeard),
              ),
            ],
          ],
        ),
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final online = widget.meshService.isOnline(widget.contact.nodeId);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Редактировать'),
        actions: [
          TextButton(
            onPressed: _name.trim().isNotEmpty && !_saving ? _save : null,
            child: const Text('Сохранить'),
          ),
        ],
      ),
      body: ListView(
        children: [
          // Avatar + display info (tap to edit)
          Padding(
            padding: const EdgeInsets.symmetric(
                vertical: AppSpacing.s28, horizontal: AppSpacing.s24),
            child: Column(
              children: [
                GestureDetector(
                  onTap: _openEmojiAndNameEditor,
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
                            _selectedEmoji ?? '😊',
                            style:
                                const TextStyle(fontSize: AppSizes.emojiAvatar),
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
                        child: const Icon(Icons.edit,
                            size: AppIconSizes.banner,
                            color: AppColors.onAccent),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.s12),
                Text(
                  _name,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: AppSpacing.s4),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: AppSizes.statusDotSmall,
                      height: AppSizes.statusDotSmall,
                      decoration: BoxDecoration(
                        color: online ? AppColors.online : AppColors.offline,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.s6),
                    Text(
                      online ? 'В сети' : 'Не в сети',
                      style: AppTextStyles.body.copyWith(
                        color: online ? AppColors.online : AppColors.offline,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.s4),
                Text(
                  'Добавлен ${formatAddedRu(widget.contact.addedAt)}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                ),
              ],
            ),
          ),

          const Divider(height: 1),

          // Notifications
          ListenableBuilder(
            listenable: NotificationSettings.instance,
            builder: (context, _) {
              final convId = 'dm_${widget.contact.nodeId}';
              final settings = NotificationSettings.instance;
              final muted = settings.isMuted(convId);
              return SwitchListTile(
                secondary: Icon(muted
                    ? Icons.notifications_off_outlined
                    : Icons.notifications_outlined),
                title: const Text('Уведомления'),
                value: !muted,
                onChanged: (v) async {
                  if (v) {
                    await settings.unmuteConversation(convId);
                  } else {
                    await settings.muteConversation(convId);
                  }
                },
              );
            },
          ),

          const Divider(height: 1),

          ListTile(
            leading: const Icon(Icons.share),
            title: const Text('Поделиться контактом'),
            onTap: _shareContact,
          ),

          const Divider(height: 1),

          ListTile(
            leading: const Icon(Icons.info_outline),
            title: const Text('Дополнительно'),
            subtitle: const Text('Node ID, время последнего соединения и другая информация'),
            trailing: const Icon(Icons.chevron_right),
            onTap: _showAdditionalInfo,
          ),

          const Divider(height: 1),

          ListTile(
            leading: const Icon(Icons.block, color: AppColors.warning),
            title: const Text(
              'Заблокировать',
              style: TextStyle(color: AppColors.warning),
            ),
            onTap: _blockNode,
          ),

          const Divider(height: 1),

          ListTile(
            leading: Icon(Icons.delete, color: Theme.of(context).colorScheme.error),
            title: Text(
              'Удалить контакт',
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
            onTap: _deleteContact,
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 140,
          child: Text(
            label,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.textSecondary,
                ),
          ),
        ),
        Expanded(
          child: Text(value, style: Theme.of(context).textTheme.bodyMedium),
        ),
      ],
    );
  }
}
