import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meshly/l10n/app_localizations.dart';
import 'package:meshly/theme/app_theme.dart';
import 'package:meshly/widgets/floating_nav_bar.dart';

const _labels = ['Чаты', 'Контакты', 'Настройки'];

Widget _host({
  required int currentIndex,
  required ValueChanged<int> onTap,
  double textScale = 1.0,
}) {
  return MaterialApp(
    theme: buildLightTheme(),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    locale: const Locale('ru'),
    home: MediaQuery(
      data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
      child: Scaffold(
        body: Align(
          alignment: Alignment.bottomCenter,
          child: FloatingNavBar(currentIndex: currentIndex, onTap: onTap),
        ),
      ),
    ),
  );
}

void _setScreenSize(WidgetTester tester, Size size) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

void main() {
  for (final size in const [Size(320, 600), Size(400, 800)]) {
    for (var index = 0; index < 3; index++) {
      testWidgets(
          'renders without overflow at ${size.width.toInt()}px, index $index',
          (tester) async {
        _setScreenSize(tester, size);

        await tester.pumpWidget(_host(currentIndex: index, onTap: (_) {}));
        await tester.pumpAndSettle();

        // All three labels are always visible (overflow would fail the test
        // automatically via FlutterError.onError).
        for (final label in _labels) {
          expect(find.text(label), findsOneWidget);
        }
      });
    }
  }

  testWidgets('tapping each tab reports the right index', (tester) async {
    _setScreenSize(tester, const Size(400, 800));

    final taps = <int>[];
    await tester.pumpWidget(_host(currentIndex: 0, onTap: taps.add));

    for (var i = 0; i < 3; i++) {
      await tester.tap(find.text(_labels[i]));
      await tester.pumpAndSettle();
    }

    expect(taps, [0, 1, 2]);
  });

  testWidgets('gaps between items are visually equal (space-evenly)',
      (tester) async {
    _setScreenSize(tester, const Size(400, 800));

    final taps = <int>[];
    await tester.pumpWidget(_host(currentIndex: 0, onTap: taps.add));

    final rects = [
      for (var i = 0; i < 3; i++)
        tester.getRect(find.byType(InkWell).at(i)),
    ];
    // Items sit at their intrinsic widths, so the gap between
    // Чаты–Контакты must equal the gap Контакты–Настройки.
    final gap01 = rects[1].left - rects[0].right;
    final gap12 = rects[2].left - rects[1].right;
    expect((gap01 - gap12).abs(), lessThan(0.5),
        reason: 'between-item gaps must match: $gap01 vs $gap12');

    for (var i = 0; i < 3; i++) {
      // Tap near the left edge of each item (not on the icon/label).
      await tester.tapAt(
          Offset(rects[i].left + AppSpacing.s4, rects[i].center.dy));
      await tester.pumpAndSettle();
    }

    expect(taps, [0, 1, 2]);
  });

  testWidgets('no overflow at 320px with textScaler 1.3', (tester) async {
    _setScreenSize(tester, const Size(320, 600));

    await tester.pumpWidget(
      _host(currentIndex: 2, onTap: (_) {}, textScale: 1.3),
    );
    await tester.pumpAndSettle();

    for (final label in _labels) {
      expect(find.text(label), findsOneWidget);
    }
  });
}
