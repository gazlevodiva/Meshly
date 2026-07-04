// Russian-language relative/absolute date formatting utilities.

const _monthNames = [
  '', 'января', 'февраля', 'марта', 'апреля', 'мая', 'июня',
  'июля', 'августа', 'сентября', 'октября', 'ноября', 'декабря',
];

String absoluteDateRu(DateTime dt) =>
    '${dt.day} ${_monthNames[dt.month]} ${dt.year}';

/// Date-chip label between messages from different days in a chat:
/// "Сегодня" / "Вчера" / "5 мая" (same year) / "5 мая 2025" (other year).
///
/// [now] is injectable for tests.
String chatDateRu(DateTime dt, {DateTime? now}) {
  final n = now ?? DateTime.now();
  final today = DateTime(n.year, n.month, n.day);
  final day = DateTime(dt.year, dt.month, dt.day);
  final diff = today.difference(day).inDays;
  if (diff == 0) return 'Сегодня';
  if (diff == 1) return 'Вчера';
  if (dt.year == n.year) return '${dt.day} ${_monthNames[dt.month]}';
  return absoluteDateRu(dt);
}

/// "сегодня" / "5 дней назад" / "2 мая 2026"
String formatAddedRu(DateTime dt) {
  final diff = DateTime.now().difference(dt).inDays;
  if (diff < 1) return 'сегодня';
  if (diff < 30) return '$diff ${_days(diff)} назад';
  return absoluteDateRu(dt);
}

/// "только что" / "3 минуты назад" / "2 часа назад" / "5 дней назад" / "2 мая 2026"
String formatLastHeardRu(DateTime dt) {
  final now = DateTime.now();
  final diff = now.difference(dt);
  if (diff.inMinutes < 1) return 'только что';
  if (diff.inHours < 1) return '${diff.inMinutes} ${_minutes(diff.inMinutes)} назад';
  if (diff.inDays < 1) return '${diff.inHours} ${_hours(diff.inHours)} назад';
  if (diff.inDays < 30) return '${diff.inDays} ${_days(diff.inDays)} назад';
  return absoluteDateRu(dt);
}

String _days(int n) {
  if (n % 10 == 1 && n % 100 != 11) return 'день';
  if (n % 10 >= 2 && n % 10 <= 4 && (n % 100 < 10 || n % 100 >= 20)) return 'дня';
  return 'дней';
}

String _hours(int n) {
  if (n % 10 == 1 && n % 100 != 11) return 'час';
  if (n % 10 >= 2 && n % 10 <= 4 && (n % 100 < 10 || n % 100 >= 20)) return 'часа';
  return 'часов';
}

String _minutes(int n) {
  if (n % 10 == 1 && n % 100 != 11) return 'минуту';
  if (n % 10 >= 2 && n % 10 <= 4 && (n % 100 < 10 || n % 100 >= 20)) return 'минуты';
  return 'минут';
}
