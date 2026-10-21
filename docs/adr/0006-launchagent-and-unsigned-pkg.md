# 0006. LaunchAgent and unsigned `.pkg` installer

- Status: Accepted
- Date: 2026-10-21

## Context

The daemon must run permanently and reconnect to the console. It must also be installable by
someone who is not a developer, from a GitHub release. The project has no Apple Developer
account and no Developer ID certificate.

## Decision

- The daemon is a user **LaunchAgent** (`local.jog-bridge`, `RunAtLoad`, `KeepAlive`,
  `ProcessType Interactive`), not a system daemon: it runs in the user's session, with their
  rights. The virtual MIDI ports are those of that session.
- Distribution is a `.pkg` built by `scripts/build-pkg.sh`: binary in `/usr/local/bin`, plist
  copied to `~/Library/LaunchAgents` by a `postinstall` script.
- The `.pkg` is **neither signed nor notarised**; the README explains how to get around
  Gatekeeper.
- The `postinstall` script **never fails the installation** because of `launchctl`: `bootstrap`
  is retried, followed by a `kickstart`, and errors are ignored.

## Consequences

- First launch: macOS requires allowing the item in *Login Items & Extensions → Allow in the
  Background*. Until that is done, `launchctl bootstrap` fails with error 5. The script cannot
  grant it on the user's behalf; without the error tolerance, the installer showed "failed"
  although every file was in place.
- The `postinstall` script identifies the user through `/dev/console`: an installation with no
  graphical session (remote, login window) does not target the right account.
- `KeepAlive` only matters after a crash: the console being absent does not stop the process
  ([architecture](../architecture.md)).
- Signing and notarising the `.pkg` would remove the Gatekeeper warning; to consider if the
  project gets a Developer ID.

## Alternatives considered

- **LaunchDaemon (root)**: unneeded privileges and MIDI ports outside the user session.
- **Manual launch only**: available (README), but not suited to everyday use.
