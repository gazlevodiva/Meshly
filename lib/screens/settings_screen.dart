import 'dart:async';

import 'package:flutter/material.dart';
import 'package:meshly/l10n/l10n.dart';
import 'package:meshly/screens/blocked_nodes_screen.dart';
import 'package:meshly/screens/my_card_screen.dart';
import 'package:meshly/screens/notification_settings_screen.dart';
import 'package:meshly/screens/radio_region_screen.dart';
import 'package:meshly/screens/scan_screen.dart';
import 'package:meshly/services/contact_store.dart';
import 'package:meshly/services/locale_controller.dart';
import 'package:meshly/services/lora_region.dart';
import 'package:meshly/services/mesh_service.dart';
import 'package:meshly/services/notification_settings.dart';
import 'package:meshly/services/theme_controller.dart';
import 'package:meshly/theme/app_theme.dart';
import 'package:meshly/widgets/section_card.dart';
import 'package:meshly/widgets/sheet_drag_handle.dart';
import 'package:meshly/widgets/tab_header.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({required this.meshService, super.key});

  final MeshService meshService;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  static final Uri _githubUri = Uri.parse(
    'https://github.com/gazlevodiva/Meshly',
  );

  String _version = '1.0.0';

  @override
  void initState() {
    super.initState();
    unawaited(_loadVersion());
  }

  Future<void> _loadVersion() async {
    try {
      final info = await PackageInfo.fromPlatform();
      if (mounted && info.version.isNotEmpty) {
        setState(() => _version = info.version);
      }
    } on Exception {
      // Platform channel unavailable (e.g. in tests) — keep the default.
    }
  }

  Future<void> _openGitHub() async {
    var opened = false;
    try {
      opened = await launchUrl(
        _githubUri,
        mode: LaunchMode.externalApplication,
      );
    } on Exception {
      opened = false;
    }
    if (!opened && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('github.com/gazlevodiva/Meshly'),
        ),
      );
    }
  }

  static String _themeModeLabel(BuildContext context, ThemeMode mode) {
    switch (mode) {
      case ThemeMode.system:
        return context.l10n.themeSystem;
      case ThemeMode.light:
        return context.l10n.themeLight;
      case ThemeMode.dark:
        return context.l10n.themeDark;
    }
  }

  static String _languageLabel(BuildContext context, Locale? locale) {
    switch (locale?.languageCode) {
      case 'ru':
        return context.l10n.languageRussian;
      case 'en':
        return context.l10n.languageEnglish;
      default:
        return context.l10n.languageSystem;
    }
  }

  void _showLanguagePicker(BuildContext context) {
    unawaited(
      showModalBottomSheet<void>(
        context: context,
        shape: AppShapes.bottomSheet,
        builder: (_) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.only(top: AppSpacing.s12),
            child: ListenableBuilder(
              listenable: LocaleController.instance,
              builder: (sheetContext, _) {
                // 'system' sentinel — RadioGroup can't use null as a value.
                final current =
                    LocaleController.instance.locale?.languageCode ?? 'system';
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SheetDragHandle(bottomMargin: AppSpacing.s8),
                    RadioGroup<String>(
                      groupValue: current,
                      onChanged: (code) async {
                        if (code != null) {
                          await LocaleController.instance.setLocale(
                            code == 'system' ? null : Locale(code),
                          );
                        }
                        if (sheetContext.mounted) Navigator.pop(sheetContext);
                      },
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          RadioListTile<String>(
                            value: 'system',
                            title: Text(sheetContext.l10n.languageSystem),
                          ),
                          RadioListTile<String>(
                            value: 'ru',
                            title: Text(sheetContext.l10n.languageRussian),
                          ),
                          RadioListTile<String>(
                            value: 'en',
                            title: Text(sheetContext.l10n.languageEnglish),
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
      ),
    );
  }

  void _showThemePicker(BuildContext context) {
    unawaited(
      showModalBottomSheet<void>(
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
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          RadioListTile<ThemeMode>(
                            value: ThemeMode.system,
                            title: Text(sheetContext.l10n.themeSystem),
                          ),
                          RadioListTile<ThemeMode>(
                            value: ThemeMode.light,
                            title: Text(sheetContext.l10n.themeLight),
                          ),
                          RadioListTile<ThemeMode>(
                            value: ThemeMode.dark,
                            title: Text(sheetContext.l10n.themeDark),
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
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: TabGradientBackground(
        child: SafeArea(
          bottom: false,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.s20,
                  AppSpacing.s12,
                  AppSpacing.s20,
                  AppSpacing.s12,
                ),
                child: TabHeader(title: context.l10n.settingsTitle),
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.s16,
                    0,
                    AppSpacing.s16,
                    AppSpacing.listBottomPadding,
                  ),
                  children: [
                    // ── Profile ──────────────────────────────────────
                    SectionCard(
                      title: context.l10n.settingsSectionProfile,
                      child: ListTile(
                        leading: const Icon(Icons.qr_code),
                        title: Text(context.l10n.myProfileQrTitle),
                        subtitle: Text(context.l10n.shareYourContactSubtitle),
                        onTap: () => unawaited(
                          Navigator.push<void>(
                            context,
                            MaterialPageRoute<void>(
                              builder: (_) =>
                                  MyCardScreen(meshService: widget.meshService),
                            ),
                          ),
                        ),
                      ),
                    ),

                    // ── Notifications ──────────────────────────────────
                    SectionCard(
                      title: context.l10n.notificationsTitle,
                      child: ListenableBuilder(
                        listenable: NotificationSettings.instance,
                        builder: (context, _) {
                          final enabled = NotificationSettings.instance.enabled;
                          return ListTile(
                            leading: Icon(
                              enabled
                                  ? Icons.notifications_outlined
                                  : Icons.notifications_off_outlined,
                              color: enabled
                                  ? null
                                  : context.appColors.iconSecondary,
                            ),
                            title: Text(context.l10n.notificationSettingsTile),
                            subtitle: Text(
                              enabled
                                  ? context.l10n.notificationsEnabled
                                  : context.l10n.notificationsDisabled,
                            ),
                            trailing: const Icon(Icons.chevron_right),
                            onTap: () => unawaited(
                              Navigator.push<void>(
                                context,
                                MaterialPageRoute<void>(
                                  builder: (_) =>
                                      const NotificationSettingsScreen(),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),

                    // ── Blocked ──────────────────────────────
                    SectionCard(
                      title: context.l10n.settingsSectionBlocked,
                      child: ListenableBuilder(
                        listenable: ContactStore.instance,
                        builder: (context, _) {
                          final count =
                              ContactStore.instance.blockedNodes.length;
                          return ListTile(
                            leading: const Icon(Icons.block),
                            title: Text(context.l10n.blockedNodesTile),
                            subtitle: Text(
                              count == 0
                                  ? context.l10n.noBlockedNodes
                                  : context.l10n.blockedCount(count),
                            ),
                            trailing: const Icon(Icons.chevron_right),
                            onTap: () => unawaited(
                              Navigator.push<void>(
                                context,
                                MaterialPageRoute<void>(
                                  builder: (_) => const BlockedNodesScreen(),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),

                    // ── Appearance ──────────────────────────────────
                    SectionCard(
                      title: context.l10n.settingsSectionAppearance,
                      child: Column(
                        children: [
                          ListenableBuilder(
                            listenable: ThemeController.instance,
                            builder: (context, _) {
                              return ListTile(
                                leading: const Icon(
                                  Icons.brightness_6_outlined,
                                ),
                                title: Text(context.l10n.themeTile),
                                subtitle: Text(
                                  _themeModeLabel(
                                    context,
                                    ThemeController.instance.mode,
                                  ),
                                ),
                                trailing: const Icon(Icons.chevron_right),
                                onTap: () => _showThemePicker(context),
                              );
                            },
                          ),
                          const Divider(height: 1),
                          ListenableBuilder(
                            listenable: LocaleController.instance,
                            builder: (context, _) {
                              return ListTile(
                                leading: const Icon(Icons.language),
                                title: Text(context.l10n.languageTile),
                                subtitle: Text(
                                  _languageLabel(
                                    context,
                                    LocaleController.instance.locale,
                                  ),
                                ),
                                trailing: const Icon(Icons.chevron_right),
                                onTap: () => _showLanguagePicker(context),
                              );
                            },
                          ),
                        ],
                      ),
                    ),

                    // ── Advanced ────────────────────────────────
                    // No section title — deliberately: connection state and
                    // radio region are hidden in a sub-screen; in plain
                    // sight this row would only confuse a newcomer. The
                    // card has no title of its own, so we explicitly ask it
                    // for a top gap — otherwise it would stick to the
                    // previous card.
                    SectionCard(
                      topGap: true,
                      child: ListTile(
                        leading: const Icon(Icons.tune),
                        title: Text(context.l10n.settingsAdvancedTitle),
                        subtitle: Text(context.l10n.settingsAdvancedSubtitle),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => unawaited(
                          Navigator.push<void>(
                            context,
                            MaterialPageRoute<void>(
                              builder: (_) => _AdvancedSettingsScreen(
                                meshService: widget.meshService,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),

                    // ── About ─────────────────────────────────
                    SectionCard(
                      title: context.l10n.settingsSectionAbout,
                      child: Column(
                        children: [
                          ListTile(
                            leading: const Icon(Icons.info_outline),
                            title: const Text('Meshly'),
                            subtitle: Text(
                              context.l10n.versionOpenSource(_version),
                            ),
                          ),
                          ListTile(
                            leading: const Icon(Icons.open_in_new),
                            title: const Text('GitHub'),
                            subtitle: const Text(
                              'github.com/gazlevodiva/Meshly',
                            ),
                            onTap: () => unawaited(_openGitHub()),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Value of the region row: a code, "not set", or "reading settings" —
/// used both by settings and the "Advanced" sub-screen.
String _regionLabel(BuildContext context, int? value) {
  if (value == null) return context.l10n.radioRegionReading;
  if (value == LoraRegion.unset) return context.l10n.radioRegionNotSet;
  final code = LoraRegion.codeOf(value);
  return code ?? context.l10n.radioRegionUnknownCode(value);
}

/// The "Advanced" sub-screen — settings for those who understand the
/// consequences.
///
/// The connection row and the radio region are grouped into one "Device"
/// section: both rows are about the physical device. Connection state is
/// already visible on the home screen — it's hidden here so as not to
/// confuse a newcomer. The radio region is hidden for the same reason: a
/// correctly configured region almost never needs to change, and changing
/// it breaks the connection with everyone whose device stayed on the old
/// one (see the "not configured" card on the home screen — it remains
/// there for the newcomer).
class _AdvancedSettingsScreen extends StatelessWidget {
  const _AdvancedSettingsScreen({required this.meshService});

  final MeshService meshService;

  Future<void> _disconnect(BuildContext context) async {
    await meshService.disconnect();
    if (context.mounted) {
      unawaited(
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute<void>(
            builder: (_) => ScanScreen(
              meshService: meshService,
              // Intentional disconnect: don't reconnect right away.
              autoConnect: false,
            ),
          ),
          (_) => false,
        ),
      );
    }
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
        title: Text(context.l10n.settingsAdvancedTitle),
      ),
      body: TabGradientBackground(
        child: ListView(
          padding: EdgeInsets.fromLTRB(
            AppSpacing.s16,
            topInset + AppSpacing.s8,
            AppSpacing.s16,
            AppSpacing.listBottomPadding,
          ),
          children: [
            SectionCard(
              title: context.l10n.settingsSectionDevice,
              child: Column(
                children: [
                  ValueListenableBuilder<String?>(
                    valueListenable: meshService.deviceName,
                    builder: (context, name, _) {
                      final connected = meshService.isConnected;
                      if (name != null || connected) {
                        return ListTile(
                          leading: Icon(
                            Icons.bluetooth_connected,
                            color: context.appColors.brand,
                          ),
                          title: Text(
                            name != null
                                ? context.l10n.connectedToName(name)
                                : context.l10n.statusConnected,
                          ),
                          subtitle: Text(context.l10n.tapToDisconnect),
                          onTap: () => unawaited(_disconnect(context)),
                        );
                      } else {
                        return ListTile(
                          leading: Icon(
                            Icons.bluetooth_disabled,
                            color: context.appColors.iconSecondary,
                          ),
                          title: Text(context.l10n.statusNoConnection),
                        );
                      }
                    },
                  ),
                  const Divider(height: 1),
                  ValueListenableBuilder<int?>(
                    valueListenable: meshService.loraRegion,
                    builder: (context, region, _) {
                      final enabled = meshService.canSetRegion;
                      return ListTile(
                        leading: Icon(
                          Icons.settings_input_antenna,
                          color: enabled
                              ? null
                              : context.appColors.iconSecondary,
                        ),
                        title: Text(context.l10n.radioRegionTitle),
                        subtitle: Text(_regionLabel(context, region)),
                        trailing: const Icon(Icons.chevron_right),
                        enabled: enabled,
                        onTap: () => unawaited(
                          Navigator.push<void>(
                            context,
                            MaterialPageRoute<void>(
                              builder: (_) =>
                                  RadioRegionScreen(meshService: meshService),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
