import 'package:flutter/material.dart';
import 'package:meshly/l10n/l10n.dart';
import 'package:meshly/services/channel_manager.dart';
import 'package:meshly/services/mesh_service.dart';
import 'package:meshly/theme/app_theme.dart';
import 'package:meshly/widgets/section_card.dart';
import 'package:meshly/widgets/tab_header.dart';

class NewChannelScreen extends StatefulWidget {
  const NewChannelScreen({required this.meshService, super.key});

  final MeshService meshService;

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

    Navigator.pop(context, ch);
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
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
        title: Text(context.l10n.newChannelTitle),
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
            // Эмодзи + название
            SectionCard(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.s16),
                child: Row(
                  children: [
                    GestureDetector(
                      onTap: _pickEmoji,
                      child: CircleAvatar(
                        radius: AppSizes.avatarList / 2,
                        backgroundColor:
                            Theme.of(context).colorScheme.primaryContainer,
                        child: Text(_emoji,
                            style: const TextStyle(
                                fontSize: AppSizes.emojiLarge)),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.s16),
                    Expanded(
                      child: TextField(
                        controller: _nameCtrl,
                        autofocus: true,
                        textCapitalization: TextCapitalization.sentences,
                        decoration: InputDecoration(
                          labelText: context.l10n.channelNameLabel,
                          hintText: context.l10n.channelNameHint,
                        ),
                        onChanged: (_) => setState(() {}),
                        onSubmitted: (_) => _create(),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.s12),

            // Сетка эмодзи
            SectionCard(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.s16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(context.l10n.channelIconLabel,
                        style: AppTextStyles.subtitle(context)),
                    const SizedBox(height: AppSpacing.s8),
                    Wrap(
                      spacing: AppSpacing.s8,
                      runSpacing: AppSpacing.s8,
                      children: _emojis.map((e) => GestureDetector(
                        onTap: () => setState(() => _emoji = e),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          width: AppSizes.emojiCellLarge,
                          height: AppSizes.emojiCellLarge,
                          decoration: BoxDecoration(
                            color: e == _emoji
                                ? Theme.of(context).colorScheme.primaryContainer
                                : Theme.of(context)
                                    .colorScheme
                                    .surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(AppRadius.card),
                          ),
                          child: Center(
                            child: Text(e,
                                style: const TextStyle(
                                    fontSize: AppSizes.emojiMedium)),
                          ),
                        ),
                      )).toList(),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.s12),

            // Инфо
            SectionCard(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.s14),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.info_outline,
                        size: AppIconSizes.info,
                        color: context.appColors.iconSecondary),
                    const SizedBox(width: AppSpacing.s10),
                    Expanded(
                      child: Text(
                        context.l10n.channelCreateInfo,
                        style: AppTextStyles.subtitle(context),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.s24),

            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _valid && !_loading ? _create : null,
                icon: _loading
                    ? SizedBox(
                        width: AppSizes.spinnerSmall,
                        height: AppSizes.spinnerSmall,
                        child: CircularProgressIndicator(
                            strokeWidth: AppSizes.spinnerStroke,
                            color: context.appColors.onAccent),
                      )
                    : const Icon(Icons.add),
                label: Text(context.l10n.createChannel),
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
        title: Text(context.l10n.chooseIconTitle),
        content: SizedBox(
          width: AppSizes.emojiDialogWidth,
          child: Wrap(
            spacing: AppSpacing.s8,
            runSpacing: AppSpacing.s8,
            children: _emojis.map((e) => GestureDetector(
              onTap: () => Navigator.pop(context, e),
              child: SizedBox(
                width: AppSizes.emojiCell,
                height: AppSizes.emojiCell,
                child: Center(
                  child: Text(e,
                      style: const TextStyle(fontSize: AppSizes.emojiLarge)),
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
