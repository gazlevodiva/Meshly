import 'package:flutter/material.dart';

/// Central design tokens for Meshly.
///
/// Screens and widgets must never use raw `Colors.*`, `fontSize:`,
/// `BorderRadius.circular(<number>)` or magic paddings — everything visual
/// lives here. Material `ColorScheme` roles (primary, error, errorContainer,
/// surfaceContainerHighest, primaryContainer, ...) are intentionally NOT
/// duplicated: keep using `Theme.of(context).colorScheme` for those.
///
/// Semantic colors that Material does not cover live in [AppColorsExt] — a
/// `ThemeExtension` with a light and a dark instance, resolved per-theme via
/// `context.appColors`.

// ── Semantic colors (theme extension) ─────────────────────────

/// Semantic colors that are not covered by the Material [ColorScheme].
///
/// Registered on both themes in [buildLightTheme]/[buildDarkTheme];
/// read them in widgets via `context.appColors.<token>`.
@immutable
class AppColorsExt extends ThemeExtension<AppColorsExt> {
  const AppColorsExt({
    required this.online,
    required this.offline,
    required this.textSecondary,
    required this.iconSecondary,
    required this.dragHandle,
    required this.warning,
    required this.danger,
    required this.brand,
    required this.onAccent,
    required this.qrCardBackground,
    required this.qrCardShadow,
    required this.islandShadow,
  });

  /// Green "online" indicator (dots, "В сети" label, strong signal).
  final Color online;

  /// Grey "offline" indicator (dots, "Не в сети" label).
  final Color offline;

  /// Secondary/dimmed text (captions, hints, subtitles).
  final Color textSecondary;

  /// Dimmed icons (info rows, muted bell, disabled bluetooth...).
  final Color iconSecondary;

  /// Bottom-sheet drag handle.
  final Color dragHandle;

  /// Warning accent — block/blocked actions, medium signal.
  final Color warning;

  /// Hard failure accent — failed message status, weak signal.
  final Color danger;

  /// Brand blue used for standalone icons/acked checkmarks
  /// (kept separate from colorScheme.primary on purpose — the seeded
  /// scheme derives a different tone than the raw brand blue).
  final Color brand;

  /// Content drawn on top of accent-colored fills
  /// (message bubble text, unread badge text, spinner on FilledButton).
  final Color onAccent;

  /// QR-code card background — always white so codes stay scannable.
  final Color qrCardBackground;

  /// Soft shadow under the QR card.
  final Color qrCardShadow;

  /// Shadow under the floating navigation island.
  final Color islandShadow;

  /// Light-theme palette.
  static const light = AppColorsExt(
    online: Colors.green,
    offline: Colors.grey,
    textSecondary: Colors.grey,
    iconSecondary: Colors.grey,
    dragHandle: Color(0xFFE0E0E0),
    warning: Colors.orange,
    danger: Colors.red,
    brand: Color(0xFF2F6BFF),
    onAccent: Colors.white,
    qrCardBackground: Colors.white,
    qrCardShadow: Color(0x14000000),
    islandShadow: Color(0x24000000),
  );

  /// Dark-theme palette (deep navy-graphite surfaces, vivid blue accent).
  static const dark = AppColorsExt(
    online: Color(0xFF4ADE80),
    offline: Color(0xFF6B7280),
    textSecondary: Color(0xFF8B95A5),
    iconSecondary: Color(0xFF8B95A5),
    dragHandle: Color(0xFF3A4149),
    warning: Color(0xFFFFB74D),
    danger: Color(0xFFEF5350),
    brand: Color(0xFF2F6BFF),
    onAccent: Colors.white,
    qrCardBackground: Colors.white,
    qrCardShadow: Color(0x66000000),
    islandShadow: Color(0x59000000),
  );

  @override
  AppColorsExt copyWith({
    Color? online,
    Color? offline,
    Color? textSecondary,
    Color? iconSecondary,
    Color? dragHandle,
    Color? warning,
    Color? danger,
    Color? brand,
    Color? onAccent,
    Color? qrCardBackground,
    Color? qrCardShadow,
    Color? islandShadow,
  }) {
    return AppColorsExt(
      online: online ?? this.online,
      offline: offline ?? this.offline,
      textSecondary: textSecondary ?? this.textSecondary,
      iconSecondary: iconSecondary ?? this.iconSecondary,
      dragHandle: dragHandle ?? this.dragHandle,
      warning: warning ?? this.warning,
      danger: danger ?? this.danger,
      brand: brand ?? this.brand,
      onAccent: onAccent ?? this.onAccent,
      qrCardBackground: qrCardBackground ?? this.qrCardBackground,
      qrCardShadow: qrCardShadow ?? this.qrCardShadow,
      islandShadow: islandShadow ?? this.islandShadow,
    );
  }

