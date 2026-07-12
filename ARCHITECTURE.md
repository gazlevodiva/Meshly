# Architecture

Meshly is a Flutter app that talks to a Meshtastic-firmware device over BLE
GATT, decodes/encodes Meshtastic protobuf frames by hand, and surfaces
messages and contacts through a small set of `ChangeNotifier` stores.

## Data flow

```
 Meshtastic radio (BLE peripheral)
        │  GATT: ToRadio / FromRadio / FromNum (notify)
        ▼
 lib/services/mesh_service.dart        (MeshService)
        │  owns the BLE connection, UUIDs, read/write/notify plumbing
        ▼
 lib/services/meshtastic_proto.dart    (manual protobuf encode/decode)
        │  raw bytes  <->  Meshtastic message structs (packets, node info, ...)
        ▼
 lib/services/mesh_service.dart        (MeshService)
        │  turns decoded packets into app-level events
        │  (incoming message, node seen, ack, ...)
        ▼
 lib/services/contact_store.dart       (ContactStore, drift-backed)
        │  persists to SQLite (drift), holds an in-memory cache,
        │  extends ChangeNotifier
        ▼
 UI (lib/screens/*, lib/widgets/*)
        via ListenableBuilder / ValueListenableBuilder
```

Outbound messages travel the same path in reverse: a screen calls into
`MeshService`, which builds a Meshtastic packet via
`meshtastic_proto.dart` and writes it to the `ToRadio` GATT characteristic.

## The manually-encoded protobuf layer

There is no official Meshtastic Dart/Flutter package, so
`lib/services/meshtastic_proto.dart` hand-rolls the wire format for the
subset of Meshtastic protobuf messages the app needs (packets, node info,
channel settings, acks). This is the most delicate part of the codebase:

- It has to match the exact field numbers and wire types Meshtastic firmware
  expects — there's no schema to check against at compile time.
- LoRa text packets are capped at roughly 200 bytes of UTF-8 payload; message
  composition and truncation logic has to respect that limit.
- Any change here should come with a unit test that round-trips
  encode → decode against known-good byte sequences, since a subtle mistake
  won't surface until you're talking to real hardware.

`lib/services/mesh_service.dart` owns the BLE device UUIDs (service,
ToRadio, FromRadio, FromNum) and the connection lifecycle; it's the only
place that should touch `flutter_blue_plus` directly.

## End-to-end DM encryption

Direct messages between two Meshly installs are end-to-end encrypted;
channel messages are unaffected and still rely on the Meshtastic channel
PSK.

- **`lib/services/crypto_service.dart`** (`CryptoService`) owns the
  device's X25519 identity keypair. The private key is generated on first
  run and stored only via `flutter_secure_storage` (Keychain on iOS,
  Keystore on Android) — it never touches the drift database. The pure
  crypto functions (`generateKeyPair`/`encryptFor`/`decryptFrom`) are
  key-bytes-in/bytes-out so they can be unit-tested without touching secure
  storage.
- **Envelope**: static ECDH (`X25519(myPrivate, peerPublic)`) derives a
  shared secret; XChaCha20-Poly1305 AEAD with a fresh random 24-byte nonce
  per message encrypts and authenticates the plaintext. Wire format is
  `[version:1][nonce:24][ciphertext+MAC]`, roughly 41 bytes of overhead on
  top of the plaintext. There is no ratchet — no forward secrecy — a
  deliberate tradeoff for an unreliable, unordered LoRa transport with no
  session handshake.
- **Key distribution**: a contact's X25519 public key is bundled into the
  QR payload alongside their node ID (see `lib/services/qr_service.dart`),
  so a key is only known once you've scanned that contact's QR in person
  (or received theirs). `ContactStore`/drift persists the peer's public key
  per contact (`app_database.dart`).
