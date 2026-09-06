import 'dart:async';

import 'package:flutter/material.dart';
import 'package:meshly/screens/contacts_screen.dart';
import 'package:meshly/screens/home_screen.dart';
import 'package:meshly/screens/settings_screen.dart';
import 'package:meshly/services/mesh_service.dart';
import 'package:meshly/services/notification_service.dart';
import 'package:meshly/widgets/floating_nav_bar.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({required this.meshService, super.key});

  final MeshService meshService;

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _index = 0;

  /// Whether the notification permission has already been asked for in this
  /// process. Static because the screen is rebuilt on reconnect, and the OS
  /// dialog must not reappear each time.
  static bool _askedForNotifications = false;

  @override
  void initState() {
    super.initState();
    // Asked here rather than in `main()`: reaching this screen means the
    // device is connected and messages can actually arrive, so the request
    // has a visible reason behind it. Before `runApp` it landed on a person
    // who had not yet seen the app, and on Android a permission denied that
    // early cannot be asked for again.
    if (!_askedForNotifications) {
      _askedForNotifications = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        unawaited(NotificationService.instance.requestPermissions());
      });
    }
  }

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
            child: FloatingNavBar(
              currentIndex: _index,
              onTap: (i) => setState(() => _index = i),
            ),
          ),
        ],
      ),
    );
  }
}
