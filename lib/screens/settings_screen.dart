import 'dart:async';

import 'package:flutter/material.dart';
import 'package:meshly/screens/blocked_nodes_screen.dart';
import 'package:meshly/screens/my_card_screen.dart';
import 'package:meshly/screens/notification_settings_screen.dart';
import 'package:meshly/screens/scan_screen.dart';
import 'package:meshly/services/contact_store.dart';
import 'package:meshly/services/mesh_service.dart';
import 'package:meshly/services/notification_settings.dart';
import 'package:meshly/services/theme_controller.dart';
import 'package:meshly/theme/app_theme.dart';
import 'package:meshly/widgets/sheet_drag_handle.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({required this.meshService, super.key});

  final MeshService meshService;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  Future<void> _disconnect() async {
    await widget.meshService.disconnect();
    if (mounted) {
      unawaited(Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute<void>(
            builder: (_) => ScanScreen(meshService: widget.meshService)),
        (_) => false,
      ));
    }
  }

  static String _themeModeLabel(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.system:
        return 'Системная';
      case ThemeMode.light:
        return 'Светлая';
      case ThemeMode.dark:
        return 'Тёмная';
    }
  }

  void _showThemePicker(BuildContext context) {
    unawaited(showModalBottomSheet<void>(
      context: context,
      shape: AppShapes.bottomSheet,
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.only(top: AppSpacing.s12),
          child: ListenableBuilder(
            listenable: ThemeController.instance,
            builder: (sheetContext, _) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SheetDragHandle(bottomMargin: AppSpacing.s8),
                  RadioGroup<ThemeMode>(
                    groupValue: ThemeController.instance.mode,
                    onChanged: (mode) async {
                      if (mode != null) {
                        await ThemeController.instance.setMode(mode);
                      }
                      if (sheetContext.mounted) Navigator.pop(sheetContext);
                    },
                    child: const Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        RadioListTile<ThemeMode>(
                          value: ThemeMode.system,
                          title: Text('Системная'),
                        ),
                        RadioListTile<ThemeMode>(
                          value: ThemeMode.light,
                          title: Text('Светлая'),
                        ),
                        RadioListTile<ThemeMode>(
                          value: ThemeMode.dark,
                          title: Text('Тёмная'),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.s8),
                ],
              );
            },
          ),
        ),
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Настройки')),
      body: ListView(
        padding: const EdgeInsets.only(bottom: AppSpacing.listBottomPadding),
        children: [
          // ── Профиль ──────────────────────────────────────────
          const _SectionHeader('Профиль'),
          ListTile(
            leading: const Icon(Icons.qr_code),
            title: const Text('Мой профиль и QR-код'),
            subtitle: const Text('Поделитесь своим контактом'),
            onTap: () => unawaited(Navigator.push<void>(
              context,
              MaterialPageRoute<void>(
                builder: (_) => MyCardScreen(meshService: widget.meshService),
              ),
            )),
          ),

          // ── Устройство ───────────────────────────────────────
          const _SectionHeader('Устройство'),
          ValueListenableBuilder<String?>(
            valueListenable: widget.meshService.deviceName,
            builder: (_, name, _) {
              final connected = widget.meshService.isConnected;
              if (name != null || connected) {
                return ListTile(
                  leading: Icon(Icons.bluetooth_connected,
                      color: context.appColors.brand),
                  title: Text('Подключено${name != null ? ': $name' : ''}'),
                  subtitle: const Text('Нажмите чтобы отключиться'),
                  onTap: _disconnect,
                );
              } else {
                return ListTile(
                  leading: Icon(Icons.bluetooth_disabled,
                      color: context.appColors.iconSecondary),
                  title: const Text('Нет подключения'),
                );
              }
            },
          ),

          // ── Уведомления ──────────────────────────────────────
          const _SectionHeader('Уведомления'),
          ListenableBuilder(
            listenable: NotificationSettings.instance,
            builder: (context, _) {
              final enabled = NotificationSettings.instance.enabled;
              return ListTile(
                leading: Icon(
                  enabled
                      ? Icons.notifications_outlined
                      : Icons.notifications_off_outlined,
                  color: enabled ? null : context.appColors.iconSecondary,
                ),
                title: const Text('Настройки уведомлений'),
                subtitle: Text(enabled ? 'Включены' : 'Выключены'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => unawaited(Navigator.push<void>(
                  context,
                  MaterialPageRoute<void>(
                    builder: (_) => const NotificationSettingsScreen(),
                  ),
                )),
              );
            },
          ),

          // ── Заблокированные ──────────────────────────────────
          const _SectionHeader('Заблокированные'),
          ListenableBuilder(
            listenable: ContactStore.instance,
            builder: (context, _) {
              final count = ContactStore.instance.blockedNodes.length;
              return ListTile(
                leading: const Icon(Icons.block),
                title: const Text('Заблокированные ноды'),
                subtitle: Text(count == 0 ? 'Нет заблокированных нод' : 'Заблокировано: $count'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => unawaited(Navigator.push<void>(
                  context,
                  MaterialPageRoute<void>(
                    builder: (_) => const BlockedNodesScreen(),
                  ),
                )),
              );
            },
          ),

          // ── Внешний вид ──────────────────────────────────────
          const _SectionHeader('Внешний вид'),
          ListenableBuilder(
            listenable: ThemeController.instance,
            builder: (context, _) {
              return ListTile(
                leading: const Icon(Icons.brightness_6_outlined),
                title: const Text('Тема'),
                subtitle: Text(_themeModeLabel(ThemeController.instance.mode)),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _showThemePicker(context),
              );
            },
          ),

          // ── О приложении ─────────────────────────────────────
          const _SectionHeader('О приложении'),
          const ListTile(
            leading: Icon(Icons.info_outline),
            title: Text('Meshly'),
            subtitle: Text('v1.0.0 · Open source'),
          ),
          ListTile(
            leading: const Icon(Icons.open_in_new),
            title: const Text('GitHub'),
            subtitle: const Text('github.com/gazlevodiva/Meshly'),
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('github.com/gazlevodiva/Meshly'),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.title);

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.s16, AppSpacing.s16, AppSpacing.s16, AppSpacing.s4),
      child: Text(
        title,
        style: AppTextStyles.sectionHeader.copyWith(
          color: Theme.of(context).colorScheme.primary,
        ),
      ),
    );
  }
}
