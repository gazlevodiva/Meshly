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

  Contact? get _existingContact => _store.contactByNodeId(_nodeId);

  /// Whether a name has actually been set for this device. False until the
  /// first successful [_saveName] — [_existingContact] doesn't exist before
  /// that, since nothing ever persists an empty name (see [_saveName]).
  /// Gates the QR/share section below: showing a code before a name is set
  /// would encode whatever placeholder we invented, and the person who
  /// scans it would save that placeholder as this device's name — see the
  /// sprint brief's "Я" leak.
  bool get _hasName => _existingContact != null;

  Contact get _myContact {
    final existing = _existingContact;
    // No placeholder name here: when nothing is set yet, this stays empty
    // and [_hasName] keeps the QR/share section (which is what reads this)
    // from ever being shown, so the empty name is never encoded or seen.
    final base =
        existing ??
        Contact(nodeId: _nodeId, displayName: '', avatarEmoji: _emoji);
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
    if (_initialized) return;
    _initialized = true;
    final existing = _existingContact;
    _nameController.text = existing?.displayName ?? '';
    _emoji = existing?.avatarEmoji ?? '😊';
    // No name set yet — open the field immediately instead of showing a
    // blank headline with nothing to explain it.
    _editingName = existing == null;
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _saveName() async {
    final name = sanitizeDisplayName(_nameController.text);
    if (name.isEmpty) return;
    _nameController.text = name;
    setState(() => _editingName = false);
    final existing = _existingContact;
    final c = Contact(
      nodeId: _nodeId,
      displayName: name,
      avatarEmoji: _emoji,
      publicKey: existing?.publicKey,
      addedAt: existing?.addedAt,
    );
    await _store.saveContact(c);
    setState(() {});
  }

  Future<void> _pickEmoji() async {
    final picked = await showDialog<String>(
      context: context,
      builder: (_) => _EmojiPickerDialog(current: _emoji),
    );
    if (!mounted) return;
    if (picked == null) return;
    setState(() => _emoji = picked);
    // No name set yet — nothing to persist under (Contact needs one); the
    // emoji is applied once a name is actually saved via [_saveName].
    final name = sanitizeDisplayName(_nameController.text);
    if (name.isEmpty) return;
    final existing = _existingContact;
    final c = Contact(
      nodeId: _nodeId,
      displayName: name,
      avatarEmoji: picked,
      publicKey: existing?.publicKey,
      addedAt: existing?.addedAt,
    );
    await _store.saveContact(c);
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
                  inputFormatters: const [_DisplayNameInputFormatter()],
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

            // QR + link — withheld until a name is set (see [_hasName]):
            // otherwise the code would encode an unset name, and whoever
            // scans it would save that as this device's name.
            if (_hasName)
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
              )
            else
              SectionCard(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.s16),
                  child: Column(
                    children: [
                      Icon(
                        Icons.info_outline,
                        color: context.appColors.warning,
                      ),
                      const SizedBox(height: AppSpacing.s8),
                      Text(
                        context.l10n.myCardNoNameTitle,
                        textAlign: TextAlign.center,
                        style: AppTextStyles.subtitle(context),
                      ),
                      const SizedBox(height: AppSpacing.s8),
                      Text(
                        context.l10n.myCardNoNameMessage,
                        textAlign: TextAlign.center,
                        style: AppTextStyles.bodyLargeSecondary(context),
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

/// Keeps a typed display name within [kDisplayNameMaxLength] Unicode code
/// points and free of newlines/control characters as the person types —
/// the same treatment [sanitizeDisplayName] applies before saving, surfaced
/// here so the field visibly refuses what would otherwise be silently
/// cleaned up later (see the sprint brief: a name typed without limit but
/// truncated only where it's used, with nothing to explain the mismatch).
class _DisplayNameInputFormatter extends TextInputFormatter {
  const _DisplayNameInputFormatter();

  static final _controlChars = RegExp(r'[\x00-\x1f\x7f]');

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final flattened = newValue.text.replaceAll(_controlChars, ' ');
    final capped = flattened.runes.length > kDisplayNameMaxLength
        ? String.fromCharCodes(flattened.runes.take(kDisplayNameMaxLength))
        : flattened;
    if (capped == newValue.text) return newValue;
    return TextEditingValue(
      text: capped,
      selection: TextSelection.collapsed(offset: capped.length),
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
