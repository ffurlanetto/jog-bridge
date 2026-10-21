# 0011. App bundle for the LaunchAgent: name, icon, no loose binary

- Status: Accepted
- Date: 2026-10-21

## Context

In *System Settings → Login Items & Extensions → Allow in the Background*, the `jog-bridge` item
showed the bare executable name and the generic "exec" icon. Apple's documentation says why:
for a legacy LaunchAgent (a plist in `~/Library/LaunchAgents`), macOS shows the name of the
`ProgramArguments` executable when it is unsigned and not tied to an app; the organisation name
of the signing certificate when it is signed; and the **app's name and icon** when the plist
carries `AssociatedBundleIdentifiers` naming an app bundle.

The binary also sat loose in `/usr/local/bin`, which is not where macOS expects the helper of a
background service to live. Apple's own installer sample puts its app bundle under
`/Library/Application Support/<vendor>/`, but there the bundle is a helper of a main app; for
software the user installs and sees named in System Settings, `/Applications` is the expected
place.

## Decision

- The executable is installed **inside an app bundle**,
  `/Applications/Jog Bridge.app`, built by `scripts/build-pkg.sh`:
  `Contents/MacOS/jog-bridge`, an `Info.plist` (identifier `io.github.ffurlanetto.jog-bridge`,
  display name "Jog Bridge"), and `Contents/Resources/AppIcon.icns`
  generated from the logo (`make icon`, the `.icns` is committed). The bundle is ad-hoc signed.
- The LaunchAgent plist runs the bundle's executable and lists the bundle identifier in
  `AssociatedBundleIdentifiers`.
- `postinstall` removes the loose `/usr/local/bin/jog-bridge` left by early builds, and registers
  the app with Launch Services (`lsregister`, best effort) so the association works immediately
  rather than after the next scan of `/Applications`.
- **No link in `/usr/local/bin`.** The installed binary is called by its full path (documented in
  the README); an alias is suggested for those who want a short command.
- The app component is **not relocatable** and not version-checked (`pkgbuild` component plist),
  so the installer always installs it in `/Applications`, never over another copy of the bundle
  found elsewhere on the disk (a build folder, for instance).
- Clicking the app opens a status panel, a separate executable in the same bundle
  ([ADR 0012](0012-status-panel-in-the-bundle.md)); the daemon is only started by launchd.

## Consequences

- System Settings should show "Jog Bridge" with the project icon instead of the bare executable.
  **This depends on macOS accepting the association for an unsigned bundle**: Apple states that
  the executable's and the app's Team ID must match, and neither has one here. The display must be
  checked on a real machine; if it stays generic, signing with a Developer ID is the fix
  ([ADR 0006](0006-launchagent-and-unsigned-pkg.md)).
- The uninstall is the usual one: drag `Jog Bridge.app` to the Bin (plus the agent plist, see the
  README), instead of hunting for a loose binary.
- `--list` and `--dump` are no longer on the `PATH` after installation; every doc, issue template
  and troubleshooting step says how to call them.
- Several paths and identifiers now have to stay consistent: the bundle identifier in
  `build-pkg.sh` and in `local.jog-bridge.plist`, and the program path in the plist. CI checks it.
- The launchd label (`local.jog-bridge`) is unchanged: this is not a rename.

## Alternatives considered

- **Keep the loose binary, change nothing**: simplest, but the generic icon and bare name stay.
- **Keep a `/usr/local/bin/jog-bridge` symlink to the bundle**: handy for the CLI, but it brings
  back a loose entry the Apple layout avoids, and a second path to keep consistent.
- **`/Library/Application Support/jog-bridge/jog-bridge.app`** (the layout of Apple's installer
  sample): hides the bundle from the Finder, but it is not where users look for or remove an app,
  and Launch Services does not index that folder by itself. This was the first version of this
  decision and was changed for those two reasons.
- **`SMAppService` with the agent plist inside the bundle** (`BundleProgram`): the modern API, and
  the cleanest, but it needs an app that registers the service itself, and ideally a Developer ID
  signature. Worth revisiting together with signing.
