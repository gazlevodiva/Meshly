import 'dart:async';

import 'package:flutter/material.dart';
import 'package:meshly/l10n/l10n.dart';
import 'package:meshly/services/lora_region.dart';
import 'package:meshly/services/mesh_service.dart';
import 'package:meshly/theme/app_theme.dart';
import 'package:meshly/widgets/section_card.dart';
import 'package:meshly/widgets/sheet_drag_handle.dart';
import 'package:meshly/widgets/tab_header.dart';

/// LoRa region selection screen.
///
/// The board ships from the factory with [LoraRegion.unset] and physically
/// does not transmit over the air until the region is chosen explicitly —
/// this is the one place in the app where that can be done.
///
/// While no region is set, the screen collapses as much as possible into a
/// single confirming tap — the suggestion comes from the phone's country
/// ([LoraRegion.suggestedFor]). The full list of 37 codes is the fallback for
/// when there is no suggestion, or via an explicit tap on the secondary link.
class RadioRegionScreen extends StatefulWidget {
  const RadioRegionScreen({required this.meshService, super.key});

  final MeshService meshService;

  @override
  State<RadioRegionScreen> createState() => _RadioRegionScreenState();
}

class _RadioRegionScreenState extends State<RadioRegionScreen> {
  bool _applying = false;

  /// Show the full list instead of the suggestion — either because there is
  /// no suggestion, or the user explicitly asked to "choose another region".
  bool _showFullList = false;

  /// Region matching the phone's country, if it could be determined.
  /// Computed once in [initState]: the platform locale doesn't change while
  /// the screen is open, and reading it via [WidgetsBinding] (rather than
  /// directly through `dart:ui`) is the only way to override the locale in
  /// tests.
  late final LoraRegion? _suggested;

  @override
  void initState() {
    super.initState();
    _suggested = LoraRegion.suggestedFor(
      WidgetsBinding.instance.platformDispatcher.locale.countryCode,
    );
  }

  Future<void> _applyRegion(LoraRegion region, {required int? current}) async {
    final confirmed = await _confirmRegionChange(region, current: current);
    if (!confirmed || !mounted) return;

    setState(() => _applying = true);
    final ok = await widget.meshService.setRegion(region.value);
    if (!mounted) return;
    setState(() => _applying = false);

    final messenger = ScaffoldMessenger.of(context);
    if (ok) {
      messenger.showSnackBar(
        SnackBar(content: Text(context.l10n.radioRegionApplying)),
      );
      Navigator.of(context).pop();
    } else {
      messenger.showSnackBar(
        SnackBar(content: Text(context.l10n.radioRegionFailed)),
      );
    }
  }

  Future<bool> _confirmRegionChange(
    LoraRegion region, {
    required int? current,
  }) async {
    // A region was already set (and it's not the same code) — changing it
    // breaks the connection with everyone whose device stayed on the old
    // region. This needs to be said plainly, not just mention a reboot.
    final isChange =
        current != null &&
        current != LoraRegion.unset &&
        current != region.value;

    final result = await showModalBottomSheet<bool>(
      context: context,
      shape: AppShapes.bottomSheet,
      builder: (sheetContext) => SafeArea(
        child: SingleChildScrollView(
          // With a large system font (or a long region-change warning) the
          // content might not fit the sheet's height — better to scroll than
          // to get clipped at the bottom.
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.s20,
            AppSpacing.s12,
            AppSpacing.s20,
            AppSpacing.s20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SheetDragHandle(),
              Text(region.code, style: AppTextStyles.title),
              const SizedBox(height: AppSpacing.s8),
              Text(
                sheetContext.l10n.radioRegionApplying,
                style: AppTextStyles.secondary(sheetContext),
              ),
              if (isChange) ...[
                const SizedBox(height: AppSpacing.s8),
                Text(
                  sheetContext.l10n.radioRegionChangeWarning,
                  style: TextStyle(color: sheetContext.appColors.danger),
                ),
              ],
              const SizedBox(height: AppSpacing.s24),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.pop(sheetContext, false),
                      child: Text(
                        MaterialLocalizations.of(
                          sheetContext,
                        ).cancelButtonLabel,
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.s12),
                  Expanded(
                    child: FilledButton(
                      onPressed: () => Navigator.pop(sheetContext, true),
                      child: Text(sheetContext.l10n.radioRegionChoose),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
    return result ?? false;
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
        title: Text(context.l10n.radioRegionTitle),
      ),
      body: TabGradientBackground(
        child: ValueListenableBuilder<int?>(
          valueListenable: widget.meshService.loraRegion,
          builder: (context, current, _) {
            final suggested = _suggested;
            final showSuggestion =
                !_showFullList &&
                suggested != null &&
                (current == null || current == LoraRegion.unset);

            return AbsorbPointer(
              absorbing: _applying,
              child: Opacity(
                opacity: _applying ? 0.6 : 1,
                child: showSuggestion
                    ? _SuggestionView(
                        suggested: suggested,
                        topInset: topInset,
                        onConfirm: () => unawaited(
                          _applyRegion(suggested, current: current),
                        ),
                        onChooseOther: () =>
                            setState(() => _showFullList = true),
                      )
                    : _FullListView(
                        topInset: topInset,
                        current: current,
                        onTap: (region) =>
                            _applyRegion(region, current: current),
                      ),
              ),
            );
          },
        ),
      ),
    );
  }
}

/// The single confirming action: the region suggested from the phone's
/// country, with one prominent button and a small secondary link to the full
/// list — instead of a list of 37 codes that an ordinary person can't
/// realistically choose from.
class _SuggestionView extends StatelessWidget {
  const _SuggestionView({
    required this.suggested,
    required this.topInset,
    required this.onConfirm,
    required this.onChooseOther,
  });

  final LoraRegion suggested;
  final double topInset;
  final VoidCallback onConfirm;
  final VoidCallback onChooseOther;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.s20,
        topInset + AppSpacing.s20,
        AppSpacing.s20,
        AppSpacing.listBottomPadding,
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          // On a small screen (or with a large system font) the height can
          // go negative — BoxConstraints wouldn't survive that.
          minHeight:
              (MediaQuery.sizeOf(context).height -
                      topInset -
                      AppSpacing.listBottomPadding)
                  .clamp(0, double.infinity),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Icon(
              Icons.settings_input_antenna,
              size: AppIconSizes.hero,
              color: context.appColors.brand,
            ),
            const SizedBox(height: AppSpacing.s20),
            Text(
              context.l10n.radioRegionSuggestBody(suggested.code),
              textAlign: TextAlign.center,
              style: AppTextStyles.title,
            ),
            const SizedBox(height: AppSpacing.s8),
            Text(
              context.l10n.radioRegionHint,
              textAlign: TextAlign.center,
              style: AppTextStyles.hint(context),
            ),
            const SizedBox(height: AppSpacing.s32),
            FilledButton(
              onPressed: onConfirm,
              child: Text(context.l10n.radioRegionSuggestConfirm),
            ),
            const SizedBox(height: AppSpacing.s12),
            TextButton(
              onPressed: onChooseOther,
              child: Text(context.l10n.radioRegionSuggestOther),
            ),
          ],
        ),
      ),
    );
  }
}

