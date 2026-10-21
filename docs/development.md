# Development

## Prerequisites

```sh
xcode-select --install
brew install libusb pkg-config
```

`Package.swift` queries `pkg-config` when the manifest is evaluated to find the static library
`libusb-1.0.a` and the headers. It adds the Homebrew paths (`/opt/homebrew`, `/usr/local`) to
the `PATH` itself, because Xcode evaluates the manifest without that `PATH`.

## Command contract

The same `make` targets serve humans, agents and CI:

```sh
make help         # list the targets
make install      # Homebrew prerequisites (libusb, pkg-config)
make check        # lint + typecheck + test + build + audit — the quality gate
make test         # swift test
make pkg VERSION=1.0.0
```

`make lint` validates the scripts (`bash -n`, shellcheck if installed), the plist, the JSON and
the SVG files; `make audit` checks that libusb is statically linked.

## Build and run

```sh
make build                           # or: swift build -c release
.build/release/jog-bridge --list     # console plugged in
.build/release/jog-bridge --dump     # USB and MIDI traffic
```

`make panel` runs the status panel from the build folder (it inspects the *installed* agent, so
it shows the real state of this Mac).

The project also opens in Xcode (*File → Open…* on the folder or on `Package.swift`).

If the installed agent is running, it already holds the console: stop it before running a
development build.

```sh
launchctl bootout gui/$(id -u)/local.jog-bridge
# … experiments …
launchctl bootstrap gui/$(id -u) ~/Library/LaunchAgents/local.jog-bridge.plist
```

## Debugging

- `--dump` logs every frame byte that changes (`USB Δ: [03] 00→04`), the MIDI message produced
  (`→ MIDI: 90 0A 7F`) and the messages received from the application (`MIDI → LEDs: …`).
- Logs go to stderr; under the LaunchAgent: `/tmp/jog-bridge.log`.
- *Audio MIDI Setup → Window → Show MIDI Studio* shows the virtual ports; *MIDI Monitor* (or any
  monitoring application) lets you check the flow.

## Tests

```sh
swift test
```

109 tests (Swift Testing), no hardware needed: unit, integration (real CoreMIDI and libusb) and
non-regression (reference sessions, MIDI contract, djay mapping) for the daemon, plus the status
panel's logic, probes and its contract with the daemon. Strategy, organisation and
rules for the reference files: [testing.md](testing.md).

## Building the .pkg

```sh
./scripts/build-pkg.sh 1.0.0
```

The script builds, assembles `.build/pkg/root` and `.build/pkg/scripts`, then writes
`dist/jog-bridge-<version>.pkg`. Both folders are ignored by git.

The package installs `/Applications/Jog Bridge.app` (binary in
`Contents/MacOS`, `Info.plist`, `AppIcon.icns`, ad-hoc signature). The icon is generated from
`assets/branding/logo.svg` by `make icon` and the `.icns` is committed.

Check a package's contents without installing it:

```sh
pkgutil --payload-files dist/jog-bridge-1.0.0.pkg
pkgutil --expand dist/jog-bridge-1.0.0.pkg "$(mktemp -d)/pkg-check"   # then read Scripts/postinstall
```

Check that the binary has no dynamic dependency on libusb:

```sh
otool -L .build/release/jog-bridge     # must not list libusb
```

Installer log when an installation fails:
`grep -i jog-bridge /var/log/install.log | tail -30`.

## Continuous integration

- `.github/workflows/ci.yml` (push to `main`, pull requests, manual run):
  - `build` job: `make check` (lint, tests, build, static linking of libusb);
  - `package` job (if `build` succeeds): builds the `.pkg`, checks its contents and its binary
    (self-contained, `--help` works), computes the SHA-256 and uploads both files as an
    artifact (14 days). Run by hand (*Actions → CI → Run workflow*), it accepts a version;
    otherwise the package is named `jog-bridge-0.0.0-ci.pkg`;
  - `guardrails` job (Ubuntu): `make test-hooks` and a gitleaks secret scan over the whole
    history.
- `.github/workflows/publish.yml` (tag `vX.Y.Z`): builds the `.pkg`, computes its SHA-256 and
  creates a **draft** release from
  [`.github/RELEASE_TEMPLATE.md`](../.github/RELEASE_TEMPLATE.md). You still have to review it
  and publish it on GitHub.

CI does not test the hardware: no console is plugged into the runners.

## Developing with coding agents

The repository is configured for Claude Code: [`AGENTS.md`](../AGENTS.md) (shared
instructions) and `.claude/` (skills, subagents, hooks, permissions). The guardrails refuse an
agent's commit that contains a secret or changes code without a test
([ADR 0009](adr/0009-guardrails-enforced-outside-the-model.md)); `make test-hooks` proves they
work. The delivery flow (branch, draft PR, wait for CI) is described in
[ADR 0010](adr/0010-delivery-flow.md).

## Publishing a release

Manually, or automated by pushing the tag (see above):

1. Update `CHANGELOG.md`.
2. `./scripts/build-pkg.sh X.Y.Z`, then `shasum -a 256 dist/jog-bridge-X.Y.Z.pkg`.
3. Create the `vX.Y.Z` tag and attach the `.pkg` to the GitHub release, starting from
   [`.github/RELEASE_TEMPLATE.md`](../.github/RELEASE_TEMPLATE.md) (SHA-256 checksum, a note that
   the package is unsigned: [ADR 0006](adr/0006-launchagent-and-unsigned-pkg.md)).
