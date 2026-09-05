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

  /// Подменяет локаль платформы (страну телефона), от которой зависит
  /// подсказка [LoraRegion.suggestedFor], и снимает подмену после теста.
  void setPlatformCountry(WidgetTester tester, String? countryCode) {
    final dispatcher = tester.binding.platformDispatcher
      ..localeTestValue = countryCode == null
          ? const Locale('en')
          : Locale('en', countryCode);
    addTearDown(dispatcher.clearLocaleTestValue);
  }

  /// Список — `ListView`, поэтому элементы ниже первого экрана не
  /// построены, пока их не прокрутили в область видимости.
  Future<void> scrollToText(WidgetTester tester, String text) async {
    final finder = find.text(text);
    await tester.scrollUntilVisible(
      finder,
      400,
      scrollable: find.byType(Scrollable).first,
    );
    // scrollUntilVisible останавливается, как только виджет ПОСТРОЕН, а
    // список строит и то, что лежит за краем экрана (cacheExtent). Без
    // ensureVisible виджет бывает найден, но не виден — и тап по нему
    // промахивается мимо экрана. Тест не должен зависеть от того, на
    // сколько пикселей ниже оказалась карточка.
    await tester.ensureVisible(finder);
    await tester.pumpAndSettle();
  }

  group('RadioRegionScreen — подсказка в один тап', () {
    testWidgets('есть подсказка — показана одна кнопка подтверждения', (
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
      // Полный список пока не показан.
      expect(find.text(l10n.radioRegionAll), findsNothing);
    });

    testWidgets('подтверждение подсказки ведёт к обычному диалогу', (
      tester,
    ) async {
      setPlatformCountry(tester, 'US');
      final mesh = MeshService(); // конфиг не пришёл — setRegion вернёт false
      await tester.pumpWidget(wrap(RadioRegionScreen(meshService: mesh)));
      await tester.pump();

      final l10n = await AppLocalizations.delegate.load(const Locale('ru'));
      await tester.tap(
        find.widgetWithText(FilledButton, l10n.radioRegionSuggestConfirm),
      );
      await tester.pumpAndSettle();

      // Открылась шторка подтверждения с кодом региона.
      expect(find.text('US'), findsWidgets);
      await tester.tap(
        find.widgetWithText(FilledButton, l10n.radioRegionChoose),
      );
      await tester.pumpAndSettle();

      expect(find.text(l10n.radioRegionFailed), findsOneWidget);
    });

    testWidgets('«выбрать другой регион» открывает полный список', (
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

    testWidgets('нет однозначной подсказки — сразу полный список', (
      tester,
    ) async {
      // Казахстан намеренно не в таблице подсказок (два равноправных кода).
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

  group('RadioRegionScreen — полный список', () {
    testWidgets('текущий регион помечен галочкой', (tester) async {
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
      // Регион уже задан (EU_868, диапазон 868) — экран сразу открывает
      // полный список, а не подсказку.
      mesh.loraRegion.value = LoraRegion.common[0].value; // EU_868
      await tester.pumpWidget(wrap(RadioRegionScreen(meshService: mesh)));
      await tester.pump();
      return mesh;
    }

    testWidgets('«Все регионы» не содержит несовместимый диапазон', (
      tester,
    ) async {
      setPlatformCountry(tester, null);
      await pumpWithEu868(tester);

      final l10n = await AppLocalizations.delegate.load(const Locale('ru'));

      // «Все регионы» (совместимые, диапазон 868) не содержит 'US'
      // (диапазон 915) — он отфильтрован в отдельную секцию ниже.
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

    testWidgets('несовместимый диапазон — отдельная секция с предупреждением', (
      tester,
    ) async {
      setPlatformCountry(tester, null);
      await pumpWithEu868(tester);

      final l10n = await AppLocalizations.delegate.load(const Locale('ru'));

      // Секция «Другой диапазон» с предупреждением содержит 'US'.
      // Прокручиваем до заголовка секции, а не до текста предупреждения:
      // заголовок — самый нижний из проверяемых виджетов (после него в
      // ListView только сам список), поэтому его видимость не зависит от
      // того, сколько строк выше (в «Частых» или «Все регионы»).
      // Заголовок и предупреждение проверяем по очереди: в длинном списке
      // они не обязаны помещаться на экран одновременно, а невидимые
      // элементы список не строит.
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

    testWidgets('смена уже заданного региона предупреждает о разрыве связи', (
      tester,
    ) async {
      setPlatformCountry(tester, null);
      final mesh = MeshService();
      mesh.loraRegion.value = LoraRegion.common[0].value; // EU_868 задан
      await tester.pumpWidget(wrap(RadioRegionScreen(meshService: mesh)));
      await tester.pump();

      final l10n = await AppLocalizations.delegate.load(const Locale('ru'));
      // RU (868) — совместимый регион, отличный от текущего EU_868.
      await tester.tap(find.widgetWithText(ListTile, 'RU').first);
      await tester.pumpAndSettle();

      expect(find.text(l10n.radioRegionChangeWarning), findsOneWidget);
    });

    testWidgets(
      'неудачная попытка применить регион показывает ошибку',
      (tester) async {
        setPlatformCountry(tester, 'KZ'); // без подсказки — сразу список
        final mesh = MeshService(); // конфиг не пришёл — setRegion вернёт false
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

  group('RadioRegionScreen — крупный шрифт (2.0)', () {
    testWidgets('кнопка подтверждения подсказки остаётся на экране', (
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

      // Кнопка действительно нажимаема (не перекрыта, не за кадром).
      await tester.tap(button);
      await tester.pumpAndSettle();
      expect(find.text(l10n.radioRegionChoose), findsOneWidget);
    });
  });

  group('HomeScreen — карточка «не настроено»', () {
    Future<void> pumpHome(WidgetTester tester, MeshService mesh) async {
      await tester.pumpWidget(wrap(HomeScreen(meshService: mesh)));
      await tester.pump();
    }

    testWidgets('показана, когда регион явно unset', (tester) async {
      final mesh = MeshService();
      mesh.loraRegion.value = LoraRegion.unset;
      await pumpHome(tester, mesh);

      final l10n = await AppLocalizations.delegate.load(const Locale('ru'));
      expect(find.text(l10n.radioNotConfiguredTitle), findsOneWidget);
      expect(find.text(l10n.radioRegionChoose), findsOneWidget);
    });

    testWidgets('отсутствует, пока конфиг ещё не пришёл (null)', (
      tester,
    ) async {
      final mesh = MeshService(); // loraRegion.value == null по умолчанию
      await pumpHome(tester, mesh);

      final l10n = await AppLocalizations.delegate.load(const Locale('ru'));
      expect(find.text(l10n.radioNotConfiguredTitle), findsNothing);
    });

    testWidgets('отсутствует, когда регион уже задан', (tester) async {
      final mesh = MeshService();
      mesh.loraRegion.value = LoraRegion.common[0].value;
      await pumpHome(tester, mesh);

      final l10n = await AppLocalizations.delegate.load(const Locale('ru'));
      expect(find.text(l10n.radioNotConfiguredTitle), findsNothing);
    });
  });

  group('SettingsScreen — строка региона в «Дополнительно»', () {
    Future<void> pumpSettings(WidgetTester tester, MeshService mesh) async {
      await tester.pumpWidget(wrap(SettingsScreen(meshService: mesh)));
      await tester.pump();
    }

    testWidgets('на виду только строка «Дополнительно», не сам регион', (
      tester,
    ) async {
      final mesh = MeshService();
      mesh.loraRegion.value = LoraRegion.common[0].value; // EU_868
      await pumpSettings(tester, mesh);

      final l10n = await AppLocalizations.delegate.load(const Locale('ru'));
      // «Дополнительно» — карточка внизу списка, вне первого экрана.
      await scrollToText(tester, l10n.settingsAdvancedTitle);
      expect(find.text(l10n.settingsAdvancedTitle), findsOneWidget);
      // Код региона (в отличие от статичного названия строки) на виду не
      // должен быть — он появляется только внутри подэкрана.
      expect(find.text('EU_868'), findsNothing);
    });

    testWidgets('открывает подэкран, где регион виден', (tester) async {
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

    testWidgets('читаем настройки, пока конфиг не пришёл', (tester) async {
      final mesh = MeshService();
      await pumpSettings(tester, mesh);
      final l10n = await AppLocalizations.delegate.load(const Locale('ru'));

      await scrollToText(tester, l10n.settingsAdvancedTitle);
      await tester.tap(find.text(l10n.settingsAdvancedTitle));
      await tester.pumpAndSettle();

      expect(find.text(l10n.radioRegionReading), findsOneWidget);
    });

    testWidgets('«не задан» для UNSET', (tester) async {
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
      'строка подключения — только в подэкране «Дополнительно», '
      'на основном экране настроек её нет',
      (tester) async {
        final mesh = MeshService();
        mesh.loraRegion.value = LoraRegion.common[0].value; // EU_868
        await pumpSettings(tester, mesh);
        final l10n = await AppLocalizations.delegate.load(const Locale('ru'));

        // Устройство не подключено — на основном экране нет ни секции
        // «Устройство», ни строки статуса подключения (даже прокрутив
        // список целиком).
        await scrollToText(tester, l10n.settingsAdvancedTitle);
        expect(find.text(l10n.statusNoConnection), findsNothing);
        expect(find.text(l10n.settingsSectionDevice), findsNothing);

        await tester.tap(find.text(l10n.settingsAdvancedTitle));
        await tester.pumpAndSettle();

        // В подэкране «Дополнительно» строка подключения на виду вместе
        // с регионом радио, сгруппированные секцией «Устройство».
        expect(find.text(l10n.settingsSectionDevice), findsOneWidget);
        expect(find.text(l10n.statusNoConnection), findsOneWidget);
        expect(find.text('EU_868'), findsOneWidget);
      },
    );
  });
}