/// The full list: common regions, all regions, and — in a separate section
/// with a warning — regions of a different range than what's already set on
/// the board (incompatible ones aren't removed entirely: there can be a
/// legitimate reason to pick one, e.g. the board was swapped — but the
/// choice is clearly flagged as risky).
class _FullListView extends StatelessWidget {
  const _FullListView({
    required this.topInset,
    required this.current,
    required this.onTap,
  });

  final double topInset;
  final int? current;
  final Future<void> Function(LoraRegion region) onTap;

  @override
  Widget build(BuildContext context) {
    final compatible = LoraRegion.compatibleWith(current ?? LoraRegion.unset);
    final compatibleCodes = compatible.map((r) => r.code).toSet();
    final incompatible = LoraRegion.all
        .where((r) => !compatibleCodes.contains(r.code))
        .toList();

    return ListView(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.s16,
        topInset + AppSpacing.s8,
        AppSpacing.s16,
        AppSpacing.listBottomPadding,
      ),
      children: [
        Text(
          context.l10n.radioRegionHint,
          style: AppTextStyles.hint(context),
        ),
        const SizedBox(height: AppSpacing.s20),
        SectionCard(
          title: context.l10n.radioRegionCommon,
          child: _RegionList(
            regions: LoraRegion.common,
            current: current,
            onTap: onTap,
          ),
        ),
        const SizedBox(height: AppSpacing.s20),
        SectionCard(
          title: context.l10n.radioRegionAll,
          child: _RegionList(
            regions: compatible,
            current: current,
            onTap: onTap,
          ),
        ),
        if (incompatible.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.s20),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s4),
            child: Text(
              context.l10n.radioRegionIncompatibleWarning,
              style: TextStyle(color: context.appColors.warning),
            ),
          ),
          const SizedBox(height: AppSpacing.s12),
          SectionCard(
            title: context.l10n.radioRegionIncompatibleSection,
            child: _RegionList(
              regions: incompatible,
              current: current,
              onTap: onTap,
            ),
          ),
        ],
      ],
    );
  }
}

class _RegionList extends StatelessWidget {
  const _RegionList({
    required this.regions,
    required this.current,
    required this.onTap,
  });

  final List<LoraRegion> regions;
  final int? current;
  final Future<void> Function(LoraRegion region) onTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var i = 0; i < regions.length; i++) ...[
          if (i > 0) const Divider(height: 1),
          ListTile(
            title: Text(regions[i].code, style: AppTextStyles.mono),
            trailing: regions[i].value == current
                ? Icon(Icons.check, color: context.appColors.brand)
                : null,
            onTap: () => unawaited(onTap(regions[i])),
          ),
        ],
      ],
    );
  }
}
