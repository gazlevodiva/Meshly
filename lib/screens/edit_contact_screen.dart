import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:meshly/l10n/l10n.dart';
import 'package:meshly/models/contact.dart';
import 'package:meshly/services/contact_store.dart';
import 'package:meshly/services/mesh_service.dart';
import 'package:meshly/services/notification_settings.dart';
import 'package:meshly/services/qr_service.dart';
import 'package:meshly/theme/app_theme.dart';
import 'package:meshly/utils/date_format.dart';
import 'package:meshly/widgets/qr_card.dart';
import 'package:meshly/widgets/section_card.dart';
import 'package:meshly/widgets/sheet_drag_handle.dart';
import 'package:meshly/widgets/tab_header.dart';

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
              context.l10n.shareContact,
              style: Theme.of(ctx).textTheme.titleLarge,
            ),
            const SizedBox(height: AppSpacing.s20),
            QrCard(data: qrUrl),
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
                label: Text(context.l10n.copyLinkButton),
                onPressed: () async {
                  await Clipboard.setData(ClipboardData(text: qrUrl));
                  if (!ctx.mounted) return;
                  Navigator.pop(ctx);
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(context.l10n.linkCopied)),
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
        title: Text(ctx.l10n.blockNodeQuestion),
        content: Text(ctx.l10n.blockNodeWarning),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(ctx.l10n.cancel),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.error,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(ctx.l10n.blockAction),
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
        title: Text(ctx.l10n.deleteContactQuestion),
        content: Text(
            ctx.l10n.deleteContactWarning(widget.contact.displayName)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(ctx.l10n.cancel),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.error,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(ctx.l10n.deleteAction),
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
    unawaited(
      showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        shape: AppShapes.bottomSheet,
        // Controllers live inside the sheet's own State (disposed only after
        // the closing animation finishes) — disposing them from whenComplete
        // crashed the still-animating TextFields.
        builder: (_) => _EditNameEmojiSheet(
          initialName: _name,
          initialEmoji: _selectedEmoji,
          presets: _emojis,
          onNameChanged: (v) => setState(() => _name = v),
          onEmojiChanged: (v) => setState(() => _selectedEmoji = v),
        ),
      ),
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
            Text(ctx.l10n.additionalInfoTitle,
                style: Theme.of(ctx).textTheme.titleLarge),
            const SizedBox(height: AppSpacing.s20),
            _InfoRow(label: ctx.l10n.deviceIdLabel, value: nodeId),
            const SizedBox(height: AppSpacing.s12),
            _InfoRow(
              label: ctx.l10n.addedLabel,
              value: formatAdded(ctx.l10n, widget.contact.addedAt),
            ),
            if (lastHeard != null) ...[
              const SizedBox(height: AppSpacing.s12),
              _InfoRow(
                label: ctx.l10n.lastHeardLabel,
                value: formatLastHeard(ctx.l10n, lastHeard),
              ),
            ],
          ],
        ),
      ),
    ));
  }

  Widget _buildHeader(BuildContext context) {
    final online = widget.meshService.isOnline(widget.contact.nodeId);
    return Column(
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
        Text(_name, style: AppTextStyles.headline),
        const SizedBox(height: AppSpacing.s4),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: AppSizes.statusDotSmall,
              height: AppSizes.statusDotSmall,
              decoration: BoxDecoration(
                color: online
                    ? context.appColors.online
                    : context.appColors.offline,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: AppSpacing.s6),
            Text(
              online ? context.l10n.online : context.l10n.offline,
              style: AppTextStyles.body.copyWith(
                color: online
                    ? context.appColors.online
                    : context.appColors.offline,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.s4),
        Text(
          context.l10n
              .addedOn(formatAdded(context.l10n, widget.contact.addedAt)),
          style: AppTextStyles.caption(context),
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
        actions: [
          TextButton(
            onPressed: _name.trim().isNotEmpty && !_saving ? _save : null,
            child: Text(context.l10n.saveButton),
          ),
        ],
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
            // Avatar + name + status (tap opens the name/emoji editor)
            _buildHeader(context),
            const SizedBox(height: AppSpacing.s24),

            // Notifications
            SectionCard(
              child: ListenableBuilder(
                listenable: NotificationSettings.instance,
                builder: (context, _) {
                  final convId = 'dm_${widget.contact.nodeId}';
                  final settings = NotificationSettings.instance;
                  final muted = settings.isMuted(convId);
                  return SwitchListTile(
                    secondary: Icon(muted
                        ? Icons.notifications_off_outlined
                        : Icons.notifications_outlined),
                    title: Text(context.l10n.notificationsTitle),
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
            ),
            const SizedBox(height: AppSpacing.s12),

            // Actions
            SectionCard(
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.share),
                    title: Text(context.l10n.shareContact),
                    onTap: _shareContact,
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.info_outline),
                    title: Text(context.l10n.additionalInfoTitle),
                    subtitle: Text(context.l10n.additionalInfoSubtitle),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: _showAdditionalInfo,
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.s12),

            // Danger zone
            SectionCard(
              child: Column(
                children: [
                  ListTile(
                    leading:
                        Icon(Icons.block, color: context.appColors.warning),
                    title: Text(
                      context.l10n.blockAction,
                      style: TextStyle(color: context.appColors.warning),
                    ),
                    onTap: _blockNode,
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: Icon(Icons.delete,
                        color: Theme.of(context).colorScheme.error),
                    title: Text(
                      context.l10n.deleteContactAction,
                      style: TextStyle(
                          color: Theme.of(context).colorScheme.error),
                    ),
                    onTap: _deleteContact,
                  ),
                ],
              ),
            ),
          ],
        ),
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
                  color: context.appColors.textSecondary,
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

/// Bottom sheet for editing the contact's name and emoji.
///
/// Owns its [TextEditingController]s so they are disposed by the framework
/// only after the sheet's closing animation completes.
class _EditNameEmojiSheet extends StatefulWidget {
  const _EditNameEmojiSheet({
    required this.initialName,
    required this.initialEmoji,
    required this.presets,
    required this.onNameChanged,
    required this.onEmojiChanged,
  });

  final String initialName;
  final String? initialEmoji;
  final List<String> presets;
  final ValueChanged<String> onNameChanged;
  final ValueChanged<String> onEmojiChanged;

  @override
  State<_EditNameEmojiSheet> createState() => _EditNameEmojiSheetState();
}

class _EditNameEmojiSheetState extends State<_EditNameEmojiSheet> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _emojiCtrl;
  String? _emoji;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.initialName);
    _emojiCtrl = TextEditingController(text: widget.initialEmoji);
    _emoji = widget.initialEmoji;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emojiCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.s24,
        AppSpacing.s20,
        AppSpacing.s24,
        MediaQuery.of(context).viewInsets.bottom + AppSpacing.s24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SheetDragHandle(bottomMargin: AppSpacing.s16),
          Text(
            context.l10n.editSheetTitle,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: AppSpacing.s16),
          TextField(
            controller: _nameCtrl,
            decoration: InputDecoration(
              labelText: context.l10n.nameLabel,
              border: const OutlineInputBorder(),
            ),
            onChanged: (v) {
              widget.onNameChanged(v);
              setState(() {}); // refreshes the button's disabled state
            },
          ),
          const SizedBox(height: AppSpacing.s16),
          TextField(
            controller: _emojiCtrl,
            decoration: InputDecoration(
              hintText: context.l10n.emojiInputHint,
              border: const OutlineInputBorder(),
              labelText: context.l10n.iconLabel,
            ),
            maxLength: 2,
            onChanged: (v) {
              if (v.isNotEmpty) {
                widget.onEmojiChanged(v);
                setState(() => _emoji = v);
              }
            },
          ),
          const SizedBox(height: AppSpacing.s8),
          Wrap(
            spacing: AppSpacing.s10,
            runSpacing: AppSpacing.s10,
            children: widget.presets.map((e) {
              final isSelected = e == _emoji;
              return GestureDetector(
                onTap: () {
                  _emojiCtrl.text = e;
                  widget.onEmojiChanged(e);
                  setState(() => _emoji = e);
                },
                child: Container(
                  width: AppSizes.emojiCell,
                  height: AppSizes.emojiCell,
                  decoration: BoxDecoration(
                    color: isSelected
                        ? Theme.of(context).colorScheme.primaryContainer
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(AppRadius.chip),
                  ),
                  child: Center(
                    child: Text(
                      e,
                      style:
                          const TextStyle(fontSize: AppSizes.emojiMedium),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: AppSpacing.s16),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _nameCtrl.text.trim().isEmpty
                  ? null
                  : () => Navigator.pop(context),
              child: Text(context.l10n.doneButton),
            ),
          ),
        ],
      ),
    );
  }
}
