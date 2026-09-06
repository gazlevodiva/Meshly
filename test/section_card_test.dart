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

  group('SectionCard — top spacing', () {
    testWidgets(
      'a card without a title and without topGap sticks to the previous one '
      '(old behavior preserved)',
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
        // Without topGap there is no spacing — the second card is right under the first.
        expect(secondRect.top, greaterThan(firstRect.bottom));
      },
    );

    testWidgets(
      'a card without a title with topGap: true does not overlap the previous one',
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

        // The cards do not overlap and there is a visible gap between them.
        expect(secondCardRect.top, greaterThan(firstCardRect.bottom));
      },
    );
  });
}
