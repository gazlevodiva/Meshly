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

## Setting the LoRa region from the app

A factory-fresh Meshtastic board ships with `LoRaConfig.region = UNSET` and
transmits nothing until a region is chosen — previously that meant reaching
for the official Meshtastic app just to get a new board on the air. Meshly
now does this itself, entirely through the same `AdminMessage` channel used
for other device configuration:

- On connect, the device sends its current `Config` (including `LoRaConfig`)
  unprompted as part of the `want_config` dump; `MeshService` decodes it
  (`MeshtasticProto.decodeLoraConfig`) and exposes both the raw config bytes
  and the parsed region as `loraRegion`/`hwModel` (`ValueNotifier`s).
- Changing the region (`MeshService.setRegion`) sends three self-addressed
  `AdminMessage` frames in sequence — `begin_edit_settings` (64) →
  `set_config` (34, carrying the whole `LoRaConfig` with only the region
  field patched) → `commit_edit_settings` (65) — built by
  `MeshtasticProto.encodeSetRegion`. `set_config` replaces the *entire*
  config, so it must start from the raw bytes the device actually sent, not
  a value reconstructed field-by-field; that's why `setRegion` refuses to run
  before a config has been received (`canSetRegion`).
- `lib/services/lora_region.dart` (`LoraRegion`) is a static reference table
  of Meshtastic's `RegionCode` enum plus two pieces of app-specific
  reasoning: `suggestedFor(countryCode)` maps the phone's own country (via
  its locale) to a sensible default so the picker can pre-select something
  without ever choosing automatically, and `compatibleWith(currentRegion)`
  narrows the list to regions sharing the same frequency band as whatever the
  board is already set to — a European 868 MHz board's antenna cannot
  usefully run at 433 MHz, so cross-band choices are filtered out rather than
  offered and silently failing.
- The region is deliberately never set without an explicit user choice: no
  auto-detection writes to the device on its own.

## Onboarding and the display name

A device's own node id — and therefore whether a self-contact already
exists — is only known once a radio has actually connected and sent
`MyNodeInfo`, so asking for a display name can't happen during the intro
slides. `OnboardingScreen` only shows three static pages and a "skip"
button, then hands off to `ScanScreen`; once a connection succeeds,
`postConnectDestination` (in `lib/screens/scan_screen.dart`) decides where
to land: straight to `MainScreen` if `ContactStore.contactByNodeId(myNodeId)`
already exists (a returning user or a reconnect), otherwise to
`NameStepScreen` (defined in `lib/screens/onboarding_screen.dart`) to ask
for a name once, right after the first successful connect.

- **One limit everywhere.** `kDisplayNameMaxLength` (32 Unicode code points,
  `lib/models/contact.dart`) is the single cap on a display name, enforced
  three times so it can never drift: live, as a `TextInputFormatter` on the
  name field (`_DisplayNameInputFormatter` in `my_card_screen.dart`) that
  refuses further input rather than silently truncating later;
  `sanitizeDisplayName`, which trims, flattens control characters/newlines
  to spaces, and caps by *code points* (not UTF-16 units, so an emoji's
  surrogate pair is never split) before a name is persisted; and again
  inside `encodeSystemEvent` (see *Join/leave announcements* below), so a
  name that already fits the field is guaranteed to reach an announcement
  unchanged. The cap is also applied on every path a name arrives from
  *another* device — `decodeSystemEvent`, `QrService.decodeContact` and
  `QrService.decodeChannel` — because those senders' encoders bind only
  honest clients, and a name that skipped the cap would reach the store,
  the chat header and a push-notification title as encoded.
- **No QR until a name exists.** `MyCardScreen._hasName` is true only once
  `ContactStore.contactByNodeId` returns a row for this device, which only
  happens after the first successful `_saveName` — there is no placeholder
  name. The QR/share section stays hidden until then, so a card never
  encodes an invented stand-in name that a scanning contact would save as
  this device's real name.

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
  channel 0 — see *Conversations are not hardware channel slots* below for
  why there is no per-conversation slot). This is intentional — the stock
  Meshtastic app and other firmware clients don't recognize `PRIVATE_APP` and
  will ignore these packets, so Meshly traffic no longer interoperates with
  non-Meshly clients. `MeshService.sendText` returns `SendResult.needsKey`
  instead of sending in the clear when a DM peer's public key isn't known
  yet. On receive (`_onBytesReceived`): an incoming broadcast is only
  accepted if it is `PRIVATE_APP` and decrypts under *some* known
  conversation's key (see below) — anything else (plaintext broadcast,
  unknown key, auth failure) is silently dropped without notifying. Unicast
  packets go through the DM path described below.
- **Service packets**: version bytes `0x02..0x04` on `PRIVATE_APP` are
  reserved for the secure-chat state machine and never carry user text —
  `[0x02]` is the bare "I cannot decrypt you" notice, `[0x03]`/`[0x04]` are
  the encrypted verify ping/ack. They are recognised by their version byte
  *before* any decryption attempt, so they never reach the message path. See
  `SECURITY.md` → *Secure-chat service packets* for the threat model.

