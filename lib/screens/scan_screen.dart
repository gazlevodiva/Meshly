import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:meshly/l10n/l10n.dart';
import 'package:meshly/screens/main_screen.dart';
import 'package:meshly/services/mesh_service.dart';
import 'package:meshly/theme/app_theme.dart';
import 'package:meshly/widgets/sheet_drag_handle.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Known patterns in Meshtastic device names (popular boards and vendors).
/// The list is deliberately generous: better to show an extra device than
/// to filter out a real Meshtastic node with an atypical name.
const _meshtasticNamePatterns = <String>[
  'meshtastic',
  'heltec',
  't-beam',
  'tbeam',
  'rak',
  'lilygo',
  'station',
  'tracker',
  'sensor',
  'm5stack',
  'm5',
  'nano',
  'wismesh',
  'seeed',
  'xiao',
];

/// Pure, testable check: does this BLE device look like Meshtastic.
///
/// Positive signal — ANY of:
///  - the advertised service UUIDs include the Meshtastic service UUID
///    ([kMeshtasticServiceUuid]), compared case-insensitively;
///  - the name (lowercase) contains one of [_meshtasticNamePatterns].
///
/// An empty name with no service UUID match is discarded. The RSSI
/// catch-all was deliberately removed — it used to let through
/// headphones/TVs/watches.
bool isLikelyMeshtasticDevice({
  required String name,
  required List<String> serviceUuids,
}) {
  final target = kMeshtasticServiceUuid.toLowerCase();
  for (final u in serviceUuids) {
    if (u.toLowerCase().contains(target)) return true;
  }
  if (name.isEmpty) return false;
  final lower = name.toLowerCase();
  return _meshtasticNamePatterns.any(lower.contains);
}

class ScanScreen extends StatefulWidget {
  const ScanScreen({
    required this.meshService,
    this.isReconnect = false,
    this.autoConnect = true,
    super.key,
  });

  final MeshService meshService;
  final bool isReconnect;

  // Whether to try auto-connecting to the last device when the screen
  // opens. Disabled when navigating here after an INTENTIONAL disconnect,
  // otherwise the screen would immediately reconnect to the same device
  // (last_device_id is kept for the next launch, but a reconnect isn't
  // wanted right now).
  final bool autoConnect;

  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

enum _ScreenState { idle, autoConnecting, scanning, connecting }

class _ScanScreenState extends State<ScanScreen> {
  final Map<String, ScanResult> _resultsMap = {};
  _ScreenState _state = _ScreenState.idle;
  String? _connectingName;
  String? _lastDeviceName;

  // The actual Bluetooth adapter state. When it's off, we show a dedicated
  // screen with an enable button instead of a pointless scan into the void.
  BluetoothAdapterState _adapterState = BluetoothAdapterState.unknown;
  StreamSubscription<BluetoothAdapterState>? _adapterSub;

  // Escape hatch: by default the list is filtered down to Meshtastic
  // devices, but the user can show ALL devices — for a board with a
  // nonstandard/renamed name that doesn't advertise the service UUID.
  bool _showAllDevices = false;

  List<ScanResult> get _results =>
      _resultsMap.values.where(_isRelevant).toList()
        ..sort((a, b) => b.rssi.compareTo(a.rssi));

  bool _isRelevant(ScanResult r) {
    // In "show all" mode we only filter out nameless devices (there's no
    // way to tell what they are anyway).
    if (_showAllDevices) return r.device.platformName.isNotEmpty;
    return isLikelyMeshtasticDevice(
      name: r.device.platformName,
      serviceUuids: r.advertisementData.serviceUuids
          .map((g) => g.toString())
          .toList(),
    );
  }

  @override
  void initState() {
    super.initState();
    _adapterState = FlutterBluePlus.adapterStateNow;
    // onError silences the UnsupportedError from flutter_blue_plus without
    // a platform (widget tests): we stay on `unknown`, not monitoring the
    // adapter.
    _adapterSub = FlutterBluePlus.adapterState.listen(
      _onAdapterState,
      onError: (Object _) {},
    );
    // Don't start auto-connect when BT is known to be off — the user needs
    // to turn on the adapter first (see _onAdapterState). And don't start it
    // if the screen was opened after an intentional disconnect
    // (autoConnect=false).
    if (widget.autoConnect && _adapterState != BluetoothAdapterState.off) {
      unawaited(_tryAutoConnect());
    }
  }

  @override
  void dispose() {
    unawaited(_adapterSub?.cancel());
    super.dispose();
  }

