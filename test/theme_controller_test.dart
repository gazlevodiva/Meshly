import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meshly/services/theme_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  final controller = ThemeController.instance;

  setUp(() async {
    // Order matters: clear the mock store first, then reset in-memory state,
    // then load — so each test starts from a clean slate.
    SharedPreferences.setMockInitialValues({});
    controller.resetForTesting();
    await controller.load();
  });

  group('ThemeController — defaults', () {
    test('mode is system after load with empty prefs', () {
      expect(controller.mode, ThemeMode.system);
    });

    test('load falls back to system on unknown stored value', () async {
      SharedPreferences.setMockInitialValues({'theme_mode_v1': 'neon'});
      controller.resetForTesting();
      await controller.load();
      expect(controller.mode, ThemeMode.system);
    });
  });

  group('ThemeController — setMode', () {
    test('updates mode', () async {
      await controller.setMode(ThemeMode.dark);
      expect(controller.mode, ThemeMode.dark);
    });

    test('notifies listeners', () async {
      var notified = 0;
      void listener() => notified++;
      controller.addListener(listener);
      addTearDown(() => controller.removeListener(listener));

      await controller.setMode(ThemeMode.light);
      expect(notified, 1);
    });

    test('is a no-op (no notify) when mode is unchanged', () async {
      var notified = 0;
      void listener() => notified++;
      controller.addListener(listener);
      addTearDown(() => controller.removeListener(listener));

      await controller.setMode(ThemeMode.system); // already system
      expect(notified, 0);
      expect(controller.mode, ThemeMode.system);
    });

    test('persists to SharedPreferences', () async {
      await controller.setMode(ThemeMode.dark);

      controller.resetForTesting();
      expect(controller.mode, ThemeMode.system);

      await controller.load();
      expect(controller.mode, ThemeMode.dark);
    });
  });

  group('ThemeController — load', () {
    test('restores light mode from prefs', () async {
      SharedPreferences.setMockInitialValues({'theme_mode_v1': 'light'});
      controller.resetForTesting();
      await controller.load();
      expect(controller.mode, ThemeMode.light);
    });

    test('load notifies listeners', () async {
      var notified = 0;
      void listener() => notified++;
      controller.addListener(listener);
      addTearDown(() => controller.removeListener(listener));

      await controller.load();
      expect(notified, 1);
    });
  });
}
