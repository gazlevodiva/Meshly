import 'package:flutter/material.dart';

/// Central design tokens for Meshly.
///
/// Screens and widgets must never use raw `Colors.*`, `fontSize:`,
/// `BorderRadius.circular(<number>)` or magic paddings — everything visual
/// lives here. Material `ColorScheme` roles (primary, error, errorContainer,
/// surfaceContainerHighest, primaryContainer, ...) are intentionally NOT
/// duplicated: keep using `Theme.of(context).colorScheme` for those.

// ── Colors ────────────────────────────────────────────────────

/// Semantic colors that are not covered by the Material [ColorScheme].
abstract final class AppColors {
  /// Seed for the Material 3 [ColorScheme] (see [buildAppTheme]).
  static const Color seed = Colors.blue;

  /// Green "online" indicator (dots, "В сети" label, strong signal).
  static const Color online = Colors.green;

  /// Grey "offline" indicator (dots, "Не в сети" label).
  static const Color offline = Colors.grey;

  /// Secondary/dimmed text (captions, hints, subtitles).
  static const Color textSecondary = Colors.grey;

  /// Dimmed icons (info rows, muted bell, disabled bluetooth...).
  static const Color iconSecondary = Colors.grey;

  /// Bottom-sheet drag handle (== Colors.grey.shade300).
  static const Color dragHandle = Color(0xFFE0E0E0);

  /// Warning accent — block/blocked actions, medium signal.
  static const Color warning = Colors.orange;

  /// Hard failure accent — failed message status, weak signal.
  static const Color danger = Colors.red;

  /// Brand blue used for standalone icons/acked checkmarks
  /// (kept separate from colorScheme.primary on purpose — the seeded
  /// scheme derives a different tone than raw Colors.blue).
  static const Color brand = Colors.blue;

  /// Content drawn on top of accent-colored fills
  /// (message bubble text, unread badge text, spinner on FilledButton).
  static const Color onAccent = Colors.white;

  /// QR-code card background — always white so codes stay scannable.
  static const Color qrCardBackground = Colors.white;

  /// Soft shadow under the QR card (== Colors.black.withAlpha(20)).
  static const Color qrCardShadow = Color(0x14000000);

  /// Shadow under the floating navigation island.
  static const Color islandShadow = Color(0x24000000);
}

// ── Spacing ───────────────────────────────────────────────────

/// Spacing scale (paddings, gaps, margins). `sN` == N logical pixels.
abstract final class AppSpacing {
  static const double s2 = 2;
  static const double s4 = 4;
  static const double s6 = 6;
  static const double s8 = 8;
  static const double s10 = 10;
  static const double s12 = 12;
  static const double s14 = 14;
  static const double s16 = 16;
  static const double s20 = 20;
  static const double s24 = 24;
  static const double s28 = 28;
  static const double s32 = 32;
  static const double s40 = 40;
  static const double s48 = 48;

  /// Divider indent that aligns with ListTile text (past the avatar).
  static const double dividerIndent = 72;

  /// Bottom list padding that keeps content clear of the floating navbar.
  static const double listBottomPadding = 96;
}

// ── Corner radii ──────────────────────────────────────────────

/// Corner radii in use across the app.
abstract final class AppRadius {
  /// Bottom-sheet drag handle.
  static const double handle = 2;

  /// Onboarding page-indicator dots.
  static const double dot = 4;

  /// Small emoji-picker cell (36x36, inside dialogs).
  static const double chipSmall = 6;

  /// Regular emoji-picker cell (44x44).
  static const double chip = 8;

  /// Unread-count badge.
  static const double badge = 10;

  /// Cards / emoji grid cells (48x48) / info boxes.
  static const double card = 12;

  /// White QR-code card.
  static const double qrCard = 16;

  /// Chat message bubble.
  static const double bubble = 18;

  /// Modal bottom sheet (top corners).
  static const double sheet = 20;

  /// Rounded message input field.
  static const double input = 24;

  /// Floating navigation island.
  static const double island = 28;
}

/// Shared shapes built from [AppRadius].
abstract final class AppShapes {
  /// Standard modal bottom sheet with rounded top corners.
  static const RoundedRectangleBorder bottomSheet = RoundedRectangleBorder(
    borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.sheet)),
  );
}

// ── Icon sizes ────────────────────────────────────────────────

/// Icon sizes in use across the app.
abstract final class AppIconSizes {
  /// Message status icon (clock/check/done_all) next to a bubble.
  static const double status = 12;

  /// Muted-bell icon in a conversation tile.
  static const double mute = 14;

  /// Banner icons (disconnected bluetooth, chevron) and small edit pencil.
  static const double banner = 16;

  /// Info-row icons (lock, key, info_outline) and inline edit button.
  static const double info = 18;

  /// Signal-strength indicator in the scan list.
  static const double signal = 20;

  /// Navigation bar items.
  static const double nav = 24;

  /// Hero bluetooth icon on the scan screen.
  static const double hero = 72;
}