### Conversations are not hardware channel slots

Meshtastic radios expose eight hardware channel slots (0 is the fixed
primary/public channel; 1–7 are configurable). An earlier version of Meshly
mapped each group conversation onto one of the free slots 1–7, which capped
the app at seven conversations and meant `MeshtasticProto.encodeSetChannel`
had to program the radio's channel table over `AdminMessage.set_channel`.
That encoder had the wrong field number and port and never actually worked —
the slot was never configured on the device in practice, group messages
always rode the radio's default primary channel regardless of what the UI
showed. `encodeSetChannel`, `ContactStore.conversationForSlot`, and
`ChannelManager.nextFreeSlot` have all been removed, and `MeshChannel` no
longer has a `slotIndex` field.

Every conversation now sends broadcast on channel 0 and is identified purely
by which Meshly-AEAD key decrypts it, not by which slot it arrived on:

- **Send**: `MeshService.sendText` always broadcasts channel-conversation
  packets on hardware channel 0, encrypted with the conversation's derived
  channel key (`CryptoService.encryptForChannel`). There is no slot to pick
  and thus no seven-conversation ceiling — `ChannelManager.create` never has
  to fail with "all slots taken."
- **Receive**: `_onBytesReceived` first does a cheap structural check on the
  raw envelope — correct version byte and at least
  `version(1) + nonce(24) + mac(16)` bytes — before touching any key, so a
  garbage broadcast from any node in range costs one comparison instead of N
  decrypt attempts. A payload that passes is then tried against every known
  conversation's derived channel key in turn
  (`CryptoService.deriveChannelKey`, cached by PSK) until one succeeds;
  Poly1305 rejects the wrong key outright, so a "successful" decryption under
  the wrong key cannot happen — the first one that authenticates is
  unambiguously the right conversation. There is no cap on how many
  conversations can be tried, so the number of group conversations is no
  longer limited by hardware slots.
- **Column left in place**: `Channels.slotIndex` still exists in the drift
  schema (`NOT NULL`) because dropping a column means a `TableMigration`, and
  this sprint deliberately kept the schema untouched; it is always written
  as `0` and never read back. The QR channel-invite payload still emits
  `slot=1` for compatibility with old app versions that require the field on
  decode, but current versions ignore it entirely on both encode and decode.

A side effect worth calling out for privacy: the slot number used to be
visible in the air on every channel packet, and since the app assigned slots
per conversation, an eavesdropper who saw two nodes both transmitting on slot
3 learned that they were in the same group — without decrypting anything.
Fixing every conversation to channel 0 removes that signal: the slot field no
longer distinguishes one Meshly group from another.

## Join/leave announcements

Scanning a conversation's QR (joining) and leaving it (the action is
labelled *Выйти из беседы* / *Leave conversation*, and removes the
conversation and its messages from this device only) each broadcast a
one-shot announcement so other members' devices can show
something happened, without the app ever maintaining an authoritative
member list (see *Conversations are not hardware channel slots* above for
why there is no roster to maintain in the first place).

- **Wire format** (`lib/models/message.dart`): `encodeSystemEvent`/
  `decodeSystemEvent` prefix the plaintext with `\u0000meshly:v1:<kind>:`
  before it goes through the normal channel AEAD envelope
  (`CryptoService.encryptForChannel`) and `PRIVATE_APP` framing — same
  portnum, same channel 0, same envelope version as an ordinary message.
  From outside the encryption, an announcement is byte-for-byte
  indistinguishable from a regular broadcast; a distinct outer packet type
  would have let an eavesdropper count joins/leaves without decrypting
  anything, exactly the metadata leak the hardware-slot removal just closed.
  The leading `\u0000` (NUL) is what keeps an ordinary typed message from
  ever being misread as an event — no on-screen keyboard can produce
  U+0000 — see *Security* below for what that does and does not protect
  against.
- **Payload is name-only.** `encodeSystemEvent` carries the sender's
  `sanitizeDisplayName`-capped display name (falling back to the raw node id
  if no self-contact name is set yet — see *Onboarding* above) and nothing
  else. No key material is ever in an announcement.
- **Send**: `MeshService.announceChannelEvent` (called from
  `ChannelManager.addFromQr` on join, and from
  `MeshService.leaveChannelConversation` on leave) is fire-and-forget, like
  the secure-chat service packets — one broadcast, no retry, no delivery
  tracking. Leaving announces best-effort *before* the local conversation
  row is deleted, so a radio failure never blocks the delete.
