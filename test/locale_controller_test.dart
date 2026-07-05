import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meshly/services/locale_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  final controller = LocaleController.instance;

  setUp(() async {
    // Order matters: clear the mock store first, then reset in-memory state,
    // then load — so each test starts from a clean slate.
    SharedPreferences.setMockInitialValues({});
    controller.resetForTesting();
    await controller.load();
  });

  group('LocaleController — defaults', () {
    test('locale is null (system) after load with empty prefs', () {
      expect(controller.locale, isNull);
    });

    test('load falls back to system on unknown stored value', () async {
      SharedPreferences.setMockInitialValues({'locale_v1': 'de'});
      controller.resetForTesting();
      await controller.load();
      expect(controller.locale, isNull);
    });

    test('load treats stored "system" as null', () async {
      SharedPreferences.setMockInitialValues({'locale_v1': 'system'});
      controller.resetForTesting();
      await controller.load();
      expect(controller.locale, isNull);
    });
  });

  group('LocaleController — setLocale', () {
    test('updates locale', () async {
      await controller.setLocale(const Locale('en'));
      expect(controller.locale, const Locale('en'));
    });

    test('null switches back to system', () async {
      await controller.setLocale(const Locale('ru'));
      await controller.setLocale(null);
      expect(controller.locale, isNull);
    });

    test('notifies listeners', () async {
      var notified = 0;
      void listener() => notified++;
      controller.addListener(listener);
      addTearDown(() => controller.removeListener(listener));

      await controller.setLocale(const Locale('ru'));
      expect(notified, 1);
    });

    test('is a no-op (no notify) when locale is unchanged', () async {
      var notified = 0;
      void listener() => notified++;
      controller.addListener(listener);
      addTearDown(() => controller.removeListener(listener));

      await controller.setLocale(null); // already system
      expect(notified, 0);
      expect(controller.locale, isNull);
    });

    test('persists to SharedPreferences', () async {
      await controller.setLocale(const Locale('en'));

      controller.resetForTesting();
      expect(controller.locale, isNull);

      await controller.load();
      expect(controller.locale, const Locale('en'));
    });

    test('persists "system" for null locale', () async {
      await controller.setLocale(const Locale('en'));
      await controller.setLocale(null);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('locale_v1'), 'system');

      controller.resetForTesting();
      await controller.load();
      expect(controller.locale, isNull);
    });
  });

  group('LocaleController — load', () {
    test('restores Russian locale from prefs', () async {
      SharedPreferences.setMockInitialValues({'locale_v1': 'ru'});
      controller.resetForTesting();
      await controller.load();
      expect(controller.locale, const Locale('ru'));
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
