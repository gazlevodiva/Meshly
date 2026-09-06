import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Manages the app locale (system / Russian / English).
///
/// Extends ChangeNotifier so widgets can subscribe via ListenableBuilder
/// and rebuild automatically when the locale changes — no manual setState
/// needed. A null [locale] means "follow the system locale".
class LocaleController extends ChangeNotifier {
  LocaleController._();
  static final instance = LocaleController._();

  static const _keyLocale = 'locale_v1';
  static const _systemValue = 'system';

  /// Language codes the app ships translations for (see lib/l10n).
  static const supportedLanguageCodes = ['ru', 'en'];

  Locale? _locale;

  /// The forced app locale, or null to follow the system.
  Locale? get locale => _locale;

  /// Restores the persisted locale. Called in main() before runApp.
  Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final stored = prefs.getString(_keyLocale);
      _locale = (stored != null && supportedLanguageCodes.contains(stored))
          ? Locale(stored)
          : null;
      notifyListeners();
    } on Exception catch (_) {
      // Keep the default if SharedPreferences is unavailable.
    }
  }

  /// Sets the app locale; null means "follow the system".
  Future<void> setLocale(Locale? locale) async {
    if (_locale == locale) return;
    final previous = _locale;
    _locale = locale;
    // Persist first — if save fails, roll back and don't notify UI,
    // so in-memory and on-disk state stay consistent.
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_keyLocale, locale?.languageCode ?? _systemValue);
    } on Exception catch (_) {
      _locale = previous;
      return;
    }
    notifyListeners();
  }

  /// For unit tests only: resets in-memory state without touching SharedPreferences.
  void resetForTesting() {
    _locale = null;
    // No notifyListeners — tests don't need widget rebuilds.
  }
}
