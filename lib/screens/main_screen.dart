import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:meshly/screens/contacts_screen.dart';
import 'package:meshly/screens/home_screen.dart';
import 'package:meshly/screens/settings_screen.dart';
import 'package:meshly/services/mesh_service.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({required this.meshService, super.key});

  final MeshService meshService;

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          IndexedStack(
            index: _index,
            children: [
              HomeScreen(meshService: widget.meshService),
              ContactsScreen(meshService: widget.meshService),
              SettingsScreen(meshService: widget.meshService),
            ],
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: _FloatingNavBar(
              currentIndex: _index,
              onTap: (i) => setState(() => _index = i),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Floating island nav bar ───────────────────────────────────

class _FloatingNavBar extends StatelessWidget {
  const _FloatingNavBar({required this.currentIndex, required this.onTap});

  final int currentIndex;
  final ValueChanged<int> onTap;

  static const List<({IconData icon, IconData activeIcon, String label})> _items = [
    (icon: Icons.chat_bubble_outline, activeIcon: Icons.chat_bubble, label: 'Чаты'),
    (icon: Icons.people_outline,      activeIcon: Icons.people,       label: 'Контакты'),
    (icon: Icons.settings_outlined,   activeIcon: Icons.settings,     label: 'Настройки'),
  ];

  @override
  Widget build(BuildContext context) {
    const radius = BorderRadius.all(Radius.circular(28));
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: radius,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.14),
              blurRadius: 24,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: radius,
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: ColoredBox(
              color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.88),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Row(
                    children: List.generate(_items.length, (i) {
                      return Expanded(
                        child: _NavItem(
                          icon: _items[i].icon,
                          activeIcon: _items[i].activeIcon,
                          label: _items[i].label,
                          selected: currentIndex == i,
                          onTap: () => onTap(i),
                        ),
                      );
                    }),
                  ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Один пункт навбара с анимацией ───────────────────────────

class _NavItem extends StatefulWidget {
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

  @override
  State<_NavItem> createState() => _NavItemState();
}

class _NavItemState extends State<_NavItem> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 80),
      reverseDuration: const Duration(milliseconds: 160),
    );
    _scale = Tween<double>(begin: 1, end: 0.88).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeIn, reverseCurve: Curves.elasticOut),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _onTapDown(_) => _ctrl.forward();
  void _onTapUp(_) => _ctrl.reverse();
  void _onTapCancel() => _ctrl.reverse();

  @override
  Widget build(BuildContext context) {
    final color = widget.selected
        ? Theme.of(context).colorScheme.primary
        : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.45);

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: widget.onTap,
      onTapDown: _onTapDown,
      onTapUp: _onTapUp,
      onTapCancel: _onTapCancel,
      child: ScaleTransition(
        scale: _scale,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: Icon(
                widget.selected ? widget.activeIcon : widget.icon,
                key: ValueKey(widget.selected),
                color: color,
                size: 24,
              ),
            ),
            const SizedBox(height: 4),
            AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 200),
              style: TextStyle(
                fontSize: 11,
                fontWeight: widget.selected ? FontWeight.w600 : FontWeight.w400,
                color: color,
              ),
              child: Text(widget.label),
            ),
          ],
        ),
      ),
    );
  }
}
