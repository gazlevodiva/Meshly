import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meshly/l10n/app_localizations.dart';
import 'package:meshly/screens/home_screen.dart';
import 'package:meshly/screens/radio_region_screen.dart';
import 'package:meshly/screens/settings_screen.dart';
import 'package:meshly/services/app_database.dart'
    hide Channel, Contact, Conversation, Message;
import 'package:meshly/services/contact_store.dart';
import 'package:meshly/services/lora_region.dart';
import 'package:meshly/services/mesh_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  final store = ContactStore.instance;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    store.resetForTesting(AppDatabase.forTesting(NativeDatabase.memory()));
    await store.init();
  });

  Widget wrap(Widget child) {
    return MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: const Locale('ru'),
      home: child,
    );
  }

  /// Substitutes the platform locale (the phone's country), which
  /// [LoraRegion.suggestedFor]'s suggestion depends on, and removes the
  /// substitution after the test.
  void setPlatformCountry(WidgetTester tester, String? countryCode) {
    final dispatcher = tester.binding.platformDispatcher
      ..localeTestValue = countryCode == null
          ? const Locale('en')
          : Locale('en', countryCode);
    addTearDown(dispatcher.clearLocaleTestValue);
  }

  /// The list is a `ListView`, so items below the first screen are not
  /// built until scrolled into view.
  Future<void> scrollToText(WidgetTester tester, String text) async {
    final finder = find.text(text);
    await tester.scrollUntilVisible(
      finder,
      400,
      scrollable: find.byType(Scrollable).first,
    );
    // scrollUntilVisible stops as soon as the widget is BUILT, and the list
    // also builds what lies beyond the screen edge (cacheExtent). Without
    // ensureVisible the widget can be found but not visible — and a tap on
    // it misses the screen. The test must not depend on how many pixels
    // below the screen the card ended up.
    await tester.ensureVisible(finder);
    await tester.pumpAndSettle();
  }

  group('RadioRegionScreen — one-tap suggestion', () {
    testWidgets('a suggestion is present — one confirm button is shown', (
      tester,
    ) async {
      setPlatformCountry(tester, 'US'); // suggestedFor('US') -> 'US'
      final mesh = MeshService();
      await tester.pumpWidget(wrap(RadioRegionScreen(meshService: mesh)));
      await tester.pump();

      final l10n = await AppLocalizations.delegate.load(const Locale('ru'));
      expect(find.text(l10n.radioRegionSuggestBody('US')), findsOneWidget);
      expect(
        find.widgetWithText(FilledButton, l10n.radioRegionSuggestConfirm),
        findsOneWidget,
      );
      // The full list is not shown yet.
      expect(find.text(l10n.radioRegionAll), findsNothing);
    });

    testWidgets('confirming the suggestion leads to the regular dialog', (
      tester,
    ) async {
      setPlatformCountry(tester, 'US');
      final mesh =
          MeshService(); // config hasn't arrived — setRegion will return false
      await tester.pumpWidget(wrap(RadioRegionScreen(meshService: mesh)));
      await tester.pump();

      final l10n = await AppLocalizations.delegate.load(const Locale('ru'));
      await tester.tap(
        find.widgetWithText(FilledButton, l10n.radioRegionSuggestConfirm),
      );
      await tester.pumpAndSettle();

      // The confirmation sheet with the region code opened.
      expect(find.text('US'), findsWidgets);
      await tester.tap(
        find.widgetWithText(FilledButton, l10n.radioRegionChoose),
      );
      await tester.pumpAndSettle();

      expect(find.text(l10n.radioRegionFailed), findsOneWidget);
    });

    testWidgets('"choose a different region" opens the full list', (
      tester,
    ) async {
      setPlatformCountry(tester, 'US');
      final mesh = MeshService();
      await tester.pumpWidget(wrap(RadioRegionScreen(meshService: mesh)));
      await tester.pump();

      final l10n = await AppLocalizations.delegate.load(const Locale('ru'));
      await tester.tap(find.text(l10n.radioRegionSuggestOther));
      await tester.pumpAndSettle();

      await scrollToText(tester, l10n.radioRegionAll);
      expect(find.text(l10n.radioRegionAll), findsOneWidget);
      expect(find.text('EU_868'), findsWidgets);
    });

    testWidgets('no unambiguous suggestion — full list right away', (
      tester,
    ) async {
      // Kazakhstan is deliberately not in the suggestion table (two equally valid codes).
      setPlatformCountry(tester, 'KZ');
      final mesh = MeshService();
      await tester.pumpWidget(wrap(RadioRegionScreen(meshService: mesh)));
      await tester.pump();

      final l10n = await AppLocalizations.delegate.load(const Locale('ru'));
      expect(
        find.widgetWithText(FilledButton, l10n.radioRegionSuggestConfirm),
        findsNothing,
      );
      await scrollToText(tester, l10n.radioRegionAll);
      expect(find.text(l10n.radioRegionAll), findsOneWidget);
      expect(find.text('EU_868'), findsWidgets);
    });
  });

  group('RadioRegionScreen — full list', () {
    testWidgets('the current region is marked with a checkmark', (
      tester,
    ) async {
      setPlatformCountry(tester, null);
      final mesh = MeshService();
      mesh.loraRegion.value = LoraRegion.common[0].value; // EU_868
      await tester.pumpWidget(wrap(RadioRegionScreen(meshService: mesh)));
      await tester.pump();

      final tile = find.widgetWithText(ListTile, 'EU_868').first;
      final listTile = tester.widget<ListTile>(tile);
      expect(listTile.trailing, isA<Icon>());
      expect((listTile.trailing! as Icon).icon, Icons.check);
    });

    Future<MeshService> pumpWithEu868(WidgetTester tester) async {
      final mesh = MeshService();
      // The region is already set (EU_868, range 868) — the screen opens
      // straight to the full list, not the suggestion.
      mesh.loraRegion.value = LoraRegion.common[0].value; // EU_868
      await tester.pumpWidget(wrap(RadioRegionScreen(meshService: mesh)));
      await tester.pump();
      return mesh;
    }

    testWidgets('"All regions" does not contain an incompatible range', (
      tester,
    ) async {
      setPlatformCountry(tester, null);
      await pumpWithEu868(tester);

      final l10n = await AppLocalizations.delegate.load(const Locale('ru'));

      // "All regions" (compatible, range 868) does not contain 'US'
      // (range 915) — it is filtered into a separate section below.
      await scrollToText(tester, l10n.radioRegionAll);
      final allSection = find
          .ancestor(
            of: find.text(l10n.radioRegionAll),
            matching: find.byType(Column),
          )
          .first;
      expect(
        find.descendant(of: allSection, matching: find.text('US')),
        findsNothing,
      );
    });

    testWidgets('incompatible range — a separate section with a warning', (
      tester,
    ) async {
      setPlatformCountry(tester, null);
      await pumpWithEu868(tester);

      final l10n = await AppLocalizations.delegate.load(const Locale('ru'));

      // The "Other range" section with the warning contains 'US'.
      // We scroll to the section heading, not to the warning text: the
      // heading is the lowest of the widgets being checked (after it the
      // ListView has only the list itself), so its visibility does not
      // depend on how many rows are above it (in "Frequent" or "All
      // regions").
      // We check the heading and the warning one after another: in a long
      // list they don't have to both fit on screen at the same time, and
      // the list doesn't build invisible elements.
      await scrollToText(tester, l10n.radioRegionIncompatibleWarning);
      expect(find.text(l10n.radioRegionIncompatibleWarning), findsOneWidget);

      await scrollToText(tester, l10n.radioRegionIncompatibleSection);
      expect(find.text(l10n.radioRegionIncompatibleSection), findsOneWidget);
      final incompatibleSection = find
          .ancestor(
            of: find.text(l10n.radioRegionIncompatibleSection),
            matching: find.byType(Column),
          )
          .first;
      expect(
        find.descendant(of: incompatibleSection, matching: find.text('US')),
        findsOneWidget,
      );
    });

    testWidgets(
      'changing an already-set region warns about losing connection',
      (
        tester,
      ) async {
        setPlatformCountry(tester, null);
        final mesh = MeshService();
        mesh.loraRegion.value = LoraRegion.common[0].value; // EU_868 is set
        await tester.pumpWidget(wrap(RadioRegionScreen(meshService: mesh)));
        await tester.pump();

        final l10n = await AppLocalizations.delegate.load(const Locale('ru'));
        // RU (868) — a compatible region, different from the current EU_868.
        await tester.tap(find.widgetWithText(ListTile, 'RU').first);
        await tester.pumpAndSettle();

        expect(find.text(l10n.radioRegionChangeWarning), findsOneWidget);
      },
    );

    testWidgets(
      'a failed attempt to apply a region shows an error',
      (tester) async {
        setPlatformCountry(
          tester,
          'KZ',
        ); // no suggestion — straight to the list
        final mesh =
            MeshService(); // config hasn't arrived — setRegion will return false
        await tester.pumpWidget(wrap(RadioRegionScreen(meshService: mesh)));
        await tester.pump();

        final l10n = await AppLocalizations.delegate.load(const Locale('ru'));

        await tester.tap(find.widgetWithText(ListTile, 'US').first);
        await tester.pumpAndSettle();

        await tester.tap(
          find.widgetWithText(FilledButton, l10n.radioRegionChoose),
        );
        await tester.pumpAndSettle();

        expect(find.text(l10n.radioRegionFailed), findsOneWidget);
      },
    );
  });

  group('RadioRegionScreen — large font (2.0)', () {
    testWidgets('the suggestion confirm button stays on screen', (
      tester,
    ) async {
      setPlatformCountry(tester, 'US');
      final mesh = MeshService();
      await tester.pumpWidget(
        MediaQuery(
          data: MediaQueryData.fromView(
            tester.view,
          ).copyWith(textScaler: const TextScaler.linear(2)),
          child: wrap(RadioRegionScreen(meshService: mesh)),
        ),
      );
      await tester.pump();

      final l10n = await AppLocalizations.delegate.load(const Locale('ru'));
      final button = find.widgetWithText(
        FilledButton,
        l10n.radioRegionSuggestConfirm,
      );
      await tester.ensureVisible(button);
      await tester.pumpAndSettle();

      final rect = tester.getRect(button);
      final screen = tester.view.physicalSize / tester.view.devicePixelRatio;
      expect(rect.bottom, lessThanOrEqualTo(screen.height));
      expect(rect.top, greaterThanOrEqualTo(0));

      // The button is actually tappable (not covered, not off-screen).
      await tester.tap(button);
      await tester.pumpAndSettle();
      expect(find.text(l10n.radioRegionChoose), findsOneWidget);
    });
  });

  group('HomeScreen — "not configured" card', () {
    Future<void> pumpHome(WidgetTester tester, MeshService mesh) async {
      await tester.pumpWidget(wrap(HomeScreen(meshService: mesh)));
      await tester.pump();
    }

    testWidgets('shown when the region is explicitly unset', (tester) async {
      final mesh = MeshService();
      mesh.loraRegion.value = LoraRegion.unset;
      await pumpHome(tester, mesh);

      final l10n = await AppLocalizations.delegate.load(const Locale('ru'));
      expect(find.text(l10n.radioNotConfiguredTitle), findsOneWidget);
      expect(find.text(l10n.radioRegionChoose), findsOneWidget);
    });

    testWidgets('absent while the config has not arrived yet (null)', (
      tester,
    ) async {
      final mesh = MeshService(); // loraRegion.value == null by default
      await pumpHome(tester, mesh);

      final l10n = await AppLocalizations.delegate.load(const Locale('ru'));
      expect(find.text(l10n.radioNotConfiguredTitle), findsNothing);
    });

    testWidgets('absent when the region is already set', (tester) async {
      final mesh = MeshService();
      mesh.loraRegion.value = LoraRegion.common[0].value;
      await pumpHome(tester, mesh);

      final l10n = await AppLocalizations.delegate.load(const Locale('ru'));
      expect(find.text(l10n.radioNotConfiguredTitle), findsNothing);
    });
  });

  group('SettingsScreen — region row inside "Advanced"', () {
    Future<void> pumpSettings(WidgetTester tester, MeshService mesh) async {
      await tester.pumpWidget(wrap(SettingsScreen(meshService: mesh)));
      await tester.pump();
    }

    testWidgets('only the "Advanced" row is visible, not the region itself', (
      tester,
    ) async {
      final mesh = MeshService();
      mesh.loraRegion.value = LoraRegion.common[0].value; // EU_868
      await pumpSettings(tester, mesh);

      final l10n = await AppLocalizations.delegate.load(const Locale('ru'));
      // "Advanced" is a card at the bottom of the list, off the first screen.
      await scrollToText(tester, l10n.settingsAdvancedTitle);
      expect(find.text(l10n.settingsAdvancedTitle), findsOneWidget);
      // The region code (unlike the static row title) must not be visible —
      // it only appears inside the sub-screen.
      expect(find.text('EU_868'), findsNothing);
    });

    testWidgets('opens the sub-screen where the region is visible', (
      tester,
    ) async {
      final mesh = MeshService();
      mesh.loraRegion.value = LoraRegion.common[0].value; // EU_868
      await pumpSettings(tester, mesh);

      final l10n = await AppLocalizations.delegate.load(const Locale('ru'));
      await scrollToText(tester, l10n.settingsAdvancedTitle);
      await tester.tap(find.text(l10n.settingsAdvancedTitle));
      await tester.pumpAndSettle();

      expect(find.text(l10n.radioRegionTitle), findsOneWidget);
      expect(find.text('EU_868'), findsOneWidget);
    });

    testWidgets('reading the settings while the config has not arrived', (
      tester,
    ) async {
      final mesh = MeshService();
      await pumpSettings(tester, mesh);
      final l10n = await AppLocalizations.delegate.load(const Locale('ru'));

      await scrollToText(tester, l10n.settingsAdvancedTitle);
      await tester.tap(find.text(l10n.settingsAdvancedTitle));
      await tester.pumpAndSettle();

      expect(find.text(l10n.radioRegionReading), findsOneWidget);
    });

    testWidgets('"Не задан" for UNSET', (tester) async {
      final mesh = MeshService();
      mesh.loraRegion.value = LoraRegion.unset;
      await pumpSettings(tester, mesh);
      final l10n = await AppLocalizations.delegate.load(const Locale('ru'));

      await scrollToText(tester, l10n.settingsAdvancedTitle);
      await tester.tap(find.text(l10n.settingsAdvancedTitle));
      await tester.pumpAndSettle();

      expect(find.text(l10n.radioRegionNotSet), findsOneWidget);
    });

    testWidgets(
      'the connection row is only in the "Advanced" sub-screen, '
      'the main settings screen does not have it',
      (tester) async {
        final mesh = MeshService();
        mesh.loraRegion.value = LoraRegion.common[0].value; // EU_868
        await pumpSettings(tester, mesh);
        final l10n = await AppLocalizations.delegate.load(const Locale('ru'));

        // The device is not connected — the main screen has neither the
        // "Device" section nor the connection status row (even after
        // scrolling through the whole list).
        await scrollToText(tester, l10n.settingsAdvancedTitle);
        expect(find.text(l10n.statusNoConnection), findsNothing);
        expect(find.text(l10n.settingsSectionDevice), findsNothing);

        await tester.tap(find.text(l10n.settingsAdvancedTitle));
        await tester.pumpAndSettle();

        // In the "Advanced" sub-screen the connection row is visible
        // together with the radio region, grouped under the "Device"
        // section.
        expect(find.text(l10n.settingsSectionDevice), findsOneWidget);
        expect(find.text(l10n.statusNoConnection), findsOneWidget);
        expect(find.text('EU_868'), findsOneWidget);
      },
    );
  });
}
