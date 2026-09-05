import 'dart:async';

import 'package:flutter/material.dart';
import 'package:meshly/l10n/l10n.dart';
import 'package:meshly/services/lora_region.dart';
import 'package:meshly/services/mesh_service.dart';
import 'package:meshly/theme/app_theme.dart';
import 'package:meshly/widgets/section_card.dart';
import 'package:meshly/widgets/sheet_drag_handle.dart';
import 'package:meshly/widgets/tab_header.dart';

/// Экран выбора региона LoRa.
///
/// С завода плата приходит с [LoraRegion.unset] и физически не вещает в
/// эфир, пока регион не выбран явно — здесь и есть единственное место в
/// приложении, где это можно сделать.
///
/// Пока регион не задан, экран по возможности сводится к одному
/// подтверждающему тапу — подсказка берётся из страны телефона
/// ([LoraRegion.suggestedFor]). Полный список из 37 кодов — запасной вариант
/// для случая, когда подсказки нет, либо явный переход по вторичной ссылке.
class RadioRegionScreen extends StatefulWidget {
  const RadioRegionScreen({required this.meshService, super.key});

  final MeshService meshService;

  @override
  State<RadioRegionScreen> createState() => _RadioRegionScreenState();
}

class _RadioRegionScreenState extends State<RadioRegionScreen> {
  bool _applying = false;

  /// Показать полный список вместо подсказки — либо потому что подсказки
  /// нет, либо пользователь явно попросил «выбрать другой регион».
  bool _showFullList = false;

  /// Регион, подходящий стране телефона, если её удалось определить.
  /// Вычисляется один раз в [initState]: локаль платформы не меняется, пока
  /// открыт экран, а чтение через [WidgetsBinding] (а не напрямую через
  /// `dart:ui`) — единственный способ подменить локаль в тестах.
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
    // Регион уже был задан (и это не тот же самый код) — смена рвёт связь
    // со всеми, у кого устройство осталось на прежнем регионе. Об этом
    // нужно сказать прямо, а не только про перезагрузку.
    final isChange =
        current != null &&
        current != LoraRegion.unset &&
        current != region.value;

    final result = await showModalBottomSheet<bool>(
      context: context,
      shape: AppShapes.bottomSheet,
      builder: (sheetContext) => SafeArea(
        child: SingleChildScrollView(
          // При крупном системном шрифте (или длинном предупреждении о
          // смене региона) содержимое может не поместиться в высоту
          // шторки — пусть лучше прокрутится, чем обрежется снизу.
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

/// Единственное подтверждающее действие: подсказанный по стране телефона
/// регион с одной заметной кнопкой и мелкой вторичной ссылкой на полный
/// список — вместо списка из 37 кодов, который обычный человек выбрать
/// не может.
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
          // На маленьком экране (или при большом системном шрифте) высота
          // может уйти в минус — BoxConstraints этого не переживёт.
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

/// Полный список: частые регионы, все регионы, и — отдельной секцией с
/// предупреждением — регионы другого диапазона, чем уже задан на плате
/// (несовместимые не убираем совсем: осмысленный выбор мог быть, например,
/// заменили плату — но выбор явно окрашен как рискованный).
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
