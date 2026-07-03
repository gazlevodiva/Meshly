import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Manages all notification preferences.
///
/// Extends ChangeNotifier so widgets can subscribe via ListenableBuilder
/// and rebuild automatically when any setting changes — no manual setState needed.
class NotificationSettings extends ChangeNotifier {
  NotificationSettings._();
  static final instance = NotificationSettings._();

  static const _keyEnabled = 'notif_enabled';
  static const _keyDms = 'notif_dms';
  static const _keyChannels = 'notif_channels';
  static const _keyMuted = 'notif_muted_convs';

  bool _enabled = true;
  bool _dmsEnabled = true;
  bool _channelsEnabled = true;
  final Set<String> _mutedConversations = {};

  bool get enabled => _enabled;
  bool get dmsEnabled => _dmsEnabled;
  bool get channelsEnabled => _channelsEnabled;
  Set<String> get mutedConversations => Set.unmodifiable(_mutedConversations);

  Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _enabled = prefs.getBool(_keyEnabled) ?? true;
      _dmsEnabled = prefs.getBool(_keyDms) ?? true;
      _channelsEnabled = prefs.getBool(_keyChannels) ?? true;
      final muted = prefs.getStringList(_keyMuted) ?? [];
      _mutedConversations
        ..clear()
        ..addAll(muted);
      notifyListeners();
    } on Exception catch (_) {
      // Keep defaults if SharedPreferences is unavailable.
    }
  }

  Future<void> setEnabled({required bool value}) async {
    if (_enabled == value) return;
    _enabled = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyEnabled, value);
  }

  Future<void> setDmsEnabled({required bool value}) async {
    if (_dmsEnabled == value) return;
    _dmsEnabled = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyDms, value);
  }

  Future<void> setChannelsEnabled({required bool value}) async {
    if (_channelsEnabled == value) return;
    _channelsEnabled = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyChannels, value);
  }

  Future<void> muteConversation(String convId) async {
    if (_mutedConversations.contains(convId)) return;
    _mutedConversations.add(convId);
    notifyListeners();
    await _saveMuted();
  }

  Future<void> unmuteConversation(String convId) async {
    if (!_mutedConversations.contains(convId)) return;
    _mutedConversations.remove(convId);
    notifyListeners();
    await _saveMuted();
  }

  bool isMuted(String convId) => _mutedConversations.contains(convId);

  Future<void> _saveMuted() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_keyMuted, _mutedConversations.toList());
  }

  /// Returns true if a notification should be shown for this conversation.
  bool shouldNotify({required String convId, required bool isDm}) {
    if (!_enabled) return false;
    if (isDm && !_dmsEnabled) return false;
    if (!isDm && !_channelsEnabled) return false;
    if (_mutedConversations.contains(convId)) return false;
    return true;
  }

  /// For unit tests only: resets all in-memory state without touching SharedPreferences.
  void resetForTesting() {
    _enabled = true;
    _dmsEnabled = true;
    _channelsEnabled = true;
    _mutedConversations.clear();
    // No notifyListeners — tests don't need widget rebuilds.
  }
}
