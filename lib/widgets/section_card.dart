import 'package:flutter/material.dart';
import 'package:meshly/theme/app_theme.dart';

/// A settings-style section: an optional small primary-colored header above
/// a rounded surface card holding the section's rows.
///
/// Used by the Settings tab and the contact/channel cards so every screen
/// groups content identically.
class SectionCard extends StatelessWidget {
  const SectionCard({
    required this.child,
    super.key,
    this.title,
    this.topGap = false,
  });

  /// Small uppercase-style header above the card; omitted when null.
  final String? title;

  /// Card content — typically a [Column] of [ListTile]s.
  final Widget child;

  /// When [title] is null, adds the same top margin a titled section gets
  /// from its own header padding, so this card doesn't sit flush against
  /// whatever precedes it. Ignored when [title] is set — the header already
  /// provides that gap.
  ///
  /// Defaults to false: most call sites already place a manual [SizedBox]
  /// before each [SectionCard] regardless of title, and this default keeps
  /// their spacing unchanged. Pass true only where an untitled card follows
  /// another section with no such manual gap in between.
  final bool topGap;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (title != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.s16,
              AppSpacing.s16,
              AppSpacing.s16,
              AppSpacing.s8,
            ),
            child: Text(
              title!,
              style: AppTextStyles.sectionHeader.copyWith(
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
          )
        else if (topGap)
          const SizedBox(height: AppSpacing.s16),
        Material(
          color: Theme.of(context).colorScheme.surfaceContainer,
          borderRadius: BorderRadius.circular(AppRadius.cardLarge),
          clipBehavior: Clip.antiAlias,
          child: child,
        ),
      ],
    );
  }
}
