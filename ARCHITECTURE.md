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

## Meshly encryption (DMs and channels)

Both direct messages and group channels between Meshly installs use Meshly's
own AEAD and travel over `PRIVATE_APP`, so neither is visible to the stock
Meshtastic app. DMs and channels share one symmetric core
(`_encryptSymmetric`/`_decryptSymmetric`) and one envelope format; only the
key derivation differs (ECDH shared secret for DMs, HKDF-of-PSK for channels).

- **`lib/services/crypto_service.dart`** (`CryptoService`) owns the
  device's X25519 identity keypair. The private key is generated on first
  run and stored only via `flutter_secure_storage` (Keychain on iOS,
  Keystore on Android) — it never touches the drift database. The pure
  crypto functions (`generateKeyPair`/`encryptFor`/`decryptFrom`,
  `deriveChannelKey`/`encryptForChannel`/`decryptForChannel`) are
  bytes-in/bytes-out so they can be unit-tested without touching secure
  storage.
- **Envelope**: XChaCha20-Poly1305 AEAD with a fresh random 24-byte nonce
  per message encrypts and authenticates the plaintext. Wire format is
  `[version:1][nonce:24][ciphertext+MAC]`, roughly 41 bytes of overhead on
  top of the plaintext (constant `kEnvelopeOverhead` in `chat_screen.dart`
  reserves it in the input byte budget for both DMs and channels). There is
  no ratchet — no forward secrecy — a deliberate tradeoff for an unreliable,
  unordered LoRa transport with no session handshake.
- **DM key**: static ECDH (`X25519(myPrivate, peerPublic)`) derives the
  shared secret fed into the AEAD core.
- **Channel key**: `HKDF-SHA256(secretKey: channel PSK,
  info: "meshly-channel-v1", outputLength: 32)` (`deriveChannelKey`). The
  PSK is the existing `MeshChannel.psk` — the channel QR format and DB schema
  are unchanged, so no re-scanning is needed. The fixed `info` string is a
  domain separation from the firmware's own PSK usage, so the Meshly channel
  key never coincides with the firmware channel key. This is a *group* secret:
  every member shares one key, so any member can decrypt and can forge a
  message as any other member (no in-group sender authentication), there is no
  forward secrecy, and revoking a member requires rotating the PSK. Meshly
  drops any inbound plaintext (`TEXT_MESSAGE_APP`) broadcast, so the default
  public channel and non-Meshly senders are never shown.
- **Key distribution**: a contact's X25519 public key is bundled into the
  QR payload alongside their node ID (see `lib/services/qr_service.dart`),
  so a key is only known once you've scanned that contact's QR in person
  (or received theirs). `ContactStore`/drift persists the peer's public key
  per contact (`app_database.dart`).
