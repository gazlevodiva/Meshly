import 'package:flutter/material.dart';
import 'screens/scan_screen.dart';
import 'services/contact_store.dart';
import 'services/mesh_service.dart';
import 'services/notification_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await ContactStore.instance.init();
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
