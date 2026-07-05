import 'package:flutter/widgets.dart';
import 'package:meshly/l10n/app_localizations.dart';

export 'package:meshly/l10n/app_localizations.dart';

/// Ergonomic access to localized strings: `context.l10n.navChats`.
extension L10nX on BuildContext {
  AppLocalizations get l10n => AppLocalizations.of(this)!;
}
