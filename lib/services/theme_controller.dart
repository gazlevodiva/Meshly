import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Manages the app theme mode (system / light / dark).
///
/// Extends ChangeNotifier so widgets can subscribe via ListenableBuilder
/// and rebuild automatically when the mode changes — no manual setState needed.
class ThemeController extends ChangeNotifier {
  ThemeController._();
  static final instance = ThemeController._();

  static const _keyMode = 'theme_mode_v1';

  ThemeMode _mode = ThemeMode.system;

  ThemeMode get mode => _mode;

  /// Restores the persisted mode. Called in main() before runApp.
  Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final stored = prefs.getString(_keyMode);
      _mode = ThemeMode.values.firstWhere(
        (m) => m.name == stored,
        orElse: () => ThemeMode.system,
      );
      notifyListeners();
    } on Exception catch (_) {
      // Keep the default if SharedPreferences is unavailable.
    }
  }

  Future<void> setMode(ThemeMode mode) async {
    if (_mode == mode) return;
    final previous = _mode;
    _mode = mode;
    // Persist first — if save fails, roll back and don't notify UI,
    // so in-memory and on-disk state stay consistent.
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_keyMode, mode.name);
    } on Exception catch (_) {
      _mode = previous;
      return;
    }
    notifyListeners();
  }

  /// For unit tests only: resets in-memory state without touching SharedPreferences.
  void resetForTesting() {
    _mode = ThemeMode.system;
    // No notifyListeners — tests don't need widget rebuilds.
  }
}