  void _onAdapterState(BluetoothAdapterState s) {
    if (!mounted) return;
    final wasOff = _adapterState == BluetoothAdapterState.off;
    setState(() => _adapterState = s);
    // BT was just turned on from the "Bluetooth off" screen — resume
    // auto-connecting to the last device (if that's even allowed).
    if (widget.autoConnect &&
        wasOff &&
        s == BluetoothAdapterState.on &&
        _state == _ScreenState.idle) {
      unawaited(_tryAutoConnect());
    }
  }

  // Turn on Bluetooth. Android can show a system enable dialog; iOS
  // doesn't allow enabling BT programmatically — send the user to system
  // settings instead.
  Future<void> _enableBluetooth() async {
    if (Platform.isAndroid) {
      await Permission.bluetoothConnect.request();
      try {
        await FlutterBluePlus.turnOn();
      } on Exception {
        // The user declined or enabling failed — the screen stays in the
        // "off" state (the adapter didn't transition to on); the
        // _onAdapterState listener syncs the UI on any change.
      }
    } else {
      await openAppSettings();
    }
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
          SnackBar(content: Text(context.l10n.bluetoothPermissionNeeded)),
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

    unawaited(
      widget.meshService.scan().listen((results) {
        if (!mounted) return;
        setState(() {
          for (final r in results) {
            _resultsMap[r.device.remoteId.str] = r;
          }
        });
      }).asFuture(),
    );

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
          unawaited(
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (_) => MainScreen(meshService: widget.meshService),
              ),
            ),
          );
        }
      }
    } on Exception catch (e) {
      // The raw error (e.g. the list of discovered services when trying to
      // connect to a non-Meshtastic device) goes only to the developer log.
      // The user is shown a friendly, localized hint.
      debugPrint('[Scan] connect failed: $e');
      if (mounted) {
        setState(() => _state = _ScreenState.idle);
        unawaited(
          showDialog(
            context: context,
            builder: (dialogContext) => AlertDialog(
              title: Text(dialogContext.l10n.connectionErrorTitle),
              content: Text(dialogContext.l10n.notMeshtasticDevice),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: Text(dialogContext.l10n.ok),
                ),
              ],
            ),
          ),
        );
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

  Future<void> _showHelpSheet() async {
    final restart = await showModalBottomSheet<bool>(
      context: context,
      shape: AppShapes.bottomSheet,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.s24,
            AppSpacing.s12,
            AppSpacing.s24,
            AppSpacing.s24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SheetDragHandle(),
              Text(
                sheetContext.l10n.checkConnection,
                style: AppTextStyles.title,
              ),
              const SizedBox(height: AppSpacing.s16),
              _HelpTip(
                icon: Icons.power_settings_new,
                text: sheetContext.l10n.helpTipPoweredOn,
              ),
              _HelpTip(
                icon: Icons.bluetooth,
                text: sheetContext.l10n.helpTipBluetoothOn,
              ),
              _HelpTip(
                icon: Icons.near_me_outlined,
                text: sheetContext.l10n.helpTipKeepClose,
              ),
              _HelpTip(
                icon: Icons.restart_alt,
                text: sheetContext.l10n.helpTipRestart,
              ),
              const SizedBox(height: AppSpacing.s24),
              SizedBox(
                height: AppSizes.ctaHeight,
                child: FilledButton(
                  onPressed: () => Navigator.pop(sheetContext, true),
                  child: Text(sheetContext.l10n.searchAgain),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    if (restart == true && mounted) {
      await widget.meshService.stopScan();
      await _startScan();
    }
  }

  // ── Visual building blocks ──────────────────────────────────

  Widget _buildHero() {
    final primary = Theme.of(context).colorScheme.primary;
    Widget ring(double size, double alpha, Widget child) => Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: primary.withValues(alpha: alpha),
      ),
      child: Center(child: child),
    );

    return Center(
      child: ring(
        AppSizes.heroRingOuter,
        AppOpacities.ringOuter,
        ring(
          AppSizes.heroRingInner,
          AppOpacities.ringInner,
          Container(
            width: AppSizes.heroCircle,
            height: AppSizes.heroCircle,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Theme.of(context).colorScheme.primaryContainer,
            ),
            child: Icon(
              Icons.bluetooth,
              size: AppIconSizes.hero,
              color: primary,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTitle() {
    return Column(
      children: [
        const Text('Meshly', style: AppTextStyles.logo),
        const SizedBox(height: AppSpacing.s4),
        Text(
          context.l10n.appTagline,
          style: AppTextStyles.hint(context),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildInfoCard() {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.s14),
      decoration: BoxDecoration(
        color: scheme.surfaceContainer,
        borderRadius: BorderRadius.circular(AppRadius.cardLarge),
      ),
      child: Row(
        children: [
          _LeadingTile(icon: Icons.bluetooth, color: scheme.primary),
          const SizedBox(width: AppSpacing.s12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.l10n.connectToDeviceTitle,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: AppSpacing.s2),
                Text(
                  context.l10n.connectToDeviceHint,
                  style: AppTextStyles.subtitle(context),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCta() {
    final scanning = _state == _ScreenState.scanning;
    return SizedBox(
      width: double.infinity,
      height: AppSizes.ctaHeight,
      child: scanning
          ? FilledButton.tonalIcon(
              onPressed: _stopScan,
              icon: const Icon(Icons.stop),
              label: Text(context.l10n.stopScan),
            )
          : FilledButton.icon(
              onPressed: _startScan,
              icon: const Icon(Icons.bluetooth_searching),
              label: Text(context.l10n.findDevice),
            ),
    );
  }

  Widget _buildScanningHint() {
    final primary = Theme.of(context).colorScheme.primary;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        SizedBox(
          width: AppSizes.spinnerSmall,
          height: AppSizes.spinnerSmall,
          child: CircularProgressIndicator(
            strokeWidth: AppSizes.spinnerStroke,
            color: primary,
          ),
        ),
        const SizedBox(width: AppSpacing.s10),
        Text(
          context.l10n.scanningNearby,
          style: AppTextStyles.hint(context).copyWith(color: primary),
        ),
      ],
    );
  }

  Widget _buildDeviceCard(ScanResult r) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.s8),
      child: Material(
        color: scheme.surfaceContainer,
        borderRadius: BorderRadius.circular(AppRadius.cardLarge),
        child: InkWell(
          onTap: () => _connect(r),
          borderRadius: BorderRadius.circular(AppRadius.cardLarge),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.s12),
            child: Row(
              children: [
                _LeadingTile(
                  icon: Icons.router_outlined,
                  color: scheme.primary,
                ),
                const SizedBox(width: AppSpacing.s12),
                Expanded(
                  child: Text(
                    r.device.platformName,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: AppSpacing.s12),
                _SignalBars(rssi: r.rssi),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFooter() {
    return Column(
      children: [
        Text(
          context.l10n.deviceNotListed,
          style: AppTextStyles.subtitle(context),
        ),
        TextButton(
          onPressed: _showHelpSheet,
          child: Text(context.l10n.checkConnection),
        ),
        // Escape hatch: show all BLE devices, in case the wanted device
        // didn't pass the Meshtastic filter.
        TextButton(
          onPressed: () => setState(() => _showAllDevices = !_showAllDevices),
          child: Text(
            _showAllDevices
                ? context.l10n.showMeshtasticOnly
                : context.l10n.showAllDevices,
          ),
        ),
      ],
    );
  }

  // ── States ──────────────────────────────────────────────────

  Widget _buildMain({required bool scanning}) {
    final results = _results;
    // Once the search finishes, the found devices stay on screen so
    // scanning doesn't have to be restarted.
    final showDevices = scanning || results.isNotEmpty;
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s24),
      children: [
        const SizedBox(height: AppSpacing.s40),
        _buildHero(),
        const SizedBox(height: AppSpacing.s20),
        _buildTitle(),
        const SizedBox(height: AppSpacing.s28),
        _buildInfoCard(),
        const SizedBox(height: AppSpacing.s16),
        _buildCta(),
        if (scanning) ...[
          const SizedBox(height: AppSpacing.s16),
          _buildScanningHint(),
        ],
        if (showDevices) ...[
          const SizedBox(height: AppSpacing.s24),
          Text(
            context.l10n.availableDevices,
            style: AppTextStyles.sectionHeader.copyWith(
              color: context.appColors.textSecondary,
            ),
          ),
          const SizedBox(height: AppSpacing.s12),
          if (results.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.s16),
              child: Text(
                context.l10n.searchingMeshtastic,
                style: AppTextStyles.secondary(context),
                textAlign: TextAlign.center,
              ),
            )
          else
            ...results.map(_buildDeviceCard),
        ],
        const SizedBox(height: AppSpacing.s16),
        _buildFooter(),
        const SizedBox(height: AppSpacing.s24),
      ],
    );
  }

  Widget _buildAutoConnecting() {
    return _buildConnectingBody(
      label: context.l10n.connectingTo(_lastDeviceName ?? ''),
      trailing: TextButton(
        onPressed: _cancelAutoConnect,
        child: Text(context.l10n.otherDevice),
      ),
    );
  }

  Widget _buildConnecting() {
    return _buildConnectingBody(
      label: context.l10n.connectingTo(_connectingName ?? ''),
      // A manual connection from the list is usually the first pairing
      // with the device, so we remind about the system pairing-code
      // prompt.
      showPairingHint: true,
    );
  }

  // Pairing hint: the code entry field is drawn by the OS (it can't be
  // replaced with a custom one), but the user might dismiss the system
  // prompt — it also arrives as a notification. We explain where to get the
  // code and where to look.
  Widget _buildPairingHint() {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.s14),
      decoration: BoxDecoration(
        color: scheme.surfaceContainer,
        borderRadius: BorderRadius.circular(AppRadius.cardLarge),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _LeadingTile(icon: Icons.pin, color: scheme.primary),
          const SizedBox(width: AppSpacing.s12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.l10n.pairingHintTitle,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: AppSpacing.s2),
                Text(
                  context.l10n.pairingHintBody,
                  style: AppTextStyles.subtitle(context),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBluetoothOff() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildHero(),
            const SizedBox(height: AppSpacing.s20),
            _buildTitle(),
            const SizedBox(height: AppSpacing.s32),
            Text(
              context.l10n.bluetoothOffTitle,
              style: AppTextStyles.title,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.s8),
            Text(
              context.l10n.bluetoothOffHint,
              style: AppTextStyles.hint(context),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.s24),
            SizedBox(
              width: double.infinity,
              height: AppSizes.ctaHeight,
              child: FilledButton.icon(
                onPressed: _enableBluetooth,
                icon: const Icon(Icons.bluetooth),
                label: Text(
                  Platform.isAndroid
                      ? context.l10n.enableBluetooth
                      : context.l10n.openSettings,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildConnectingBody({
    required String label,
    Widget? trailing,
    bool showPairingHint = false,
  }) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildHero(),
            const SizedBox(height: AppSpacing.s20),
            _buildTitle(),
            const SizedBox(height: AppSpacing.s32),
            const CircularProgressIndicator(),
            const SizedBox(height: AppSpacing.s16),
            Text(
              label,
              style: AppTextStyles.hint(context),
              textAlign: TextAlign.center,
            ),
            if (showPairingHint) ...[
              const SizedBox(height: AppSpacing.s24),
              _buildPairingHint(),
            ],
            if (trailing != null) ...[
              const SizedBox(height: AppSpacing.s16),
              trailing,
            ],
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    Widget body;
    if (_adapterState == BluetoothAdapterState.off) {
      // Bluetooth being off overrides any scan/connect state.
      body = _buildBluetoothOff();
    } else {
      switch (_state) {
        case _ScreenState.idle:
          body = _buildMain(scanning: false);
        case _ScreenState.autoConnecting:
          body = _buildAutoConnecting();
        case _ScreenState.scanning:
          body = _buildMain(scanning: true);
        case _ScreenState.connecting:
          body = _buildConnecting();
      }
    }

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [scheme.surfaceContainerLowest, scheme.surface],
          ),
        ),
        child: SafeArea(child: body),
      ),
    );
  }
}

// ── Small building blocks ─────────────────────────────────────

/// Rounded-square leading tile (48x48) with a centered icon.
class _LeadingTile extends StatelessWidget {
  const _LeadingTile({required this.icon, required this.color});

  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: AppSizes.leadingTile,
      height: AppSizes.leadingTile,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(AppRadius.card),
      ),
      child: Icon(icon, size: AppIconSizes.nav, color: color),
    );
  }
}

/// Four ascending signal bars; lit count and color depend on RSSI.
class _SignalBars extends StatelessWidget {
  const _SignalBars({required this.rssi});

  final int rssi;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final active = rssi > -70
        ? 4
        : rssi > -78
        ? 3
        : rssi > -85
        ? 2
        : 1;
    final color = active == 4
        ? colors.online
        : active == 1
        ? colors.danger
        : colors.warning;
    final inactive = Theme.of(context).colorScheme.outlineVariant;

    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        for (var i = 0; i < 4; i++) ...[
          if (i > 0) const SizedBox(width: AppSizes.signalBarGap),
          Container(
            width: AppSizes.signalBarWidth,
            height: AppSizes.signalBarMinHeight + i * AppSizes.signalBarStep,
            decoration: BoxDecoration(
              color: i < active ? color : inactive,
              borderRadius: BorderRadius.circular(AppRadius.handle),
            ),
          ),
        ],
      ],
    );
  }
}

/// One line in the "check the connection" help sheet.
class _HelpTip extends StatelessWidget {
  const _HelpTip({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.s6),
      child: Row(
        children: [
          Icon(
            icon,
            size: AppIconSizes.signal,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(width: AppSpacing.s12),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }
}
