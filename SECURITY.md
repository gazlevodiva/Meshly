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
messenger. Please read this section honestly before trusting it with
sensitive communication — it mirrors the *Security & Privacy* section in
`README.md`.

- **Channels** are AES-256 encrypted by the Meshtastic firmware, with the
  pre-shared key (PSK) exchanged out-of-band via QR code.
- **Direct messages between Meshly users are end-to-end encrypted.** Each
  device generates an X25519 identity keypair on first run; the private key
  is stored only in the OS keychain/keystore (never in the app database).
  Public keys are exchanged out-of-band via QR code when you add a contact.
  Messages are encrypted with static ECDH (X25519) + XChaCha20-Poly1305 AEAD
  and sent as a `PRIVATE_APP`-portnum packet, so they're opaque to anyone
  without the recipient's private key — including other Meshtastic nodes on
  the mesh. Be honest with yourself about the limits, though:
  - **Metadata is not protected.** Who is talking to whom, when, and how
    often is visible to anyone listening on the mesh (packet source/dest
    node IDs, timing, size). Only the message content is encrypted.
  - **No forward secrecy.** The scheme uses a static long-term key, not a
    ratchet — if a private key is ever compromised, past captured
    ciphertexts for that identity could be decrypted retroactively.
  - **Decrypted text is stored locally.** The local SQLite database holds
    plaintext message history on the phone, same as before — device
    compromise still exposes past conversations.
  - **No interop with the stock Meshtastic app for DMs.** Encrypted DMs use
    a non-standard portnum (`PRIVATE_APP`) that other Meshtastic clients
    ignore; DMs only work between two Meshly installs that have exchanged
    keys via QR. If a contact's public key isn't known yet, Meshly will not
    silently fall back to sending the message in the clear.
- **Channels still use the shared channel PSK** — direct messages are the
  part that changed. Channel messages remain readable by anyone with that
  channel's PSK, same as stock Meshtastic.
- **PSKs are stored unencrypted** in the local SQLite database on the
  phone. Anyone with access to the device's app storage (e.g. a rooted
  device, a backup, or physical access with debugging enabled) can read
  channel keys (and the decrypted DM history, per above).
- **Notifications leak content.** Incoming message text appears in local
  push notifications, including on the lock screen, unless the OS/user
  notification settings hide it.
- The app has not had an independent security audit. Treat it as
  "reasonably careful hobby project," not "vetted for high-risk use."

If you're evaluating Meshly for a situation where confidentiality actually
matters (activism, abusive-relationship safety planning, etc.), please read
the above carefully — DM content confidentiality is meaningfully better
than before, but metadata exposure, lack of forward secrecy, and plaintext
local storage are still real risks.
