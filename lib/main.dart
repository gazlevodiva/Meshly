import 'package:flutter/material.dart';
import 'package:meshly/screens/onboarding_screen.dart';
import 'package:meshly/screens/scan_screen.dart';
import 'package:meshly/services/contact_store.dart';
import 'package:meshly/services/mesh_service.dart';
import 'package:meshly/services/notification_service.dart';
import 'package:meshly/services/notification_settings.dart';
import 'package:meshly/theme/app_theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await ContactStore.instance.init();
  await NotificationSettings.instance.load();
  await NotificationService.instance.init();
  await NotificationService.instance.requestPermissions();
  final prefs = await SharedPreferences.getInstance();
  final onboardingDone = prefs.getBool('onboarding_done_v1') ?? false;
  runApp(MeshlyApp(onboardingDone: onboardingDone));
}

class MeshlyApp extends StatefulWidget {
  const MeshlyApp({required this.onboardingDone, super.key});

  final bool onboardingDone;

  @override
  State<MeshlyApp> createState() => _MeshlyAppState();
}

class _MeshlyAppState extends State<MeshlyApp> {
  final _meshService = MeshService();

  @override
  void dispose() {
    _meshService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Meshly',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      home: widget.onboardingDone
          ? ScanScreen(meshService: _meshService)
          : OnboardingScreen(meshService: _meshService),
    );
  }
}
