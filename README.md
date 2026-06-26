# Meshly

A simple messenger built on top of the [Meshtastic](https://meshtastic.org/) LoRa mesh network. Designed for families — minimal UI, one tap to connect and chat.

> **Goal:** Strip everything unnecessary from the official Meshtastic app and leave just one thing — send a message. Your mom should be able to use it on the first try.

## Features

- Connect to a Meshtastic device over BLE (Bluetooth Low Energy)
- Group channel chat and direct messages (DM)
- Add contacts via QR code or manual Node ID entry
- Share your contact QR code with others
- Online/offline indicator (based on last heard time)
- Local push notifications for incoming messages
- SQLite storage — data persists across sessions
- Android + iOS

## Hardware

Tested with **Heltec MeshPocket** (ESP32 + LoRa). Should work with any Meshtastic-compatible device that supports BLE.

## Requirements

- Flutter 3.x
- Android 6.0+ (API 23) or iOS 16+
- A Meshtastic BLE device

## Getting Started

```bash
git clone https://github.com/YOUR_USERNAME/meshly.git
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
- ⚠️ Push notifications work in foreground only — background BLE on iOS requires additional native setup
- ⚠️ Protobuf encoding is implemented manually (no official Meshtastic Dart package exists)
- ⚠️ iOS free developer certificate expires every 7 days — use Apple Developer Program ($99/yr) for permanent install

## Contributing

Issues and PRs are welcome. The project is intentionally minimal — the goal is simplicity, not features.

## License

MIT
