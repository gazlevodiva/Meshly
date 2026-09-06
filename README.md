<img src="assets/logo/logo.png" width="88" alt="Meshly">

# Meshly

[![CI](https://github.com/gazlevodiva/Meshly/actions/workflows/ci.yml/badge.svg)](https://github.com/gazlevodiva/Meshly/actions/workflows/ci.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![Flutter](https://img.shields.io/badge/Flutter-3.x-02569B?logo=flutter)](https://flutter.dev)

A simple messenger built on top of the [Meshtastic](https://meshtastic.org/) LoRa mesh network. Designed for people you trust — minimal UI, one tap to connect and chat.

> **Goal:** Strip everything unnecessary from the official Meshtastic app and leave just one thing — send a message. Your mom should be able to use it on the first try.

## Features

- Connect to a Meshtastic device over BLE (Bluetooth Low Energy)
- Set the radio's LoRa region from inside the app — a factory-fresh board
  stays silent on air until this is chosen, and Meshly no longer needs
  another app to get you on the air
- Direct chats, end-to-end encrypted per contact
- Group conversations, as many as you like — they are not tied to the
  radio's eight hardware channel slots
- Add people by scanning their QR code (or by typing a device ID)
- Detects when a chat's encryption breaks — a peer reinstalled the app, say
  — explains it, and walks both sides through fixing it
- Delivery marks that claim only what they can prove
- Local notifications for incoming messages
- Data persists across restarts
- Android + iOS

## How Meshly differs from the Meshtastic app

Meshly is not a lighter skin over the official app — the two do not talk to
each other, deliberately.

**Meshly speaks only to Meshly.** Its traffic rides a private port that the
stock app does not recognise and silently ignores, and Meshly ignores
plaintext traffic in return. The default public channel that the official
app opens on does not appear here at all.

**Encryption is Meshly's own layer, above the radio.** Direct chats use a
key pair per contact, exchanged by scanning a QR code in person; group
conversations use their own key derived from the conversation's secret.
None of it depends on how the radio is configured, so a misconfigured
device cannot quietly downgrade it.

**Conversations are not channel slots.** Meshtastic radios have eight
channel slots, and the official app maps groups onto them. Meshly puts the
conversation's identity in its own encrypted payload instead, so the number
of conversations is limited by nothing, and which conversations you belong
to no longer travels in the clear.

**Everything else is missing on purpose.** No map, no node list, no
telemetry, no waypoints, no MQTT, no mesh administration. Those are the
reasons the official app exists and it does them well; this one is a
messenger for people you already trust.

What you give up: interoperability. Someone running the official app cannot
read a Meshly message, and vice versa. Both apps can share the same radio
hardware, but not the same conversation.

## Hardware

Tested with **Heltec MeshPocket** (ESP32 + LoRa). Should work with any Meshtastic-compatible device that supports BLE.

## Requirements

- Flutter 3.x
- Android 7.0+ (API 24) or iOS 16+
- A Meshtastic BLE device

## Getting Started

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

If pod install fails, install CocoaPods first: `sudo gem install cocoapods`

### iOS signing

After cloning, set your Apple Developer Team in Xcode:
1. Open `ios/Runner.xcworkspace`
2. Select **Runner** → **Signing & Capabilities**
3. Set your **Team**

## Building a release APK (Android)

```bash
flutter build apk --release
# APK: build/app/outputs/flutter-apk/app-release.apk
adb install build/app/outputs/flutter-apk/app-release.apk
```

## Project Structure

```
lib/
├── main.dart
├── models/          # Contact, Channel, Conversation, Message
├── screens/         # UI screens
├── services/        # BLE, Meshtastic protocol, SQLite, notifications
└── widgets/         # Reusable UI components

assets/logo/         # the mark, and how it is generated (see its README)
tool/                # generate_icons.py — builds every app icon from the SVGs
```

## Regenerating database code

After changing schema in `lib/services/app_database.dart`:

```bash
dart run build_runner build --delete-conflicting-outputs
```

## Tech Stack

- **Flutter + Dart** — cross-platform (Android + iOS)
- **flutter_blue_plus** — BLE connection
- **drift** — SQLite ORM
- **flutter_local_notifications** — push notifications
- **mobile_scanner** / **qr_flutter** — QR codes
- Manual protobuf encoding/decoding for Meshtastic packets

## Meshtastic BLE UUIDs

UUIDs used by the Heltec MeshPocket (may differ from standard Meshtastic firmware):

| Name            | UUID                                   |
|-----------------|----------------------------------------|
| Service         | `6ba1b218-15a8-461f-9fa8-5dcae273eafd` |
| ToRadio (TX)    | `f75c76d2-129e-4dad-a1dd-7866124401e7` |
| FromRadio (RX)  | `2c55e69e-4993-11ed-b878-0242ac120002` |
| FromNum (notify)| `ed9da18c-a800-4f66-a670-aa7547e34453` |

If your device uses different UUIDs, update the constants in `lib/services/mesh_service.dart`.

## Status & Known Limitations

- ✅ Tested on Android (Samsung S901B, Android 16) and iOS (iPhone 14, iOS 26)
- ✅ Tested with Heltec MeshPocket over BLE
- ⚠️ Group conversations have no member list and nobody can be removed from one: everyone shares a single key, and the app cannot know who holds it (see [SECURITY.md](SECURITY.md) for why that's a hard limit, not a missing UI)
- ⚠️ Push notifications work in foreground only — background BLE on iOS requires additional native setup
- ⚠️ Protobuf encoding is implemented manually (no official Meshtastic Dart package exists)
- ⚠️ iOS free developer certificate expires every 7 days — use Apple Developer Program ($99/yr) for permanent install

## Architecture

See [ARCHITECTURE.md](ARCHITECTURE.md) for the data flow (BLE → protobuf → services → reactive UI), the manual Meshtastic protobuf layer, the drift schema/migrations, and the theming/localization layers.

## Security & Privacy

Be honest with yourself about what this protects. Both direct chats and
group conversations are encrypted with Meshly's own layer (not Meshtastic's), so
message content is opaque to the stock Meshtastic app and to anyone else on
the mesh. What that does *not* cover: metadata (who talks to whom, when),
forward secrecy, and plaintext storage of message history and conversation keys
on the phone itself. The full threat model, the secure-chat recovery
mechanism, and how to report a vulnerability are in
[SECURITY.md](SECURITY.md) — read it before trusting Meshly with anything
sensitive.

## Contributing

Issues and PRs are welcome. The project is intentionally minimal — the goal is simplicity, not features. Read [CONTRIBUTING.md](CONTRIBUTING.md) for the dev setup, code conventions (design tokens, both themes, ARB localization), and the verification checklist.

## License

MIT
