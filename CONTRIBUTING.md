# Contributing to Meshly

Thanks for your interest in Meshly — a minimal messenger over the Meshtastic
LoRa mesh network. This guide covers everything you need to set up the
project, follow its conventions, and get a change merged. It applies equally
to human contributors and AI coding agents.

## Getting set up

```bash
git clone https://github.com/gazlevodiva/Meshly.git
cd meshly
flutter pub get
flutter run
```

### iOS

```bash
cd ios && pod install && cd ..
flutter run
```

If `pod install` fails, install CocoaPods first: `sudo gem install cocoapods`.
After cloning, set your own Apple Developer Team in Xcode
(`ios/Runner.xcworkspace` → Runner → Signing & Capabilities) before running
on a device.

### Generated files

Generated code (drift `*.g.dart`, `lib/l10n/app_localizations*.dart`) **is
committed** to the repo — you don't need to regenerate anything for a normal
clone-and-run. Only regenerate when you touch the source they're generated
from:

- Edited an `.arb` file (`lib/l10n/app_ru.arb` or `lib/l10n/app_en.arb`) →
  run `flutter gen-l10n`.
- Edited the database schema (`lib/services/app_database.dart`) → run
  `dart run build_runner build --delete-conflicting-outputs`.

Commit the regenerated files alongside your source change.

## Code conventions

These rules are enforced by review and (where possible) CI. Read them before
opening a PR — most rejected changes fail one of these.

1. **Design tokens only.** No raw `Colors.*` (except `Colors.transparent`),
   no numeric `fontSize`, border radii, or icon sizes in `lib/screens/` or
   `lib/widgets/`. Use the named tokens in `lib/theme/app_theme.dart`
   (`AppColorsExt`, `AppSpacing`, `AppRadius`, `AppIconSizes`, `AppSizes`,
   `AppTextStyles`, `AppShapes`). See `design/README.md` for the full token
   catalogue and how to add a new one.
2. **Both themes.** Every screen must look correct in light and dark mode.
   Read colors only from `Theme.of(context).colorScheme` or
   `context.appColors` — never hardcode a color that only makes sense in one
   theme.
3. **Localization.** All user-visible strings go through ARB files
   (`lib/l10n/app_ru.arb` is the source template, keep `lib/l10n/app_en.arb`
   in sync; keys are camelCase) and are read via `context.l10n.<key>`. No
   string literals in UI code. Use ICU plural syntax for pluralization. Run
   `flutter gen-l10n` after any ARB edit and commit the generated output.
4. **Standard widgets — don't reinvent them.**
   - Bottom sheets: `AppShapes.bottomSheet` + `SheetDragHandle`
     (`lib/widgets/sheet_drag_handle.dart`).
   - Sections: `SectionCard` (`lib/widgets/section_card.dart`).
   - QR codes: `QrCard` only (`lib/widgets/qr_card.dart`) — it forces a white
     background, which is required for the code to stay scannable.
   - Pushed screens: `TabGradientBackground` with a transparent `AppBar`
     (`extendBodyBehindAppBar: true`, top padding
     `MediaQuery.paddingOf(context).top + kToolbarHeight`).
5. **Controllers in sheets/dialogs.** A `TextEditingController` used inside a
   bottom sheet or dialog lives in that widget's `State` and is disposed in
   its own `dispose()`. Never dispose it right after `await showDialog(...)`
   or in a `whenComplete` callback — the exit animation is still painting the
   field at that point and this has caused crashes before.
6. **Database changes.** Any schema change to `lib/services/app_database.dart`
   requires: bump `schemaVersion`, add a migration step in `onUpgrade`, then
   `dart run build_runner build --delete-conflicting-outputs`. Note that
   `Messages.meshId` is **not unique** — do not rely on it as a key.
7. **Tests.** New logic in services and utilities (protocol encoding,
   formatting, stores) needs test coverage. Widget tests must pin locale to
   `ru` and register `AppLocalizations.localizationsDelegates`.

## Verification checklist

Run this before opening or updating a PR — it's the same thing CI checks:

```bash
flutter analyze          # must report 0 issues
flutter test              # all tests must pass
dart format .              # run on any files you changed
```

Also do a quick self-check on your diff:

- No raw `Colors.*` / numeric `fontSize:` / hardcoded UI strings in changed
  files under `lib/screens/` or `lib/widgets/`.
- Any new size/color token added to `app_theme.dart` (not a one-off literal).
- Any new user-facing string added to **both** `app_ru.arb` and `app_en.arb`.

## Commit messages

Use [Conventional Commits](https://www.conventionalcommits.org/):
`feat:`, `fix:`, `style:`, `chore:`, `refactor:`, `docs:`, `test:`, `l10n:`,
followed by a short imperative summary, e.g.:

```
fix: correct DM ack handling when radio reconnects
```

## Review process

- Every PR runs CI (`flutter analyze`, `flutter test`, coverage). A PR with a
  failing CI run will not be merged.
- A maintainer reviews the diff for correctness, adherence to the
  conventions above, and scope — this project is intentionally minimal, so
  prefer small, focused PRs over broad refactors bundled with features.
- Screenshots or a short clip are appreciated for UI changes (light + dark).

## Project layout

See [ARCHITECTURE.md](ARCHITECTURE.md) for a full description of the data
flow and folder structure.
