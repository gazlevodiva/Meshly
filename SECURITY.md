# Security Policy

## Reporting a vulnerability

Please **do not** open a public GitHub issue for security vulnerabilities.

Instead, report privately using one of:

- GitHub [private security advisories](https://github.com/gazlevodiva/Meshly/security/advisories/new)
  for this repository (preferred — keeps the report and any discussion
  private until a fix is out).
- Email the maintainer directly (see the GitHub profile linked from the
  repository) if you don't have or don't want to use a GitHub account.

Please include: a description of the issue, steps to reproduce, affected
version/commit, and (if applicable) the Meshtastic firmware/device you
tested against. We'll acknowledge reports as soon as we can and aim to
follow up with a fix or a plan before any public disclosure.

## Security posture

Meshly is a hobby/personal-safety project, not a hardened secure
messenger. This section is the full threat model and limitations list —
`README.md` only summarizes it and links here.

- **Channels are encrypted with Meshly's own AEAD**, not the firmware's
  channel crypto. The symmetric key is derived from the channel PSK
  (`HKDF-SHA256(psk, info="meshly-channel-v1")`) — the same PSK you exchange
  out-of-band via QR, so nothing about channel setup changes. Messages are
  encrypted with XChaCha20-Poly1305 (same envelope as DMs) and sent as a
  `PRIVATE_APP`-portnum broadcast on hardware channel 0, so they are **opaque
  to the stock Meshtastic app** even if it shares the same PSK. Every Meshly
  conversation broadcasts on channel 0 — a receiving device tries the AEAD
  key of each conversation it knows in turn and keeps whichever one
  successfully decrypts — so there is no hardware channel-slot limit on how
  many group conversations you can have, and (see *Metadata is not
  protected* below) the slot no longer reveals which devices share a group.
  Meshly ignores any plaintext
  (`TEXT_MESSAGE_APP`) traffic on channels, so the default public channel and
  other non-Meshly senders never appear. Group limits still apply:
  - **One shared key for the whole group.** Any member can decrypt every
    message and can *forge* a message that appears to come from any other
    member — there is no per-sender authentication within a channel.
  - **No forward secrecy**, and **no way to revoke a member** without
    rotating the PSK (which requires re-sharing the channel QR to everyone).
- **Direct messages between Meshly users are end-to-end encrypted.** Each
  device generates an X25519 identity keypair on first run; the private key
  is stored only in the OS keychain/keystore (never in the app database).
  Public keys are exchanged out-of-band via QR code when you add a contact.
  Messages are encrypted with static ECDH (X25519) + XChaCha20-Poly1305 AEAD
  and sent as a `PRIVATE_APP`-portnum packet, so they're opaque to anyone
  without the recipient's private key — including other Meshtastic nodes on
  the mesh. Be honest with yourself about the limits, though:
  - **Metadata is not protected.** For DMs: who is talking to whom, when, and
    how often is visible to anyone listening on the mesh (packet source/dest
    node IDs, timing, size). Only the message content is encrypted. For
    channels: every packet is a broadcast, so which channel-conversation it
    belongs to is not visible from routing alone — every conversation
    broadcasts on the same hardware channel (0), so the channel slot no
    longer tells an eavesdropper which devices share a group. Packet timing
    and size are still visible for channel traffic too.
  - **No forward secrecy.** The scheme uses a static long-term key, not a
    ratchet — if a private key is ever compromised, past captured
    ciphertexts for that identity could be decrypted retroactively.
  - **Decrypted text is stored locally.** The local SQLite database holds
    plaintext message history on the phone — device compromise exposes past
    conversations.
  - **No interop with the stock Meshtastic app for DMs.** Encrypted DMs use
    a non-standard portnum (`PRIVATE_APP`) that other Meshtastic clients
    ignore; DMs only work between two Meshly installs that have exchanged
    keys via QR. If a contact's public key isn't known yet, Meshly will not
    silently fall back to sending the message in the clear.
- **PSKs are stored unencrypted** in the local SQLite database on the
  phone. Anyone with access to the device's app storage (e.g. a rooted
  device, a backup, or physical access with debugging enabled) can read
  channel keys and the decrypted DM history.
- **Notifications leak content.** Incoming message text appears in local
  push notifications, including on the lock screen, unless the OS/user
  notification settings hide it.
- The app has not had an independent security audit. Treat it as
  "reasonably careful hobby project," not "vetted for high-risk use."

## Secure-chat service packets

Besides encrypted messages (`PRIVATE_APP` payloads starting with version byte
`0x01`), Meshly puts three small service packets on the air. They exist so a
chat that stopped working — usually because one side reinstalled and now has a
new identity key — tells the user to re-scan instead of silently swallowing
messages. They are recognised by their version byte *before* any decryption, so
they never appear as messages:

