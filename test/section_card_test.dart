import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meshly/l10n/app_localizations.dart';
import 'package:meshly/widgets/section_card.dart';

void main() {
  Widget wrap(Widget child) {
    return MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: const Locale('ru'),
      home: Scaffold(
        body: ListView(children: [child]),
      ),
    );
  }

  group('SectionCard — верхний отступ', () {
    testWidgets(
      'карточка без заголовка и без topGap прилипает к предыдущей '
      '(старое поведение сохранено)',
      (tester) async {
        await tester.pumpWidget(
          wrap(
            const Column(
              children: [
                SectionCard(
                  title: 'Профиль',
                  child: ListTile(title: Text('Первая')),
                ),
                SectionCard(child: ListTile(title: Text('Вторая'))),
              ],
            ),
          ),
        );

        final firstRect = tester.getRect(find.text('Первая'));
        final secondRect = tester.getRect(find.text('Вторая'));
        // Без topGap отступа нет — вторая карточка сразу под первой.
        expect(secondRect.top, greaterThan(firstRect.bottom));
      },
    );

    testWidgets(
      'карточка без заголовка с topGap: true не пересекается с предыдущей',
      (tester) async {
        await tester.pumpWidget(
          wrap(
            const Column(
              children: [
                SectionCard(
                  title: 'Профиль',
                  child: ListTile(title: Text('Первая')),
                ),
                SectionCard(
                  topGap: true,
                  child: ListTile(title: Text('Вторая')),
                ),
              ],
            ),
          ),
        );

        final firstCardRect = tester.getRect(
          find
              .ancestor(
                of: find.text('Первая'),
                matching: find.byType(Material),
              )
              .first,
        );
        final secondCardRect = tester.getRect(
          find
              .ancestor(
                of: find.text('Вторая'),
                matching: find.byType(Material),
              )
              .first,
        );

        // Карточки не пересекаются и между ними есть видимый зазор.
        expect(secondCardRect.top, greaterThan(firstCardRect.bottom));
      },
    );
  });
}
