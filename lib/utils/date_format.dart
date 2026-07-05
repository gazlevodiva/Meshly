// Locale-aware relative/absolute date formatting utilities.
//
// Relative phrases ("5 дней назад" / "5 days ago") come from ICU plurals in
// the ARB files; month names come from intl's CLDR data via [DateFormat].
// In the app that data is loaded by the flutter_localizations delegates;
// pure unit tests must call initializeDateFormatting() first (see
// package:intl/date_symbol_data_local.dart).

import 'package:intl/intl.dart';
import 'package:meshly/l10n/app_localizations.dart';

/// "2 мая 2026" / "2 May 2026"
String absoluteDate(AppLocalizations l10n, DateTime dt) =>
    DateFormat('d MMMM yyyy', l10n.localeName).format(dt);

/// Date-chip label between messages from different days in a chat:
/// "Сегодня" / "Вчера" / "5 мая" (same year) / "5 мая 2025" (other year).
///
/// [now] is injectable for tests.
String chatDate(AppLocalizations l10n, DateTime dt, {DateTime? now}) {
  final n = now ?? DateTime.now();
  final today = DateTime(n.year, n.month, n.day);
  final day = DateTime(dt.year, dt.month, dt.day);
  final diff = today.difference(day).inDays;
  if (diff == 0) return l10n.dateToday;
  if (diff == 1) return l10n.dateYesterday;
  if (dt.year == n.year) {
    return DateFormat('d MMMM', l10n.localeName).format(dt);
  }
  return absoluteDate(l10n, dt);
}

/// "сегодня" / "5 дней назад" / "2 мая 2026"
String formatAdded(AppLocalizations l10n, DateTime dt) {
  final diff = DateTime.now().difference(dt).inDays;
  if (diff < 1) return l10n.relativeToday;
  if (diff < 30) return l10n.daysAgo(diff);
  return absoluteDate(l10n, dt);
}

/// "только что" / "3 минуты назад" / "2 часа назад" / "5 дней назад" /
/// "2 мая 2026"
String formatLastHeard(AppLocalizations l10n, DateTime dt) {
  final diff = DateTime.now().difference(dt);
  if (diff.inMinutes < 1) return l10n.dateJustNow;
  if (diff.inHours < 1) return l10n.minutesAgo(diff.inMinutes);
  if (diff.inDays < 1) return l10n.hoursAgo(diff.inHours);
  if (diff.inDays < 30) return l10n.daysAgo(diff.inDays);
  return absoluteDate(l10n, dt);
}
