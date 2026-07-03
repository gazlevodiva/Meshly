import 'package:flutter_test/flutter_test.dart';
import 'package:meshly/utils/date_format_ru.dart';

void main() {
  final now = DateTime.now();

  group('absoluteDateRu', () {
    test('formats a specific date correctly', () {
      expect(absoluteDateRu(DateTime(2026, 5, 2)), '2 мая 2026');
      expect(absoluteDateRu(DateTime(2025)), '1 января 2025');
      expect(absoluteDateRu(DateTime(2024, 12, 31)), '31 декабря 2024');
      expect(absoluteDateRu(DateTime(2026, 3, 8)), '8 марта 2026');
    });

    test('covers all months', () {
      final months = [
        'января', 'февраля', 'марта', 'апреля', 'мая', 'июня',
        'июля', 'августа', 'сентября', 'октября', 'ноября', 'декабря',
      ];
      for (var i = 1; i <= 12; i++) {
        final result = absoluteDateRu(DateTime(2026, i, 15));
        expect(result, contains(months[i - 1]), reason: 'month $i');
      }
    });
  });

  group('formatAddedRu', () {
    test('today returns "сегодня"', () {
      expect(formatAddedRu(now.subtract(const Duration(hours: 2))), 'сегодня');
      expect(formatAddedRu(now.subtract(const Duration(minutes: 30))), 'сегодня');
    });

    test('1 day ago', () {
      expect(formatAddedRu(now.subtract(const Duration(days: 1))), '1 день назад');
    });

    test('2 days ago (2 дня)', () {
      expect(formatAddedRu(now.subtract(const Duration(days: 2))), '2 дня назад');
    });

    test('5 days ago (5 дней)', () {
      expect(formatAddedRu(now.subtract(const Duration(days: 5))), '5 дней назад');
    });

    test('11 days ago (11 дней — teens exception)', () {
      expect(formatAddedRu(now.subtract(const Duration(days: 11))), '11 дней назад');
    });

    test('21 days ago (21 день)', () {
      expect(formatAddedRu(now.subtract(const Duration(days: 21))), '21 день назад');
    });

    test('29 days ago — still relative', () {
      final result = formatAddedRu(now.subtract(const Duration(days: 29)));
      expect(result, contains('назад'));
    });

    test('30 days ago — switches to absolute date', () {
      final dt = now.subtract(const Duration(days: 30));
      final result = formatAddedRu(dt);
      expect(result, isNot(contains('назад')));
      expect(result, contains('${dt.year}'));
    });

    test('365 days ago — absolute date', () {
      final dt = now.subtract(const Duration(days: 365));
      expect(formatAddedRu(dt), absoluteDateRu(dt));
    });
  });

  group('formatLastHeardRu', () {
    test('less than 1 minute — "только что"', () {
      expect(formatLastHeardRu(now.subtract(const Duration(seconds: 30))), 'только что');
      expect(formatLastHeardRu(now.subtract(const Duration(seconds: 59))), 'только что');
    });

    test('1 minute ago', () {
      expect(
        formatLastHeardRu(now.subtract(const Duration(minutes: 1))),
        '1 минуту назад',
      );
    });

    test('2 minutes (2 минуты)', () {
      expect(
        formatLastHeardRu(now.subtract(const Duration(minutes: 2))),
        '2 минуты назад',
      );
    });

    test('5 minutes (5 минут)', () {
      expect(
        formatLastHeardRu(now.subtract(const Duration(minutes: 5))),
        '5 минут назад',
      );
    });

    test('21 minutes (21 минуту)', () {
      expect(
        formatLastHeardRu(now.subtract(const Duration(minutes: 21))),
        '21 минуту назад',
      );
    });

    test('11 minutes (11 минут — teens exception)', () {
      expect(
        formatLastHeardRu(now.subtract(const Duration(minutes: 11))),
        '11 минут назад',
      );
    });

    test('1 hour ago', () {
      expect(
        formatLastHeardRu(now.subtract(const Duration(hours: 1))),
        '1 час назад',
      );
    });

    test('2 hours (2 часа)', () {
      expect(
        formatLastHeardRu(now.subtract(const Duration(hours: 2))),
        '2 часа назад',
      );
    });

    test('5 hours (5 часов)', () {
      expect(
        formatLastHeardRu(now.subtract(const Duration(hours: 5))),
        '5 часов назад',
      );
    });

    test('11 hours (11 часов — teens exception)', () {
      expect(
        formatLastHeardRu(now.subtract(const Duration(hours: 11))),
        '11 часов назад',
      );
    });

    test('21 hours (21 час)', () {
      expect(
        formatLastHeardRu(now.subtract(const Duration(hours: 21))),
        '21 час назад',
      );
    });

    test('1 day ago (1 день)', () {
      expect(
        formatLastHeardRu(now.subtract(const Duration(days: 1))),
        '1 день назад',
      );
    });

    test('5 days ago (5 дней)', () {
      expect(
        formatLastHeardRu(now.subtract(const Duration(days: 5))),
        '5 дней назад',
      );
    });

    test('30 days ago — switches to absolute date', () {
      final dt = now.subtract(const Duration(days: 30));
      expect(formatLastHeardRu(dt), absoluteDateRu(dt));
    });
  });

  group('Russian plural rules (_days edge cases)', () {
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
        final result = formatAddedRu(now.subtract(Duration(days: n)));
        expect(result, '$n $word назад', reason: 'days=$n');
      });
    }
  });
}
