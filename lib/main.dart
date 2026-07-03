import 'package:flutter/material.dart';
import 'package:meshly/screens/scan_screen.dart';
import 'package:meshly/services/contact_store.dart';
import 'package:meshly/services/mesh_service.dart';
import 'package:meshly/services/notification_service.dart';
import 'package:meshly/services/notification_settings.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await ContactStore.instance.init();
  await NotificationSettings.instance.load();
  await NotificationService.instance.init();
  await NotificationService.instance.requestPermissions();
  runApp(const MeshlyApp());
}

class MeshlyApp extends StatefulWidget {
  const MeshlyApp({super.key});

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
      theme: ThemeData(
        colorSchemeSeed: Colors.blue,
        useMaterial3: true,
      ),
      home: ScanScreen(meshService: _meshService),
    );
  }
}
