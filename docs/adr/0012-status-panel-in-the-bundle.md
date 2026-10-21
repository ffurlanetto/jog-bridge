# 0012. Status panel as a second executable in the app bundle

- Status: Accepted
- Date: 2026-10-21

## Context

With the daemon installed as `/Applications/Jog Bridge.app` ([ADR 0011](0011-app-bundle-for-the-launch-agent.md)),
clicking the app showed nothing: its only executable was the background daemon. A user who
installs Jog Bridge has no way to tell whether it is working, and when it is not (agent not
allowed in Login Items, service stopped, console unplugged, console held by another app) the
only help is a log file and a terminal.

## Decision

- Add a **SwiftUI status panel**, `jog-bridge-panel`, as a second executable target. It is the
  bundle's **main executable** (`CFBundleExecutable`), so clicking the app opens it. The daemon
  stays at `Contents/MacOS/jog-bridge` and is still started by launchd; the plist is unchanged.
  `LSBackgroundOnly` is gone.
- The panel is a single `Window` scene: closing the window quits the panel (a documented
  behaviour of a single-window app) and never touches the daemon.
- It shows one overall level — green OK, orange attention, red problem — with a message, four
  checks, and the actions that may fix it:
  - **service**: `launchctl print gui/<uid>/local.jog-bridge` (loaded, running, pid, last exit);
  - **background permission**: `SMAppService.statusForLegacyPlist(at:)`;
  - **MIDI ports**: the virtual source "Hercules MP3 e2" in CoreMIDI;
  - **console**: present on USB through IOKit (VID `06F8`, PID `B105`), and what the end of
    `/tmp/jog-bridge.log` says about the connection.
- Actions need no administrator rights: **Start** (`launchctl bootstrap` + `kickstart`),
  **Restart** (`kickstart -k`), **Open Login Items Settings**, plus **Show Log** and **Copy
  Diagnostics** under *Details*. Nothing starts by itself when the panel opens.
- The panel does **not** change the daemon. It learns *why* the console is not connected by
  reading the daemon's log lines; a contract test checks that each line it relies on still exists
  in the daemon's sources, so rewording a message breaks CI rather than blinding the panel.
- The minimum macOS becomes **13** (the package platform moves from `.v12` to `.v13`): Login
  Items & Extensions, `SMAppService` and the `Window` scene all start there.
- State is a `@State` snapshot refreshed by a `.task` loop every two seconds (async/await): no
  Combine, no `ObservableObject`. The status is conveyed by colour **and** symbol **and** text.
- The logic (parsing `launchctl`, reading the log, evaluating the level, building the
  diagnostics) is pure and separated from system access, so it is unit-tested; the view itself is
  checked by hand.

## Consequences

- A user can see at a glance that the bridge works, and gets a concrete next step when it does not.
- The panel is not sandboxed (it runs `launchctl`, reads `/tmp`, uses IOKit): fine for a
  Developer ID or direct distribution, one more reason the App Store is out of reach
  ([ADR 0002](0002-userspace-usb-access-with-libusb.md)).
- Coupling to the daemon's log text is a maintenance cost, covered by the contract test. A status
  file written by the daemon would be sturdier but touches the hardware-validated USB code;
  revisit if the coupling hurts.
- macOS 12 is no longer supported.
- `launchctl print` is not a documented interface: the parser degrades to "loaded, not running"
  on anything unexpected instead of failing.
- For an unsigned bundle `statusForLegacyPlist` may report `notFound`; the panel then shows the
  permission as "Unknown" and relies on launchd's state.
- Double-clicking the app used to be a no-op; it now opens the panel, which also settles the earlier
  worry about launching a second daemon.

## Alternatives considered

- **A menu-bar item**: always visible, but the request was a panel that opens when the app is
  clicked, and a menu-bar app adds a permanent presence for little gain.
- **The daemon reports its own status** (status file or XPC): sturdier than reading the log, but
  it changes the USB code for a first version.
- **One executable that is both panel and daemon**: smaller bundle, but the daemon would need an
  `NSApplication`/SwiftUI runtime, and the daemon's launch path is hardware-validated as is.
- **`SMAppService` to register the agent from the app**: the modern API, left for when the
  package is signed ([ADR 0011](0011-app-bundle-for-the-launch-agent.md)).
