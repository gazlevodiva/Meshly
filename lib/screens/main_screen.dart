import 'package:flutter/material.dart';
import 'package:meshly/screens/contacts_screen.dart';
import 'package:meshly/screens/home_screen.dart';
import 'package:meshly/screens/settings_screen.dart';
import 'package:meshly/services/mesh_service.dart';
import 'package:meshly/widgets/floating_nav_bar.dart';

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