  @override
  AppColorsExt lerp(ThemeExtension<AppColorsExt>? other, double t) {
    if (other is! AppColorsExt) return this;
    return AppColorsExt(
      online: Color.lerp(online, other.online, t)!,
      offline: Color.lerp(offline, other.offline, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
      iconSecondary: Color.lerp(iconSecondary, other.iconSecondary, t)!,
      dragHandle: Color.lerp(dragHandle, other.dragHandle, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      danger: Color.lerp(danger, other.danger, t)!,
      brand: Color.lerp(brand, other.brand, t)!,
      onAccent: Color.lerp(onAccent, other.onAccent, t)!,
      qrCardBackground:
          Color.lerp(qrCardBackground, other.qrCardBackground, t)!,
      qrCardShadow: Color.lerp(qrCardShadow, other.qrCardShadow, t)!,
      islandShadow: Color.lerp(islandShadow, other.islandShadow, t)!,
    );
  }
}

/// Sugar for reading the semantic palette: `context.appColors.online`.
///
/// Falls back to the brightness-matching default palette when the ambient
/// theme was built without the extension (plain `MaterialApp` in tests).
extension AppColorsContext on BuildContext {
  AppColorsExt get appColors =>
      Theme.of(this).extension<AppColorsExt>() ??
      (Theme.of(this).brightness == Brightness.dark
          ? AppColorsExt.dark
          : AppColorsExt.light);
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

  /// Bottom list padding that keeps content clear of the floating navbar.
  static const double listBottomPadding = 96;

  /// Bottom padding of the chat message list so the last bubble scrolls
  /// clear of the floating input bar.
  static const double chatListBottomPadding = 88;
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

  /// Large surface cards (scan-screen info card / device cards).
  static const double cardLarge = 16;

  /// Chat message bubble.
  static const double bubble = 18;

  /// Small "tail" corner of a chat bubble — the corner nearest the sender
  /// (bottom-left for incoming, bottom-right for outgoing).
  static const double bubbleTail = 4;

  /// Modal bottom sheet (top corners).
  static const double sheet = 20;

  /// Rounded message input field.
  static const double input = 24;

  /// Floating navigation island.
  static const double island = 28;

  /// Fully-rounded capsules (status pill, nav pills, inline search field).
  static const double pill = 100;
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

  /// Hero bluetooth icon inside the scan-screen circle.
  static const double hero = 36;
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
  static const double avatarList = 48; // conversation/contact list cards
  static const double avatarChatHeader = 40; // chat-screen header avatar
  static const double avatarChatBubble = 28; // sender avatar next to a bubble
  static const double avatarLarge = 96; // edit-contact header
  static const double avatarEditBadge = 28; // pencil badge on avatar

  /// Emoji font inside the small per-bubble sender avatar.
  static const double emojiChatBubble = 16;

  /// Chat bubble max width as a fraction of screen width.
  static const double bubbleMaxWidthFraction = 0.75;

  // QR codes.
  static const double qrMedium = 200;
  static const double qrLarge = 220;

  // Inline progress spinners inside buttons.
  static const double spinnerSmall = 18;
  static const double spinner = 20;
  static const double spinnerStroke = 2;

  /// Blur radius of the soft shadow under the floating chat input pill.
  static const double inputShadowBlur = 12;

  // Bottom-sheet drag handle.
  static const double handleWidth = 36;
  static const double handleHeight = 4;

  // Onboarding page indicator.
  static const double pageDot = 8;
  static const double pageDotActiveWidth = 20;

  // Emoji picker dialog content width.
  static const double emojiDialogWidth = 280;

  // Scan-screen hero: filled circle + two concentric translucent rings.
  static const double heroCircle = 96;
  static const double heroRingInner = 140;
  static const double heroRingOuter = 180;

  /// Leading rounded-square tile in scan-screen cards.
  static const double leadingTile = 48;

  /// Full-width pill CTA button height (stadium shape → radius 28).
  static const double ctaHeight = 56;

  /// Round header action button (search / add) on the main tabs.
  static const double headerButton = 44;

  // Signal-strength bars (4 ascending bars in the device list).
  static const double signalBarWidth = 3;
  static const double signalBarGap = 2;
  static const double signalBarMinHeight = 5;
  static const double signalBarStep = 3;
}

// ── Opacities ─────────────────────────────────────────────────

/// Alpha values applied to theme colors (`color.withValues(alpha: ...)`).
abstract final class AppOpacities {
  /// Inner translucent ring around the scan-screen hero circle.
  static const double ringInner = 0.12;

  /// Outer translucent ring around the scan-screen hero circle.
  static const double ringOuter = 0.07;

  /// Tinted background of the active nav-bar pill (over primary) —
  /// the light end of its gradient.
  static const double navPillTint = 0.14;

  /// The stronger end of the active nav-bar pill gradient (over primary).
  static const double navPillTintStrong = 0.28;

  /// Inactive nav-bar item icon/label (over onSurface).
  static const double navInactive = 0.45;

  /// Time / status-icon metadata drawn on the accent-colored outgoing bubble
  /// (over [AppColorsExt.onAccent]).
  static const double bubbleMeta = 0.7;
}

// ── Text styles ───────────────────────────────────────────────

/// Recurring inline text styles.
///
/// Styles whose color depends on the active theme are methods taking a
/// [BuildContext]; theme-independent styles stay `const`.
abstract final class AppTextStyles {
  /// Monospace family for node IDs / keys / links.
  static const String monoFamily = 'monospace';

  /// Default-size secondary (grey) text.
  static TextStyle secondary(BuildContext context) =>
      TextStyle(color: context.appColors.textSecondary);

  /// 11 grey — tiny labels (info-row captions, timestamps).
  static TextStyle label(BuildContext context) =>
      TextStyle(fontSize: 11, color: context.appColors.textSecondary);

  /// 12 grey — captions.
  static TextStyle caption(BuildContext context) =>
      TextStyle(fontSize: 12, color: context.appColors.textSecondary);

  /// 13 plain — compact body text (last message preview, info values).
  static const TextStyle body = TextStyle(fontSize: 13);

  /// 13 grey — subtitles / helper text.
  static TextStyle subtitle(BuildContext context) =>
      TextStyle(fontSize: 13, color: context.appColors.textSecondary);

  /// 14 grey — hints on the scan screen.
  static TextStyle hint(BuildContext context) =>
      TextStyle(fontSize: 14, color: context.appColors.textSecondary);

  /// 16 grey — onboarding body text.
  static TextStyle bodyLargeSecondary(BuildContext context) =>
      TextStyle(fontSize: 16, color: context.appColors.textSecondary);

  /// Monospace, default size (blocked node IDs).
  static const TextStyle mono = TextStyle(fontFamily: monoFamily);

  /// 12 grey monospace — node IDs in dialogs/cards.
  static TextStyle monoCaption(BuildContext context) => TextStyle(
        fontSize: 12,
        color: context.appColors.textSecondary,
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
  static TextStyle badge(BuildContext context) => TextStyle(
        color: context.appColors.onAccent,
        fontSize: 11,
        fontWeight: FontWeight.bold,
      );

  /// Navbar item label (weight/color are animated per state).
  static const TextStyle navLabel = TextStyle(fontSize: 11);

  /// 13 medium — connection status pill text (color set per state).
  static const TextStyle statusPill =
      TextStyle(fontSize: 13, fontWeight: FontWeight.w500);

  /// 16 semibold — conversation/contact card title
  /// (bumps to w700 when the conversation has unread messages).
  static const TextStyle cardTitle =
      TextStyle(fontSize: 16, fontWeight: FontWeight.w600);

  /// 34 bold — big tab headers ("Meshly", "Контакты").
  static const TextStyle headerTitle =
      TextStyle(fontSize: 34, fontWeight: FontWeight.bold);

  /// Settings section header — combine with
  /// `.copyWith(color: Theme.of(context).colorScheme.primary)`.
  static const TextStyle sectionHeader = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.8,
  );
}

// ── ThemeData ─────────────────────────────────────────────────

/// Vivid brand blue that anchors both themes.
const Color _brandBlue = Color(0xFF2F6BFF);

/// The light theme, wired into [MaterialApp.theme].
///
/// Primary is pinned to the same vivid brand blue as the dark theme so
/// accents (CTA, "+" button, links) look identical in both modes.
ThemeData buildLightTheme() {
  final scheme = ColorScheme.fromSeed(seedColor: _brandBlue).copyWith(
    primary: _brandBlue,
    onPrimary: Colors.white,
  );
  return ThemeData(
    colorScheme: scheme,
    useMaterial3: true,
    // Material You sparkle: soft radial shimmer instead of a flat
    // primary-tinted splash rectangle.
    splashFactory: InkSparkle.splashFactory,
    extensions: const [AppColorsExt.light],
  );
}

/// The dark theme, wired into [MaterialApp.darkTheme].
///
/// `ColorScheme.fromSeed` alone drifts into purple-grey surfaces, so the
/// surface roles are pinned to a deep navy-graphite ramp and the primary to
/// the vivid brand blue.
ThemeData buildDarkTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: _brandBlue,
    brightness: Brightness.dark,
  ).copyWith(
    primary: _brandBlue,
    onPrimary: Colors.white,
    primaryContainer: const Color(0xFF1C355F),
    onPrimaryContainer: const Color(0xFFD6E3FF),
    surface: const Color(0xFF0B1017),
    onSurface: const Color(0xFFE6EAF2),
    onSurfaceVariant: const Color(0xFF8B95A5),
    surfaceContainerLowest: const Color(0xFF070B10),
    surfaceContainerLow: const Color(0xFF121822),
    surfaceContainer: const Color(0xFF161D27),
    surfaceContainerHigh: const Color(0xFF1B2330),
    surfaceContainerHighest: const Color(0xFF212A38),
    outlineVariant: const Color(0xFF2A3341),
  );
  return ThemeData(
    colorScheme: scheme,
    useMaterial3: true,
    splashFactory: InkSparkle.splashFactory,
    extensions: const [AppColorsExt.dark],
  );
}