- **Wire framing**: both DM and channel envelopes are sent as Meshtastic
  packets with `portnum = MeshtasticProto.PRIVATE_APP` (256) instead of the
  normal `TEXT_MESSAGE_APP` (DMs unicast to the peer, channels broadcast on
  the channel's slot). This is intentional — the stock Meshtastic app and
  other firmware clients don't recognize `PRIVATE_APP` and will ignore these
  packets, so Meshly traffic no longer interoperates with non-Meshly clients.
  `MeshService.sendText` returns `SendResult.needsKey` instead of sending in
  the clear when a DM peer's public key isn't known yet. On receive
  (`_onBytesReceived`): an incoming channel packet is only accepted if it is
  `PRIVATE_APP` and decrypts under the channel PSK — anything else (plaintext
  broadcast, wrong/unknown channel, auth failure) is silently dropped without
  notifying. Unicast packets go through the DM path described below.
- **Service packets**: version bytes `0x02..0x04` on `PRIVATE_APP` are
  reserved for the secure-chat state machine and never carry user text —
  `[0x02]` is the bare "I cannot decrypt you" notice, `[0x03]`/`[0x04]` are
  the encrypted verify ping/ack. They are recognised by their version byte
  *before* any decryption attempt, so they never reach the message path. See
  `SECURITY.md` → *Secure-chat service packets* for the threat model.

## Secure chat state (DMs)

A DM conversation stores two booleans of state (`lib/models/conversation.dart`,
persisted in `Conversations`): `iCanReadPeer` — our copy of the peer's identity
key still decrypts what they send — and `peerCanReadUs` — they hold our current
public key. Both start optimistic (`true`). A third boolean, `writeAnyway`,
records the user's override rather than the chat's state (see below).

`Conversation.secureOk` is the derived `iCanReadPeer && peerCanReadUs`, and it
is the single source of truth for everything user-visible: the in-chat recovery
card, the hint in the chat list, and the send block in `MeshService.sendText`
(which returns `SendResult.needsKey` unless `force: true`). Nothing re-derives
the state from raw flags, and the flags never influence key selection,
decryption, or trust — only the UI and the send/don't-send decision.

What moves the flags:

- A regular envelope (`[0x01]`) that **decrypts** proves both directions at
  once — ECDH is symmetric, so a readable message means our stored key is
  right *and* the peer encrypted to our current public key. Both flags are set
  (`markSecureVerified`).
- A verify packet (`[0x03]`/`[0x04]`) that authenticates proves the same thing
  and marks the chat healthy; a ping is answered with an ack, an ack is never
  answered (that asymmetry bounds the exchange at two packets).
- A real envelope we **cannot** decrypt is the only honest proof that our copy
  of the peer's key is stale: the very first such failure clears
  `iCanReadPeer`, any placeholder rows left by older builds are
  purged, and a rate-limited `[0x02]` notice tells the peer to re-share their
  QR. There is deliberately no "N failures in a row" threshold — `from` is
  forgeable, so a threshold buys no security against anyone able to forge one
  packet, while it made the honest case (the peer reinstalled) cost several
  messages sent into the void before the recovery card appeared.
  The undecryptable message itself is **not stored** — earlier versions
  saved a `kUndecryptableSentinel` placeholder bubble per junk packet, which
  flooded the thread; the constant survives only to render and clean up such
  legacy rows.
- A received `[0x02]` clears `peerCanReadUs` only — it says the *peer* cannot
  read us, which does not invalidate our own scan of them.
- A QR scan of the peer optimistically sets `iCanReadPeer`; a stale QR
  self-corrects on the next unreadable packet.

### When a verify ping is sent

There is one rule and one entry point, `MeshService.announceSecureState`:

> Send a verify ping whenever our view of a chat's health may have drifted
> apart from the peer's view of it.

Three occasions qualify, and no others:

- **(a) we just learned the peer's key** — their QR was scanned
  (`add_contact_screen`);
- **(b) we opened a chat we consider broken** (`chat_screen`) — LoRa
  acknowledges nothing, so an earlier ping may simply have evaporated;
- **(c) our view just became healthy** — something of theirs decrypted, but
  they cannot know that. Tracked in `MeshService`, not in the UI: the flags are
  read *before* `markSecureVerified` so only a real broken → healthy
  **transition** announces. Without (c), a lost ack left the other device's
  recovery card up forever while both sides were in fact fine.

The transition condition is what bounds the exchange: a side that is already
healthy answers a ping with one ack and announces nothing, so ping → ack →
ping cannot recur. Per-peer throttling (60 s) is a second line of defence, not
the mechanism. `test/mesh_service_test.dart` wires two services' radios
together and asserts the handshake converges and stops.

Because the breakage signal is unauthenticated, the user always keeps a
**"send anyway"** escape hatch, and pressing it is remembered: `writeAnyway` is
persisted per conversation (column `write_anyway`) and is what `chat_screen`
passes as `force:` to `MeshService.sendText`. A per-visit override meant the
chat re-blocked itself every time the user left and came back. It is cleared
when the conversation returns to a healthy state (both flags true again), so
the next genuine breakage shows the recovery card as usual — `ContactStore`
enforces that invariant centrally rather than at each call site.

The receive path is deliberately narrow (`_onDmPacket`). A unicast packet is
considered only if it is addressed to *our* node (`to == _myNodeNum`; while our
own node num is still unknown the packet is dropped), is on `PRIVATE_APP`, has
a non-empty payload, comes from a contact we have actually scanned, and a DM
conversation for that contact already exists. The addressee check matters
beyond attacks: the radio also hands up unicasts it merely overheard or
relayed, so two of our own contacts chatting with each other used to fail
decryption here and flag a healthy chat broken. Everything else is dropped
silently: no flag moves, and **incoming packets never create a conversation**,
so strangers and stock-Meshtastic traffic cannot conjure phantom chats (least
of all ones flagged as broken) in the chat list.

One narrow exception concerns *unknown* senders. A packet that passes every
other filter — our port, addressed to us, non-empty, and carrying the ordinary
message version byte `[0x01]` — is answered with a `[0x02]`, because it looks
like a genuine Meshly DM from someone whose contact entry we no longer have.
That is the wiped-device case: without the reply the sender sees two ticks from
their own radio and believes the message arrived, while nobody learns anything.
Service bytes (`[0x02]`/`[0x03]`/`[0x04]`) and unknown version bytes are
answered with nothing. The invariant is unchanged — **no state is created for
unknown nodes**: no contact, no conversation, no message, no notification, and
nothing appears in the UI. The reply shares the global reactive-packet budget.

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
- `Conversations` carries the two secure-chat facts (`iCanReadPeer`,
  `peerCanReadUs`), both defaulting to `true`, plus `write_anyway`
  (`writeAnyway`, default `false`) — the persisted "send anyway" override.
- Schema changes bump `schemaVersion` and add a step to `onUpgrade`; the
  generated `app_database.g.dart` is committed and regenerated via
  `dart run build_runner build --delete-conflicting-outputs`.
- The current `schemaVersion` is **10**. Versions 5..8 only ever existed on dev
  builds (never released) and their upgrade steps were deleted, so `from` can
  jump straight from 4 to 9. Each of them added one column that v9 removes
  again (`contacts.key_updated_at`, `conversations.secure_broken_at`,
  `.broken_with_key`, `.peer_scanned_at`) — no step re-adds them, but any code
  reading such a column must guard on `from`, since a v4 database does not have
  it and referencing it fails the whole upgrade.
- v9 collapses those ad-hoc flags into the two facts above by **rebuilding**
  `conversations` and `contacts` with drift's `TableMigration` (the only way to
  drop a column); `messages` is untouched. v10 only adds
  `conversations.write_anyway` (a plain `addColumn`, applied when the database
  is already at v9 — the v9 rebuild creates the column itself).
  `app_database_migration_test.dart` covers every path v1..v8 → v9 as well as
  v9 → v10.

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

- **DM/channel content is encrypted, metadata is not.** Both DMs and channel
  messages are encrypted by Meshly's own AEAD layer (see *Meshly encryption*
  above and `SECURITY.md`) and never travel in the clear over the air. What
  is *not* protected is metadata: source/destination node IDs, timing, packet
  size, and which slot a channel packet rides on are all visible to anyone
  listening on the mesh.
- **No forward secrecy.** Both DMs (static X25519 ECDH) and channels
  (HKDF-of-PSK) use static long-term keys, not a ratchet — a compromised key
  can retroactively decrypt past captured ciphertexts.
- **In-channel forgery.** A channel key is a single group secret, so any
  member can decrypt every message and forge a message that appears to come
  from any other member — there is no per-sender authentication within a
  channel.
- **Plaintext local storage.** Decrypted message history and channel PSKs are
  stored unencrypted in the local SQLite database, so device compromise still
  exposes past conversations and channel keys.
- **Channel ACKs**: a delivery ack in a group channel is only ever observed
  from the local radio's own transmission — there is no second "read by
  peer" checkmark for channels the way there is for DMs.
- Push notifications work in the foreground reliably; background BLE
  wake-up on iOS needs additional native work.