- **Wire framing**: encrypted DM envelopes are sent as Meshtastic packets
  with `portnum = MeshtasticProto.PRIVATE_APP` (256) instead of the normal
  `TEXT_MESSAGE_APP`. This is intentional — the stock Meshtastic app and
  other firmware clients don't recognize `PRIVATE_APP` and will ignore
  these packets, so encrypted DMs no longer interoperate with non-Meshly
  clients. `MeshService.sendText` returns `SendResult.needsKey` instead of
  sending in the clear when the peer's public key isn't known yet; an
  incoming DM that fails to decrypt (missing key, corruption, or a
  plaintext DM from a non-Meshly sender) is stored with the
  `kUndecryptableSentinel` text placeholder rather than being dropped or
  shown garbled.

## Reactive store pattern

State that the UI needs to react to lives in singleton `ChangeNotifier`s,
not in widget `State`:

- `ContactStore` (`lib/services/contact_store.dart`) — contacts, channels,
  conversations, messages. Backed by drift/SQLite, with an in-memory cache
  so reads are synchronous for the UI.
- `NotificationSettings` (`lib/services/notification_settings.dart`)
- `ThemeController` (`lib/services/theme_controller.dart`)
- `LocaleController` (`lib/services/locale_controller.dart`)

Widgets subscribe with `ListenableBuilder` or `ValueListenableBuilder` and
never call `setState` to mirror store data — the store notifies, and that's
the only source of rebuilds for that data.

Settings persistence follows **persist-first, then notify**: write to
`SharedPreferences` (or the DB) first, roll back the in-memory value if the
write fails, and only call `notifyListeners()` after the persisted state is
consistent with the in-memory state. `notification_settings.dart` is the
reference implementation of this pattern.

## Storage (drift)

`lib/services/app_database.dart` defines the schema (drift/SQLite): tables
for `Contacts`, `Channels`, `Conversations`, `Messages`, and `BlockedNodes`.
Notable points:

- `Messages.id` is a surrogate autoincrement key — `meshId` is **not
  unique** (packets without an id all arrive as `meshId == 0`, and
  radio-assigned ids can collide over time), so it must never be used as a
  primary key.
- Schema changes bump `schemaVersion` and add a step to `onUpgrade`; the
  generated `app_database.g.dart` is committed and regenerated via
  `dart run build_runner build --delete-conflicting-outputs`.

## Theming and localization

- All design values (colors, spacing, radii, icon sizes, text styles) are
  centralized in `lib/theme/app_theme.dart` as named tokens
  (`AppColorsExt`, `AppSpacing`, `AppRadius`, `AppIconSizes`, `AppSizes`,
  `AppTextStyles`, `AppShapes`). Screens and widgets consume tokens only —
  see `design/README.md` for the full catalogue and rationale.
- Both a light and a dark `ThemeData` are built (`buildLightTheme()` /
  `buildDarkTheme()`); `ThemeController` picks the active mode and persists
  the choice.
- All user-facing strings live in ARB files (`lib/l10n/app_ru.arb` is the
  source template, `lib/l10n/app_en.arb` the translation) and are accessed
  via `context.l10n.<key>`; generated localization delegates
  (`lib/l10n/app_localizations*.dart`) are committed and regenerated with
  `flutter gen-l10n`.

## Folder map

```
lib/
├── main.dart
├── l10n/        ARB source (app_ru.arb, app_en.arb) + generated delegates
├── models/      Contact, MeshChannel, Conversation, Message
├── screens/     one file per screen, all on the current design
├── services/    BLE, Meshtastic protobuf, drift DB, notifications,
│                theme/locale controllers, contact store
├── theme/       app_theme.dart — every design token
├── utils/       date_format.dart — localized dates, ICU pluralization
└── widgets/     shared widgets: SectionCard, QrCard, ListAvatar,
                 TabHeader / TabGradientBackground, FloatingNavBar,
                 SheetDragHandle
```

## Known limitations

These are accepted trade-offs, not bugs — see `README.md` → *Security &
Privacy* for the user-facing version:

- **DM privacy**: direct messages currently travel over the primary channel
  (slot 0) using Meshtastic's default, well-known PSK. Anyone running
  Meshtastic nearby can decrypt them. Don't treat DMs as private yet.
- **Channel ACKs**: a delivery ack in a group channel is only ever observed
  from the local radio's own transmission — there is no second "read by
  peer" checkmark for channels the way there is for DMs.
- Push notifications work in the foreground reliably; background BLE
  wake-up on iOS needs additional native work.
