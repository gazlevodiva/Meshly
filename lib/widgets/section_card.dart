import 'package:flutter/material.dart';
import 'package:meshly/theme/app_theme.dart';

/// A settings-style section: an optional small primary-colored header above
/// a rounded surface card holding the section's rows.
///
/// Used by the Settings tab and the contact/channel cards so every screen
/// groups content identically.
class SectionCard extends StatelessWidget {
  const SectionCard({required this.child, super.key, this.title});

  /// Small uppercase-style header above the card; omitted when null.
  final String? title;

  /// Card content — typically a [Column] of [ListTile]s.
  final Widget child;

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
          ),
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
