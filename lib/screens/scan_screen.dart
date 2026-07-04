import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:meshly/screens/main_screen.dart';
import 'package:meshly/services/mesh_service.dart';
import 'package:meshly/theme/app_theme.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ScanScreen extends StatefulWidget {
  const ScanScreen({
    required this.meshService,
    this.isReconnect = false,
    super.key,
  });

  final MeshService meshService;
  final bool isReconnect;

  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

enum _ScreenState { idle, autoConnecting, scanning, connecting }

class _ScanScreenState extends State<ScanScreen> {
  final Map<String, ScanResult> _resultsMap = {};
  _ScreenState _state = _ScreenState.idle;
  String? _connectingName;
  String? _lastDeviceName;

  List<ScanResult> get _results => _resultsMap.values.where(_isRelevant).toList()
    ..sort((a, b) => b.rssi.compareTo(a.rssi));

  bool _isRelevant(ScanResult r) {
    if (r.device.platformName.isEmpty) return false;
    final name = r.device.platformName.toLowerCase();
    if (name.contains('meshtastic') ||
        name.contains('heltec') ||
        name.contains('t-beam') ||
        name.contains('rak')) {
      return true;
    }
    return r.rssi > -90;
  }

  @override
  void initState() {
    super.initState();
    unawaited(_tryAutoConnect());
  }

  Future<void> _tryAutoConnect() async {
    final prefs = await SharedPreferences.getInstance();
    final lastId = prefs.getString('last_device_id');
    final lastName = prefs.getString('last_device_name');
    if (lastId == null || !mounted) return;

    setState(() {
      _state = _ScreenState.autoConnecting;
      _lastDeviceName = lastName ?? lastId;
    });

    // Request permissions first
    final status = await [
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
    ].request();
    if (status.values.any((s) => s.isDenied)) {
      if (mounted) setState(() => _state = _ScreenState.idle);
      return;
    }

    // Scan for up to 10 seconds to find the device
    var found = false;
    final subscription = widget.meshService.scan().listen((results) {
      for (final r in results) {
        if (r.device.remoteId.str == lastId) found = true;
        if (mounted) setState(() => _resultsMap[r.device.remoteId.str] = r);
      }
    });

    try {
      await Future<void>.delayed(const Duration(seconds: 10));
    } finally {
      await widget.meshService.stopScan();
      await subscription.cancel();
    }

    if (!mounted) return;

    if (found) {
      final target = _resultsMap[lastId];
      if (target != null) {
        setState(() {
          _state = _ScreenState.connecting;
          _connectingName = target.device.platformName.isNotEmpty
              ? target.device.platformName
              : lastId;
        });
        await _connectDevice(target.device);
        return;
      }
    }

    // Device not found
    if (mounted) setState(() => _state = _ScreenState.idle);
  }

