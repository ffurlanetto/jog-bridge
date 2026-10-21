# Contributing

Thank you for your interest! Contributions are welcome: fixes, support for other Hercules
models, protocol documentation, tests.

## Getting started

```sh
xcode-select --install
make install      # brew install libusb pkg-config
make check        # lint, tests, build, audit: must be green
```

See [docs/development.md](docs/development.md) for the details (running, `--dump`, packaging).

## Before opening a pull request

- `make check` passes, with no new warning.
- A behaviour change comes with tests; a change to the MIDI contract (notes, CCs, LEDs) updates
  the reference files and the CHANGELOG ([docs/testing.md](docs/testing.md)).
- If USB or MIDI behaviour changes, you tested it with a real console and give the model
  (`--list`) in the description.
- The documentation is up to date: `docs/usb-protocol.md`, `docs/midi-mapping.md`, `README.md`.
- A structural decision (linking, protocol, distribution…) comes with an ADR in
  [`docs/adr/`](docs/adr/README.md).
- User-visible changes are noted in [`CHANGELOG.md`](CHANGELOG.md).

## Branches, commits, pull requests

- One branch per change: `<type>/<short-slug>` (`feat/…`, `fix/…`, `docs/…`), never directly on
  `main`.
- [Conventional Commits](https://www.conventionalcommits.org/): `type(scope): imperative
  description`. Types: `feat` `fix` `docs` `test` `refactor` `chore` `security` `perf`; scopes:
  `decoder` `leds` `midi` `usb` `config` `pkg` `launchd` `ci` `tests` `docs` `branding`.
- Open the pull request as a **draft**; mark it "ready" when CI is green, `make check` passes
  and review threads are resolved ([ADR 0010](docs/adr/0010-delivery-flow.md)).
- Merge with *squash*.
- A commit that changes `Sources/` without touching `Tests/` is refused for coding agents; if
  the change truly has no behaviour (pure rename), add a `Test-Exempt: <reason>` trailer
  ([ADR 0009](docs/adr/0009-guardrails-enforced-outside-the-model.md)).

## Style

- Swift 5.9, 4-space indentation, PascalCase for types, camelCase otherwise.
- Comments and log messages in English, oriented towards the *why*.
- No external Swift dependency.
- `.editorconfig` is authoritative for indentation and line endings.

## Compatibility constraints

Do not change without discussing:

- the note and CC numbers (`byte × 8 + bit`, CC = byte index): they define users' mappings;
- the unique identifiers of the virtual MIDI ports;
- the LaunchAgent identifier `local.jog-bridge`.

## Reporting a bug or new hardware

Use the issue templates. Always attach the output of:

```sh
# On an installed copy, `jog-bridge` is
# /Applications/Jog Bridge.app/Contents/MacOS/jog-bridge
jog-bridge --list
jog-bridge --dump     # while reproducing the problem (stop the agent first)
tail -50 /tmp/jog-bridge.log
```

## Licence

By contributing, you agree that your code is published under the [MIT](LICENSE) licence.
