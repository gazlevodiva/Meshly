// Shared building blocks for the main-tab headers (Chats / Contacts):
// gradient backdrop, big title header with round action buttons, and the
// inline search row that replaces the header while searching.

import 'package:flutter/material.dart';
import 'package:meshly/l10n/l10n.dart';
import 'package:meshly/theme/app_theme.dart';

/// Full-screen vertical gradient backdrop for the main tabs
/// (same ramp as the scan screen: surfaceContainerLowest → surface).
class TabGradientBackground extends StatelessWidget {
  const TabGradientBackground({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [scheme.surfaceContainerLowest, scheme.surface],
        ),
      ),
      child: child,
    );
  }
}

/// Round header action button: tonal (surface circle) or filled (primary).
class RoundHeaderButton extends StatelessWidget {
  const RoundHeaderButton({
    required this.icon,
    required this.onPressed,
    this.filled = false,
    super.key,
  });

  final IconData icon;
  final VoidCallback onPressed;

  /// `true` → primary-colored circle with white icon (the "+" button).
  final bool filled;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: filled ? scheme.primary : scheme.surfaceContainer,
      shape: const CircleBorder(),
      child: InkWell(
        onTap: onPressed,
        customBorder: const CircleBorder(),
        child: SizedBox(
          width: AppSizes.headerButton,
          height: AppSizes.headerButton,
          child: Icon(
            icon,
            color: filled ? scheme.onPrimary : scheme.onSurface,
          ),
        ),
      ),
    );
  }
}

/// Big tab header: large bold title (+ optional grey subtitle) on the left,
/// round search and add buttons on the right (each hidden when its
/// callback is null — e.g. the Settings tab shows only the title).
class TabHeader extends StatelessWidget {
  const TabHeader({
    required this.title,
    this.onSearch,
    this.onAdd,
    this.subtitle,
    super.key,
  });

  final String title;
  final String? subtitle;
  final VoidCallback? onSearch;
  final VoidCallback? onAdd;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: AppTextStyles.headerTitle),
              if (subtitle != null) ...[
                const SizedBox(height: AppSpacing.s2),
                Text(subtitle!, style: AppTextStyles.subtitle(context)),
              ],
            ],
          ),
        ),
        if (onSearch != null) ...[
          const SizedBox(width: AppSpacing.s10),
          RoundHeaderButton(icon: Icons.search, onPressed: onSearch!),
        ],
        if (onAdd != null) ...[
          const SizedBox(width: AppSpacing.s10),
          RoundHeaderButton(icon: Icons.add, filled: true, onPressed: onAdd!),
        ],
      ],
    );
  }
}

/// Inline search row shown instead of [TabHeader] while searching:
/// rounded capsule text field + round close button.
class TabSearchRow extends StatelessWidget {
  const TabSearchRow({
    required this.controller,
    required this.onChanged,
    required this.onClose,
    super.key,
  });

  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        Expanded(
          child: Container(
            height: AppSizes.headerButton,
            padding:
                const EdgeInsets.symmetric(horizontal: AppSpacing.s16),
            decoration: BoxDecoration(
              color: scheme.surfaceContainer,
              borderRadius: BorderRadius.circular(AppRadius.pill),
            ),
            child: Center(
              child: TextField(
                controller: controller,
                autofocus: true,
                decoration: InputDecoration(
                  hintText: context.l10n.searchHint,
                  border: InputBorder.none,
                  isDense: true,
                ),
                onChanged: onChanged,
              ),
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.s10),
        RoundHeaderButton(icon: Icons.close, onPressed: onClose),
      ],
    );
  }
}
