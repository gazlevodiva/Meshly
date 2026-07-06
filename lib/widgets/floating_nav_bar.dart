import 'package:flutter/material.dart';
import 'package:meshly/l10n/l10n.dart';
import 'package:meshly/theme/app_theme.dart';

/// Floating "island" bottom navigation bar.
///
/// Minimal by design: three icon+label tabs laid out space-evenly (equal
/// gaps around and between items regardless of label length). The active
/// tab is a flat primary-blue tint — no gradient, no background pill, no
/// sliding indicator.
class FloatingNavBar extends StatelessWidget {
  const FloatingNavBar({
    required this.currentIndex,
    required this.onTap,
    super.key,
  });

  /// Index of the selected tab (0..2).
  final int currentIndex;

  /// Called with the tapped tab index.
  final ValueChanged<int> onTap;

  static const List<({IconData icon, IconData activeIcon})> _icons = [
    (icon: Icons.chat_bubble_outline, activeIcon: Icons.chat_bubble),
    (icon: Icons.people_outline, activeIcon: Icons.people),
    (icon: Icons.settings_outlined, activeIcon: Icons.settings),
  ];

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final l10n = context.l10n;
    final labels = [l10n.navChats, l10n.navContacts, l10n.navSettings];
    const islandRadius = BorderRadius.all(Radius.circular(AppRadius.island));

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.s16,
          0,
          AppSpacing.s16,
          AppSpacing.s12,
        ),
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: islandRadius,
            boxShadow: [
              BoxShadow(
                color: context.appColors.islandShadow,
                blurRadius: AppSizes.inputShadowBlur,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Material(
            color: scheme.surfaceContainer,
            borderRadius: islandRadius,
            clipBehavior: Clip.antiAlias,
            child: SizedBox(
              height: AppSizes.navBarInnerHeight + AppSpacing.s12,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  for (var i = 0; i < _icons.length; i++)
                    // Flexible + FittedBox inside the item: on narrow screens
                    // items shrink proportionally instead of overflowing.
                    Flexible(
                      child: _NavItem(
                        icon: _icons[i].icon,
                        activeIcon: _icons[i].activeIcon,
                        label: labels[i],
                        selected: currentIndex == i,
                        onTap: () => onTap(i),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// One tab: icon + label in a row. The active tab is a flat primary tint,
/// the inactive a dimmed onSurface; states cross-fade with an
/// [AnimatedSwitcher].
class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final IconData activeIcon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  static const Duration _switchDuration = Duration(milliseconds: 200);

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    final color = selected
        ? scheme.primary
        : scheme.onSurface.withValues(alpha: AppOpacities.navInactive);

    final content = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          selected ? activeIcon : icon,
          size: AppIconSizes.navCompact,
          color: color,
        ),
        const SizedBox(width: AppSpacing.s6),
        Text(
          label,
          maxLines: 1,
          softWrap: false,
          style: AppTextStyles.navLabel.copyWith(color: color),
        ),
      ],
    );

    return InkWell(
      onTap: onTap,
      // No splash/highlight — switching feedback is the cross-fade alone.
      splashFactory: NoSplash.splashFactory,
      highlightColor: Colors.transparent,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.s14,
          vertical: AppSpacing.s8,
        ),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: AnimatedSwitcher(
            duration: _switchDuration,
            switchInCurve: Curves.easeOut,
            switchOutCurve: Curves.easeIn,
            child: KeyedSubtree(
              key: ValueKey(selected),
              child: content,
            ),
          ),
        ),
      ),
    );
  }
}
