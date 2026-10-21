# Troubleshooting

## Quick diagnosis

```sh
launchctl print gui/$(id -u)/local.jog-bridge | grep -E "state|pid|runs|last exit"
tail -30 /tmp/jog-bridge.log
jog-bridge --list
```

A healthy start ends with:

```
Virtual MIDI ports “Hercules MP3 e2” created.
Console connected — input 0x81 (bulk)
```

## The .pkg installation fails ("an error occurred while running scripts")

The `postinstall` returned a non-zero code. The files had nevertheless already been copied
(binary and plist), which gives the impression of a half-successful installation.

Find the cause: `grep -i jog-bridge /var/log/install.log | tail -30`.

Known cause: `launchctl bootstrap` fails when the agent is not authorised (below) or when an
old service is still unloading. Since the fix, the script retries and then ignores the failure;
if you still see the error, check that you are installing a `.pkg` built after the fix
(`pkgutil --expand`, then look for `kickstart` in `Scripts/postinstall`).

## The agent does not start: `Bootstrap failed: 5: Input/output error`

System Settings → General → **Login Items & Extensions → Allow in the Background**: the
`jog-bridge` item must be enabled. Then:

```sh
launchctl bootstrap gui/$(id -u) ~/Library/LaunchAgents/local.jog-bridge.plist
```

A "Not running in the background" state in that list means the process is not loaded.

## "Cannot claim interface"

Another application (or an old Hercules driver) holds the USB interface. Close it, or uninstall
the driver. Mixxx and other DJ software can also claim the console.

## The console is detected but nothing reaches the DJ application

1. `jog-bridge --dump`: every action must print a `USB Δ` line. If not, check the endpoint with
   `--list` and try `--in 0x81`.
2. Check that the DJ application uses the "Hercules MP3 e2" port as both input **and** output.
3. If a message comes out on the wrong channel or with another note, see
   [midi-mapping.md](midi-mapping.md).

## The LEDs do not light up

- The application must send back the same note as the button, on channel 1 (steady) or 2
  (blinking). See [midi-mapping.md](midi-mapping.md).
- `--dump` prints `MIDI → LEDs: …` for every message received from the application. If nothing
  appears, the application is not sending to the "Hercules MP3 e2" destination.
- A `LED write: …` log signals a USB error.

## Gatekeeper blocks the .pkg

The package is neither signed nor notarised. A downloaded copy (a GitHub release, or the
artifact of a CI run) is blocked with *"Apple could not verify that … is free of malware"*.

1. Click **Done** — not *Move to Bin*.
2. Open *System Settings → Privacy & Security*, scroll to the message about the package and
   click **Open Anyway** (your password is asked). The button only appears for a short while
   after the blocked attempt; if it is gone, try to open the package again.
3. Or, from the Terminal:

   ```sh
   xattr -d com.apple.quarantine ~/Downloads/jog-bridge-X.Y.Z.pkg
   open ~/Downloads/jog-bridge-X.Y.Z.pkg
   ```

On recent macOS versions, right-click → *Open* is not enough for an installer package. A package
built locally (`make pkg`) has no quarantine attribute and opens without a warning. Signing and
notarising the package would remove this step ([ADR 0006](adr/0006-launchagent-and-unsigned-pkg.md)).

## Reporting a problem

Attach `jog-bridge --list`, the output of `--dump` and `/tmp/jog-bridge.log`.