- **Receive** (`_onBytesReceived` → `_storeSystemEvent`): a decrypted
  broadcast is checked with `decodeSystemEvent` before being treated as an
  ordinary message; the name it carries is re-sanitized there (an
  announcement whose name sanitizes to nothing is rejected outright), and
  `_SystemEventLine` in `chat_screen.dart` renders at most two lines; a recognised announcement is stored as a
  `Message.systemEvent` row (`Messages.eventKind`, schema v11 — see
  *Storage* below) instead. It does not call `NotificationService` and does
  not bump the unread counter — `ContactStore.addMessage` skips both for any
  `Message.isSystemEvent` row, since this isn't a message from a person.
  It is still pushed onto the same incoming-message stream so an already
  open chat updates live.
- **The "Входы и выходы" log** (`_ChannelEventsCard`,
  `lib/screens/channel_info_screen.dart`) renders these rows inline in the
  conversation's info screen. It is deliberately not framed as a member
  list in the UI copy (`channelEventsTitle`/`channelEventsNote` in the ARB
  files) — it is one device's own sighting log of a lossy broadcast, not a
  roster: some announcements never arrive, duplicates are possible, and
  entries are unverified self-reports. See `SECURITY.md` for why an
  announcement can also be *forged*, not just lost.

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

## The user is not their own contact

`ContactStore` tracks which node id is "us" (`_myNodeId`, set via
`setMyNodeId`) — `MeshService` calls it every time `MyNodeInfo` arrives on
connect or reconnect, not just once. Everything that must keep the user out
of their own contact/chat list reads this one field rather than each call
site re-deriving it, on purpose: a filter applied in one list but forgotten
in another is exactly what caused an earlier "chat with yourself" bug.

- `ContactStore.contacts` excludes any contact whose `nodeId == _myNodeId`,
  and `ContactStore.conversations` excludes any DM whose peer is
  `_myNodeId` — both filters live in the getter, not in the database, so a
  stray self-DM row from before this existed still never surfaces.
- `saveContact` refuses to create a DM conversation for the self-contact
  (the only place a self-contact is ever saved from is the name step and
  "Мой контакт"). `setMyNodeId` also deletes, once and for all, any
  self-DM conversation and its messages that a pre-fix install already has
  on disk, the moment the node id becomes known again.
- The self-contact row itself is **not** deleted from the `Contacts` table —
  `MyCardScreen`/`ContactStore.contactByNodeId` reads it legitimately to
  back the "Мой контакт" screen and the QR code. Only the two list getters
  and DM creation treat it specially.

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
- There is no FK cascade on `Messages` (see the schema), so `ContactStore`
  deletes a conversation's messages explicitly wherever it deletes the
  conversation itself: `deleteContact` and `deleteChannel` both remove the
  contact/channel row, the associated `Conversations` row, and every
  `Messages` row for that conversation id in one call — otherwise the
  messages would stay behind as permanent orphans. `blockNode` only drops the
  conversation (not the contact or its message history); `unblockNode`
  recreates an empty conversation so the contact remains reachable.
- Schema changes bump `schemaVersion` and add a step to `onUpgrade`; the
  generated `app_database.g.dart` is committed and regenerated via
  `dart run build_runner build --delete-conflicting-outputs`.
- The current `schemaVersion` is **11**. Versions 5..8 only ever existed on dev
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
  is already at v9 — the v9 rebuild creates the column itself). v11 adds
  `messages.eventKind` (nullable text, plain `addColumn`) to hold the
  join/leave kind for a system-event row (see *Join/leave announcements*
  above) — the announced name itself is stored in the existing `text` column,
  not a new one.
  `app_database_migration_test.dart` covers every path v1..v8 → v9 as well as
  v9 → v10 → v11.

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

## Delivery status: what the second checkmark means

`MessageStatus.acked` (`_onBytesReceived` in `mesh_service.dart`, via
`MeshtasticProto.decodeRoutingAck` on `ROUTING_APP`) is a *transport* fact:
for a unicast DM packet, the destination node's own radio has confirmed it
received the packet at the Meshtastic routing layer — LoRa's mesh ACK, not
an application-level read receipt. It says nothing about whether that device
could decrypt the payload. For a channel broadcast there is no destination
radio to ack in that sense; only our own node acknowledges, so a channel ack
never reflects the peer at all.

`Conversation.ackMeansDelivered` (`lib/models/conversation.dart`) is
`isDm && !writeAnyway` — true only for a DM not currently forced through
"send anyway". `_StatusIcon` (`lib/screens/chat_screen.dart`) reads that
flag to choose between a single check (transmitted) and a double check
(routing-confirmed by the peer's radio); it never claims proof that the
message was decrypted or read. That proof-of-decryption signal is a separate
mechanism — the verify ping/ack described in *Secure chat state* above — and
does not feed into the checkmarks at all.

## Known limitations

`SECURITY.md` is the single owner of the full limitations list and threat
model — see its *Security posture* section. The points above that follow
directly from how the wire protocol and storage are built (hardware-slot
metadata, static keys, plaintext storage) are covered there in full; this
document only explains the mechanisms that produce them.