- **`[0x02]` — "I cannot decrypt you."** The entire payload is that one byte:
  no nonce, no ciphertext, and deliberately **no key material**.
- **`[0x03]` / `[0x04]` — verify ping and ack.** The version byte followed by a
  normal AEAD envelope containing a fixed plaintext (`meshly:verify:ping` /
  `meshly:verify:ack`). A ping goes out whenever our view of a chat's health
  may have drifted from the peer's: after scanning their QR, when opening a
  chat we consider broken, and when our own view has just become healthy again
  (they have no other way of learning that, and a lost ack used to leave their
  recovery card up forever). An ack answers a ping and is never answered in
  turn; announcing happens only on a real broken → healthy transition, so the
  exchange always terminates.

What this does and does not buy you:

- **Key material is never transmitted over the air — by any packet.** The only
  way a contact's public key can appear or change on your device is scanning
  their QR code face to face. Handing keys out over the mesh would let a
  man-in-the-middle substitute its own, so no service packet carries one, and
  no packet can heal a chat by itself.
- **`[0x02]` is unauthenticated.** The Meshtastic `from` field is trivially
  forged and the byte travels in the clear, so anyone within radio range can
  make your app believe a contact cannot read you: the recovery card appears
  and sending into that chat is blocked. There is **no threshold** — the first
  such packet is enough (a threshold buys nothing against someone who can forge
  one packet, and it cost the honest case several messages sent into the void).
  Mitigations, not fixes:
  - **Narrow entry conditions.** A packet is only considered if it is on
    Meshly's own portnum, is addressed to *our* node (overheard or relayed
    unicasts between other nodes are dropped), comes from a contact whose QR we
    have actually scanned, and a DM conversation with them already exists.
    Nothing else moves a flag, and an incoming packet never creates a
    conversation.
  - **One narrow exception, in the outgoing direction.** A packet from a node
    we have *never* scanned is answered with a `[0x02]` if — and only if — it
    passes every other filter and carries the ordinary message version byte
    `[0x01]`. This covers the case where the other side wiped its data: without
    the reply the sender sees two ticks from their own radio and believes the
    message arrived. No state whatsoever is created for such a node (no
    contact, no conversation, no message, no notification, nothing in the UI),
    and service bytes or unknown version bytes are answered with nothing.
    Because `from` is forgeable, an attacker can steer that `[0x02]` at a third
    node — but they can send that exact packet to that node directly, so this
    grants no capability they did not already have, and the airtime is capped
    by the global budget below.
  - **Throttling.** Outgoing notices are rate-limited per peer and reactive
    service packets also share one global budget, so a flood of forged senders
    cannot buy a flood of transmissions on a link that carries a few bytes per
    second.
  - **A sticky "send anyway".** The button that bypasses the block is
    remembered for that conversation (it is stored in the database, not just
    for the current visit), so a chat the user has decided to keep using stays
    usable; it is cleared when the conversation genuinely proves healthy again,
    so a later real breakage still shows the card.

  The worst outcome is a nuisance — it cannot decrypt anything or change any
  key.
- **`[0x03]` / `[0x04]` cannot be forged.** They are encrypted to the peer's
  key and checked *by content*: the decrypted text must equal the constant
  belonging to the version byte on the wire. Without the private key you cannot
  produce a packet that counts as proof, and no unrelated ciphertext from that
  contact (an old message, an old ack) can be relabelled into one.
- **No replay protection.** Nothing on the air carries a counter, timestamp, or
  seen-nonce cache, so any captured packet — a service packet or an ordinary
  message envelope — can be re-emitted later and will be processed again. The
  verify plaintexts in particular are fixed, so a recorded ping/ack still
  authenticates. In practice this lets an attacker push the recovery card's
  state around (mark a chat healthy again, or replay a `[0x02]` to block it)
  and re-deliver an old message; it does not reveal anything new.
- **The flags are UI state, nothing more.** `iCanReadPeer` / `peerCanReadUs`
  (and the derived "secure chat works") affect only what the interface shows
  and whether the app is willing to transmit. They never influence which key is
  used, whether a payload is decrypted, or whether a sender is trusted — a
  forged or replayed service packet cannot widen what anyone can read.

If you're evaluating Meshly for a situation where confidentiality actually
matters (activism, abusive-relationship safety planning, etc.), please read
the above carefully — DM content confidentiality is meaningfully better
than before, but metadata exposure, lack of forward secrecy, and plaintext
local storage are still real risks.
