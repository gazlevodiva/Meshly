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
- **Direct messages currently are not private.** They are sent over the
  primary channel (slot 0) using Meshtastic's default, well-known PSK.
  Anyone running standard Meshtastic firmware nearby can decrypt them. Do
  not treat DMs as confidential until this is changed.
- **PSKs are stored unencrypted** in the local SQLite database on the
  phone. Anyone with access to the device's app storage (e.g. a rooted
  device, a backup, or physical access with debugging enabled) can read
  channel keys.
- **Notifications leak content.** Incoming message text appears in local
  push notifications, including on the lock screen, unless the OS/user
  notification settings hide it.
- The app has not had an independent security audit. Treat it as
  "reasonably careful hobby project," not "vetted for high-risk use."

If you're evaluating Meshly for a situation where confidentiality actually
matters (activism, abusive-relationship safety planning, etc.), please
read the above carefully and consider it insufficient on its own until DM
encryption is improved.