  Future<void> _requestPermissions() async {
    final status = await [
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
    ].request();
    if (status.values.any((s) => s.isDenied)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Нужен доступ к Bluetooth')),
        );
      }
    }
  }

  Future<void> _startScan() async {
    await _requestPermissions();

    setState(() {
      _state = _ScreenState.scanning;
      _resultsMap.clear();
    });

    unawaited(widget.meshService.scan().listen((results) {
      if (!mounted) return;
      setState(() {
        for (final r in results) {
          _resultsMap[r.device.remoteId.str] = r;
        }
      });
    }).asFuture());

    await Future<void>.delayed(const Duration(seconds: 10));
    await widget.meshService.stopScan();
    if (mounted) setState(() => _state = _ScreenState.idle);
  }

  Future<void> _stopScan() async {
    await widget.meshService.stopScan();
    if (mounted) setState(() => _state = _ScreenState.idle);
  }

  Future<void> _connect(ScanResult result) async {
    if (_state == _ScreenState.connecting) return;
    setState(() {
      _state = _ScreenState.connecting;
      _connectingName = result.device.platformName.isNotEmpty
          ? result.device.platformName
          : result.device.remoteId.str;
    });
    await _connectDevice(result.device);
  }

  Future<void> _connectDevice(BluetoothDevice device) async {
    try {
      await widget.meshService.connect(device);

      // Save last connected device
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('last_device_id', device.remoteId.str);
      await prefs.setString('last_device_name', device.platformName);

      if (mounted) {
        if (widget.isReconnect) {
          Navigator.pop(context);
        } else {
          unawaited(Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) => MainScreen(meshService: widget.meshService),
            ),
          ));
        }
      }
    } on Exception catch (e) {
      if (mounted) {
        setState(() => _state = _ScreenState.idle);
        unawaited(showDialog(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text('Ошибка подключения'),
            content: Text(e.toString().replaceFirst('Exception: ', '')),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('OK'),
              ),
            ],
          ),
        ));
      }
    }
  }

  Future<void> _cancelAutoConnect() async {
    await widget.meshService.stopScan();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('last_device_id');
    await prefs.remove('last_device_name');
    if (mounted) {
      setState(() {
        _state = _ScreenState.idle;
        _lastDeviceName = null;
        _resultsMap.clear();
      });
    }
  }

  Widget _signalIcon(int rssi) {
    final color = rssi > -70
        ? AppColors.online
        : rssi > -85
            ? AppColors.warning
            : AppColors.danger;
    return Icon(Icons.signal_cellular_alt,
        color: color, size: AppIconSizes.signal);
  }

  Widget _buildHeader() {
    return const Column(
      children: [
        Icon(Icons.bluetooth, size: AppIconSizes.hero, color: AppColors.brand),
        SizedBox(height: AppSpacing.s12),
        Text(
          'Meshly',
          style: AppTextStyles.logo,
        ),
        SizedBox(height: AppSpacing.s4),
        Text(
          'Mesh messenger for people you trust',
          style: AppTextStyles.hint,
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildIdle() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildHeader(),
            const SizedBox(height: AppSpacing.s32),
            const Text(
              'Включите Bluetooth и держите Meshtastic-устройство рядом',
              style: AppTextStyles.hint,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.s24),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _startScan,
                icon: const Icon(Icons.bluetooth_searching),
                label: const Text('Найти устройство'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAutoConnecting() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildHeader(),
            const SizedBox(height: AppSpacing.s32),
            const CircularProgressIndicator(),
            const SizedBox(height: AppSpacing.s16),
            Text(
              'Подключение к ${_lastDeviceName ?? ''}...',
              style: AppTextStyles.hint,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.s16),
            TextButton(
              onPressed: _cancelAutoConnect,
              child: const Text('Другое устройство'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildScanning() {
    final results = _results;
    return Column(
      children: [
        const SizedBox(height: AppSpacing.s48),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s32),
          child: _buildHeader(),
        ),
        const SizedBox(height: AppSpacing.s24),
        const CircularProgressIndicator(),
        const SizedBox(height: AppSpacing.s8),
        const Text('Поиск устройств...', style: AppTextStyles.secondary),
        const SizedBox(height: AppSpacing.s16),
        Expanded(
          child: results.isEmpty
              ? const Center(
                  child: Text(
                    'Ищем Meshtastic-устройства...',
                    style: AppTextStyles.secondary,
                    textAlign: TextAlign.center,
                  ),
                )
              : ListView.builder(
                  itemCount: results.length,
                  itemBuilder: (_, i) {
                    final r = results[i];
                    return ListTile(
                      leading: Icon(
                        Icons.bluetooth,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      title: Text(r.device.platformName),
                      trailing: _signalIcon(r.rssi),
                      onTap: () => _connect(r),
                    );
                  },
                ),
        ),
        Padding(
          padding: const EdgeInsets.all(AppSpacing.s16),
          child: OutlinedButton(
            onPressed: _stopScan,
            child: const Text('Остановить'),
          ),
        ),
      ],
    );
  }

  Widget _buildConnecting() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildHeader(),
            const SizedBox(height: AppSpacing.s32),
            const CircularProgressIndicator(),
            const SizedBox(height: AppSpacing.s16),
            Text(
              'Подключение к ${_connectingName ?? ''}...',
              style: AppTextStyles.hint,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    Widget body;
    switch (_state) {
      case _ScreenState.idle:
        body = _buildIdle();
      case _ScreenState.autoConnecting:
        body = _buildAutoConnecting();
      case _ScreenState.scanning:
        body = _buildScanning();
      case _ScreenState.connecting:
        body = _buildConnecting();
    }

    return Scaffold(
      body: SafeArea(child: body),
    );
  }
}
