# jog-bridge vX.Y.Z

<!-- One sentence: what this version brings. -->

## What's new

- 

## Fixes

- 

## Installation

1. Download `jog-bridge-X.Y.Z.pkg` below.
2. **This package is neither signed nor notarised.** macOS will block it on first double-click:
   right-click → *Open*, or *System Settings → Privacy & Security → Open Anyway*.
3. After installing, check that the `jog-bridge` item is enabled in *System Settings → General →
   Login Items & Extensions → Allow in the Background*. Without it, the agent does not start.
4. Plug in the console: the "Hercules MP3 e2" MIDI port appears in your DJ software.

Verify the download's integrity:

```sh
shasum -a 256 jog-bridge-X.Y.Z.pkg
# expected: <SHA-256>
```

Prefer to build it yourself? See the [README](../README.md#2-build).

## Updating and uninstalling

Reinstalling the `.pkg` replaces the binary and reloads the agent. To uninstall:

```sh
launchctl bootout gui/$(id -u)/local.jog-bridge
rm ~/Library/LaunchAgents/local.jog-bridge.plist
sudo rm /usr/local/bin/jog-bridge
```

## Hardware tested

- Hercules DJ Control MP3 e2 (`06F8:B105`)

---

*jog-bridge is an independent project, not affiliated with Guillemot Corporation or Hercules,
and neither approved nor sponsored by them. Hercules is a trademark of Guillemot Corporation.*

Full changelog: [CHANGELOG.md](../CHANGELOG.md)
