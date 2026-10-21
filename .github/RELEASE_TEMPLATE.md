# jog-bridge vX.Y.Z

<!-- One sentence: what this version brings. -->

## What's new

- 

## Fixes

- 

## Installation

1. Download `jog-bridge-X.Y.Z.pkg` below.
2. **This package is neither signed nor notarised.** macOS blocks it on first double-click with
   the message *"Apple could not verify that jog-bridge-X.Y.Z.pkg is free of malware…"*. Do
   **not** click *Move to Bin*; click *Done*, then either:
   - open *System Settings → Privacy & Security*, scroll down to the message about
     `jog-bridge-X.Y.Z.pkg` and click **Open Anyway** (your password is asked). The button only
     appears for a short while after the blocked attempt, so try the install again if it is gone;
   - or remove the download's quarantine attribute and open it from the Terminal:
     ```sh
     xattr -d com.apple.quarantine ~/Downloads/jog-bridge-X.Y.Z.pkg
     open ~/Downloads/jog-bridge-X.Y.Z.pkg
     ```

   On recent macOS versions, right-click → *Open* is not enough for an installer package.
3. After installing, check that the **Jog Bridge** item is enabled in *System Settings → General →
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
sudo rm -rf "/Applications/Jog Bridge.app"
sudo pkgutil --forget local.jog-bridge
```

## Hardware tested

- Hercules DJ Control MP3 e2 (`06F8:B105`)

---

*jog-bridge is an independent project, not affiliated with Guillemot Corporation or Hercules,
and neither approved nor sponsored by them. Hercules is a trademark of Guillemot Corporation.*

Full changelog: [CHANGELOG.md](../CHANGELOG.md)
