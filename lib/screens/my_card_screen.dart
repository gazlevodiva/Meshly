import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:meshly/l10n/l10n.dart';
import 'package:meshly/models/contact.dart';
import 'package:meshly/services/contact_store.dart';
import 'package:meshly/services/crypto_service.dart';
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

  // Our public key (for the QR), once identity has been initialized.
  // ensureIdentity() runs in initState; until it completes this stays null,
  // in which case the QR simply carries no key (better no key than a
  // crash).
  Uint8List? _myPublicKey;

  Contact get _myContact {
    final existing = _store.contactByNodeId(_nodeId);
    final base =
        existing ??
        Contact(
          nodeId: _nodeId,
          displayName: context.l10n.defaultMyName,
          avatarEmoji: _emoji,
        );
    if (_myPublicKey == null) return base;
    return Contact(
      nodeId: base.nodeId,
      displayName: base.displayName,
      avatarEmoji: base.avatarEmoji,
      publicKey: _myPublicKey,
      addedAt: base.addedAt,
    );
  }

  String get _qrData => QrService.encodeContact(_myContact, myNodeId: _nodeId);

  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    unawaited(_loadPublicKey());
  }

  Future<void> _loadPublicKey() async {
    try {
      await CryptoService.instance.ensureIdentity();
      if (!mounted) return;
      setState(() => _myPublicKey = CryptoService.instance.myPublicKey());
    } on Exception {
      // Identity unavailable (e.g. secure storage failure) — QR simply
      // won't carry a key; skip rather than crash.
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // _myContact needs Localizations from the tree (default display name),
    // so the one-time init lives here instead of initState.
    if (_initialized) return;
    _initialized = true;
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
    if (!mounted) return;
    if (picked != null) {
      setState(() => _emoji = picked);
      final c = Contact(
        nodeId: _nodeId,
        displayName: _nameController.text.trim().isNotEmpty
            ? _nameController.text.trim()
            : context.l10n.defaultMyName,
        avatarEmoji: picked,
      );
      await _store.saveContact(c);
    }
  }

  void _copyLink() {
    unawaited(Clipboard.setData(ClipboardData(text: _qrData)));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(context.l10n.linkCopied)),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final contact = _myContact;
    return Column(
      children: [
        // Emoji avatar (tap — emoji picker)
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
                child: Icon(
                  Icons.edit,
                  size: AppIconSizes.banner,
                  color: context.appColors.onAccent,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.s12),

        // Name
        if (_editingName)
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _nameController,
                  autofocus: true,
                  decoration: InputDecoration(
                    hintText: context.l10n.yourNameHint,
                  ),
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
        title: Text(context.l10n.myContact),
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
            // Avatar + name + Node ID
            _buildHeader(context),
            const SizedBox(height: AppSpacing.s24),

            // QR + link
            SectionCard(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.s16),
                child: Column(
                  children: [
                    Text(
                      context.l10n.askScanQr,
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
                        label: Text(context.l10n.copyLinkButton),
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
    '😊',
    '👩',
    '👨',
    '👵',
    '👴',
    '👦',
    '👧',
    '🐕',
    '🐈',
    '🐇',
    '🦊',
    '🐻',
    '🦁',
    '🐯',
    '🏕️',
    '🏠',
    '🏔️',
    '🌲',
    '⛵',
    '🚀',
    '🎯',
    '❤️',
    '⭐',
    '🔥',
    '💎',
    '🎸',
    '📡',
    '🛡️',
  ];

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(context.l10n.chooseEmojiTitle),
      content: SizedBox(
        width: AppSizes.emojiDialogWidth,
        child: Wrap(
          spacing: AppSpacing.s8,
          runSpacing: AppSpacing.s8,
          children: _emojis
              .map(
                (e) => GestureDetector(
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
                      child: Text(
                        e,
                        style: const TextStyle(fontSize: AppSizes.emojiMedium),
                      ),
                    ),
                  ),
                ),
              )
              .toList(),
        ),
      ),
    );
  }
}