// ── Misc sizes (emoji, dots, avatars, QR...) ──────────────────

/// Non-icon component dimensions and emoji font sizes.
abstract final class AppSizes {
  // Emoji font sizes.
  static const double emojiSmall = 22; // list avatars, small picker cells
  static const double emojiMedium = 26; // regular picker cells
  static const double emojiLarge = 28; // channel avatar, channel picker
  static const double emojiHeader = 36; // channel info header
  static const double emojiCard = 40; // "my card" avatar
  static const double emojiAvatar = 52; // edit-contact avatar
  static const double emojiEmpty = 56; // empty-state hand wave
  static const double emojiHero = 72; // onboarding page illustration

  // Online/offline status dots.
  static const double statusDotSmall = 8; // appbar / edit-contact row
  static const double statusDot = 12; // over list avatars
  static const double statusDotBorder = 2;

  // Emoji picker cells.
  static const double emojiCellSmall = 36;
  static const double emojiCell = 44;
  static const double emojiCellLarge = 48;

  // Avatars.
  static const double avatarLarge = 96; // edit-contact header
  static const double avatarEditBadge = 28; // pencil badge on avatar

  // QR codes.
  static const double qrMedium = 200;
  static const double qrLarge = 220;

  // Inline progress spinners inside buttons.
  static const double spinnerSmall = 18;
  static const double spinner = 20;
  static const double spinnerStroke = 2;

  // Bottom-sheet drag handle.
  static const double handleWidth = 36;
  static const double handleHeight = 4;

  // Onboarding page indicator.
  static const double pageDot = 8;
  static const double pageDotActiveWidth = 20;

  // Emoji picker dialog content width.
  static const double emojiDialogWidth = 280;
}

// ── Text styles ───────────────────────────────────────────────

/// Recurring inline text styles.
abstract final class AppTextStyles {
  /// Monospace family for node IDs / keys / links.
  static const String monoFamily = 'monospace';

  /// Default-size secondary (grey) text.
  static const TextStyle secondary = TextStyle(color: AppColors.textSecondary);

  /// 11 grey — tiny labels (info-row captions, timestamps).
  static const TextStyle label =
      TextStyle(fontSize: 11, color: AppColors.textSecondary);

  /// 12 grey — captions.
  static const TextStyle caption =
      TextStyle(fontSize: 12, color: AppColors.textSecondary);

  /// 13 plain — compact body text (last message preview, info values).
  static const TextStyle body = TextStyle(fontSize: 13);

  /// 13 grey — subtitles / helper text.
  static const TextStyle subtitle =
      TextStyle(fontSize: 13, color: AppColors.textSecondary);

  /// 14 grey — hints on the scan screen.
  static const TextStyle hint =
      TextStyle(fontSize: 14, color: AppColors.textSecondary);

  /// 16 grey — onboarding body text.
  static const TextStyle bodyLargeSecondary =
      TextStyle(fontSize: 16, color: AppColors.textSecondary);

  /// Monospace, default size (blocked node IDs).
  static const TextStyle mono = TextStyle(fontFamily: monoFamily);

  /// 12 grey monospace — node IDs in dialogs/cards.
  static const TextStyle monoCaption = TextStyle(
    fontSize: 12,
    color: AppColors.textSecondary,
    fontFamily: monoFamily,
  );

  /// 11 monospace — QR link preview.
  static const TextStyle monoLabel =
      TextStyle(fontSize: 11, fontFamily: monoFamily);

  /// 18 semibold — dialog/empty-state titles.
  static const TextStyle title =
      TextStyle(fontSize: 18, fontWeight: FontWeight.w600);

  /// 22 semibold — screen headers (contact/channel name).
  static const TextStyle headline =
      TextStyle(fontSize: 22, fontWeight: FontWeight.w600);

  /// 24 bold — onboarding page titles.
  static const TextStyle pageTitle =
      TextStyle(fontSize: 24, fontWeight: FontWeight.bold);

  /// 32 bold — "Meshly" logo on the scan screen.
  static const TextStyle logo =
      TextStyle(fontSize: 32, fontWeight: FontWeight.bold);

  /// Unread-count badge text.
  static const TextStyle badge = TextStyle(
    color: AppColors.onAccent,
    fontSize: 11,
    fontWeight: FontWeight.bold,
  );

  /// Navbar item label (weight/color are animated per state).
  static const TextStyle navLabel = TextStyle(fontSize: 11);

  /// Connection banner text (color comes from colorScheme.onErrorContainer).
  static const TextStyle banner = TextStyle(fontSize: 13);

  /// Settings section header — combine with
  /// `.copyWith(color: Theme.of(context).colorScheme.primary)`.
  static const TextStyle sectionHeader = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.8,
  );
}

// ── ThemeData ─────────────────────────────────────────────────

/// The single app theme, wired into [MaterialApp.theme].
ThemeData buildAppTheme() {
  return ThemeData(
    colorSchemeSeed: AppColors.seed,
    useMaterial3: true,
  );
}
