import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:meshly/l10n/app_localizations.dart';
import 'package:meshly/utils/date_format.dart';

void main() {
  final now = DateTime.now();
  final ru = lookupAppLocalizations(const Locale('ru'));
  final en = lookupAppLocalizations(const Locale('en'));

  setUpAll(() async {
    // DateFormat month names need CLDR symbol data. In the app it is loaded
    // by the flutter_localizations delegates; unit tests load it manually.
    await initializeDateFormatting('ru');
    await initializeDateFormatting('en');
  });

  group('absoluteDate (ru)', () {
    test('formats a specific date correctly', () {
      expect(absoluteDate(ru, DateTime(2026, 5, 2)), '2 мая 2026');
      expect(absoluteDate(ru, DateTime(2025)), '1 января 2025');
      expect(absoluteDate(ru, DateTime(2024, 12, 31)), '31 декабря 2024');
      expect(absoluteDate(ru, DateTime(2026, 3, 8)), '8 марта 2026');
    });

    test('covers all months', () {
      final months = [
        'января', 'февраля', 'марта', 'апреля', 'мая', 'июня',
        'июля', 'августа', 'сентября', 'октября', 'ноября', 'декабря',
      ];
      for (var i = 1; i <= 12; i++) {
        final result = absoluteDate(ru, DateTime(2026, i, 15));
        expect(result, contains(months[i - 1]), reason: 'month $i');
      }
    });
  });

  group('absoluteDate (en)', () {
    test('uses English month names', () {
      expect(absoluteDate(en, DateTime(2026, 5, 2)), '2 May 2026');
      expect(absoluteDate(en, DateTime(2024, 12, 31)), '31 December 2024');
    });
  });

  group('chatDate (ru)', () {
    final fixedNow = DateTime(2026, 7, 4, 15, 30);

    test('same day → Сегодня', () {
      expect(chatDate(ru, DateTime(2026, 7, 4, 0, 1), now: fixedNow),
          'Сегодня');
      expect(chatDate(ru, DateTime(2026, 7, 4, 23, 59), now: fixedNow),
          'Сегодня');
    });

    test('previous day → Вчера', () {
      expect(
          chatDate(ru, DateTime(2026, 7, 3, 23, 59), now: fixedNow), 'Вчера');
      expect(chatDate(ru, DateTime(2026, 7, 3, 0, 1), now: fixedNow), 'Вчера');
    });

    test('yesterday across month boundary → Вчера', () {
      final now = DateTime(2026, 3);
      expect(chatDate(ru, DateTime(2026, 2, 28), now: now), 'Вчера');
    });

    test('same year → day + month without year', () {
      expect(chatDate(ru, DateTime(2026, 5, 2), now: fixedNow), '2 мая');
      expect(chatDate(ru, DateTime(2026, 1, 15), now: fixedNow), '15 января');
    });

    test('other year → full absolute date', () {
      expect(chatDate(ru, DateTime(2025, 12, 31), now: fixedNow),
          '31 декабря 2025');
      expect(
          chatDate(ru, DateTime(2024, 3, 8), now: fixedNow), '8 марта 2024');
    });

    test('defaults to DateTime.now()', () {
      expect(chatDate(ru, DateTime.now()), 'Сегодня');
    });
  });

  group('chatDate (en)', () {
    final fixedNow = DateTime(2026, 7, 4, 15, 30);

    test('today / yesterday / same year / other year', () {
      expect(chatDate(en, DateTime(2026, 7, 4, 10), now: fixedNow), 'Today');
      expect(
          chatDate(en, DateTime(2026, 7, 3, 10), now: fixedNow), 'Yesterday');
      expect(chatDate(en, DateTime(2026, 5, 2), now: fixedNow), '2 May');
      expect(chatDate(en, DateTime(2025, 12, 31), now: fixedNow),
          '31 December 2025');
    });
  });

  group('formatAdded (ru)', () {
    test('today returns "сегодня"', () {
      expect(formatAdded(ru, now.subtract(const Duration(hours: 2))),
          'сегодня');
      expect(formatAdded(ru, now.subtract(const Duration(minutes: 30))),
          'сегодня');
    });

    test('1 day ago', () {
      expect(formatAdded(ru, now.subtract(const Duration(days: 1))),
          '1 день назад');
    });

    test('2 days ago (2 дня)', () {
      expect(formatAdded(ru, now.subtract(const Duration(days: 2))),
          '2 дня назад');
    });

    test('5 days ago (5 дней)', () {
      expect(formatAdded(ru, now.subtract(const Duration(days: 5))),
          '5 дней назад');
    });

    test('11 days ago (11 дней — teens exception)', () {
      expect(formatAdded(ru, now.subtract(const Duration(days: 11))),
          '11 дней назад');
    });

    test('21 days ago (21 день)', () {
      expect(formatAdded(ru, now.subtract(const Duration(days: 21))),
          '21 день назад');
    });

    test('29 days ago — still relative', () {
      final result = formatAdded(ru, now.subtract(const Duration(days: 29)));
      expect(result, contains('назад'));
    });

    test('30 days ago — switches to absolute date', () {
      final dt = now.subtract(const Duration(days: 30));
      final result = formatAdded(ru, dt);
      expect(result, isNot(contains('назад')));
      expect(result, contains('${dt.year}'));
    });

    test('365 days ago — absolute date', () {
      final dt = now.subtract(const Duration(days: 365));
      expect(formatAdded(ru, dt), absoluteDate(ru, dt));
    });
  });

  group('formatAdded (en)', () {
    test('today / 1 day ago / 5 days ago', () {
      expect(formatAdded(en, now.subtract(const Duration(hours: 2))), 'today');
      expect(formatAdded(en, now.subtract(const Duration(days: 1))),
          '1 day ago');
      expect(formatAdded(en, now.subtract(const Duration(days: 5))),
          '5 days ago');
    });
  });

  group('formatLastHeard (ru)', () {
    test('less than 1 minute — "только что"', () {
      expect(formatLastHeard(ru, now.subtract(const Duration(seconds: 30))),
          'только что');
      expect(formatLastHeard(ru, now.subtract(const Duration(seconds: 59))),
          'только что');
    });

    test('1 minute ago', () {
      expect(
        formatLastHeard(ru, now.subtract(const Duration(minutes: 1))),
        '1 минуту назад',
      );
    });

    test('2 minutes (2 минуты)', () {
      expect(
        formatLastHeard(ru, now.subtract(const Duration(minutes: 2))),
        '2 минуты назад',
      );
    });

    test('5 minutes (5 минут)', () {
      expect(
        formatLastHeard(ru, now.subtract(const Duration(minutes: 5))),
        '5 минут назад',
      );
    });

    test('21 minutes (21 минуту)', () {
      expect(
        formatLastHeard(ru, now.subtract(const Duration(minutes: 21))),
        '21 минуту назад',
      );
    });

    test('11 minutes (11 минут — teens exception)', () {
      expect(
        formatLastHeard(ru, now.subtract(const Duration(minutes: 11))),
        '11 минут назад',
      );
    });

    test('1 hour ago', () {
      expect(
        formatLastHeard(ru, now.subtract(const Duration(hours: 1))),
        '1 час назад',
      );
    });

    test('2 hours (2 часа)', () {
      expect(
        formatLastHeard(ru, now.subtract(const Duration(hours: 2))),
        '2 часа назад',
      );
    });

    test('5 hours (5 часов)', () {
      expect(
        formatLastHeard(ru, now.subtract(const Duration(hours: 5))),
        '5 часов назад',
      );
    });

    test('11 hours (11 часов — teens exception)', () {
      expect(
        formatLastHeard(ru, now.subtract(const Duration(hours: 11))),
        '11 часов назад',
      );
    });

    test('21 hours (21 час)', () {
      expect(
        formatLastHeard(ru, now.subtract(const Duration(hours: 21))),
        '21 час назад',
      );
    });

    test('1 day ago (1 день)', () {
      expect(
        formatLastHeard(ru, now.subtract(const Duration(days: 1))),
        '1 день назад',
      );
    });

    test('5 days ago (5 дней)', () {
      expect(
        formatLastHeard(ru, now.subtract(const Duration(days: 5))),
        '5 дней назад',
      );
    });

    test('30 days ago — switches to absolute date', () {
      final dt = now.subtract(const Duration(days: 30));
      expect(formatLastHeard(ru, dt), absoluteDate(ru, dt));
    });
  });

  group('formatLastHeard (en)', () {
    test('just now / minutes / hours / days', () {
      expect(formatLastHeard(en, now.subtract(const Duration(seconds: 30))),
          'just now');
      expect(formatLastHeard(en, now.subtract(const Duration(minutes: 1))),
          '1 minute ago');
      expect(formatLastHeard(en, now.subtract(const Duration(minutes: 5))),
          '5 minutes ago');
      expect(formatLastHeard(en, now.subtract(const Duration(hours: 1))),
          '1 hour ago');
      expect(formatLastHeard(en, now.subtract(const Duration(hours: 5))),
          '5 hours ago');
      expect(formatLastHeard(en, now.subtract(const Duration(days: 1))),
          '1 day ago');
      expect(formatLastHeard(en, now.subtract(const Duration(days: 5))),
          '5 days ago');
    });
  });

  group('Russian plural rules (daysAgo edge cases)', () {
    final cases = {
      1: 'день',
      2: 'дня',
      3: 'дня',
      4: 'дня',
      5: 'дней',
      10: 'дней',
      11: 'дней',
      12: 'дней',
      13: 'дней',
      14: 'дней',
      21: 'день',
      22: 'дня',
      25: 'дней',
    };

    for (final entry in cases.entries.toList()) {
      final n = entry.key;
      final word = entry.value;
      test('$n → $word', () {
        final result = formatAdded(ru, now.subtract(Duration(days: n)));
        expect(result, '$n $word назад', reason: 'days=$n');
      });
    }
  });
}
