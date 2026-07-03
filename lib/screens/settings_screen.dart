import 'dart:async';

import 'package:flutter/material.dart';
import 'package:meshly/screens/my_card_screen.dart';
import 'package:meshly/screens/scan_screen.dart';
import 'package:meshly/services/mesh_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({required this.meshService, super.key});

  final MeshService meshService;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _notificationsEnabled = true;

  @override
  void initState() {
    super.initState();
    unawaited(_loadPrefs());
  }

  Future<void> _loadPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _notificationsEnabled =
          prefs.getBool('notifications_enabled') ?? true;
    });
  }

  Future<void> _setNotifications(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('notifications_enabled', value);
    setState(() => _notificationsEnabled = value);
  }

  Future<void> _disconnect() async {
    await widget.meshService.disconnect();
    if (mounted) {
      unawaited(Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(
            builder: (_) => ScanScreen(meshService: widget.meshService)),
        (_) => false,
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Настройки')),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 96),
        children: [
          // ── Профиль ──────────────────────────────────────────
          const _SectionHeader('Профиль'),
          ListTile(
            leading: const Icon(Icons.qr_code),
            title: const Text('Мой профиль и QR-код'),
            subtitle: const Text('Поделитесь своим контактом'),
            onTap: () => unawaited(Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => MyCardScreen(meshService: widget.meshService),
              ),
            )),
          ),

          // ── Устройство ───────────────────────────────────────
          const _SectionHeader('Устройство'),
          StreamBuilder<String?>(
            stream: widget.meshService.connectedDeviceName,
            builder: (_, snap) {
              final name = snap.data;
              final connected = widget.meshService.isConnected;
              if (name != null || connected) {
                return ListTile(
                  leading: const Icon(Icons.bluetooth_connected,
                      color: Colors.blue),
                  title: Text('Подключено${name != null ? ': $name' : ''}'),
                  subtitle: const Text('Нажмите чтобы отключиться'),
                  onTap: _disconnect,
                );
              } else {
                return const ListTile(
                  leading:
                      Icon(Icons.bluetooth_disabled, color: Colors.grey),
                  title: Text('Нет подключения'),
                );
              }
            },
          ),

          // ── Уведомления ──────────────────────────────────────
          const _SectionHeader('Уведомления'),
          SwitchListTile(
            secondary: const Icon(Icons.notifications_outlined),
            title: const Text('Уведомления о сообщениях'),
            value: _notificationsEnabled,
            onChanged: _setNotifications,
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
                  content:
                      Text('github.com/gazlevodiva/Meshly'),
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
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: Theme.of(context).colorScheme.primary,
          letterSpacing: 0.8,
        ),
      ),
    );
  }
}
