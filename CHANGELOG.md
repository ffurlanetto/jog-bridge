# Changelog

Format inspired by [Keep a Changelog](https://keepachangelog.com/en/1.1.0/);
[SemVer](https://semver.org/) versioning.

## [Unreleased]

### Changed
- **The project is renamed `jog-bridge`** (formerly `hercules-bridge`) so as not to use the
  Hercules trademark as a name
  ([ADR 0008](docs/adr/0008-project-name-and-third-party-trademarks.md)). Binary, `.pkg`,
  plist, log and launchd label change: `local.jog-bridge`, `/usr/local/bin/jog-bridge`,
  `/tmp/jog-bridge.log`. The MIDI ports ("Hercules MP3 e2") and their identifiers are unchanged,
  so existing mappings remain valid. An old installation must be uninstalled by hand
  (`launchctl bootout gui/$(id -u)/local.hercules-bridge`, then remove the old plist and binary).
- **Everything is now in English**: code comments, log messages, `--help` and `--list` output,
  documentation, ADR file names. The log lines changed accordingly (for example
  "Console connected — input 0x81 (bulk)").

### Fixed
- `postinstall`: a `launchctl bootstrap` failure (for example error 5 when the item is not yet
  allowed in *Login Items & Extensions*) no longer fails the `.pkg` installation. Loading is
  retried, then followed by a `kickstart`.

### Added
- Documentation: `docs/` (architecture, USB protocol, MIDI mapping, development, troubleshooting,
  identity), ADRs, `AGENTS.md`, `CLAUDE.md`, `CONTRIBUTING.md`, `SECURITY.md`, MIT licence.
- Practices from [vibe-template](https://github.com/ffurlanetto/vibe-template): `make` contract
  (`install build test lint audit check test-hooks dev pkg`), agent guardrails (secret scan,
  commit refused with a secret or without a test — ADR 0009), Claude Code permissions, skills
  (`/plan` `/tdd` `/debug` `/review` `/commit` `/pr` `/ship` `/prime` `/adr` `/security-audit`),
  audit subagents, delivery flow (ADR 0010), `.editorconfig`, hardened `.gitignore`
  (certificates, keys), gitleaks scan and `guardrails` job in CI, PR template.
- Tests (`swift test`, Swift Testing): unit, CoreMIDI/libusb integration, non-regression
  (reference sessions, MIDI contract, djay mapping consistency).
- GitHub CI: `build` (compilation, tests) and `package` (checked `.pkg`, SHA-256, artifact,
  triggerable by hand with a version) jobs; publish workflow on tag (draft release); Dependabot
  for the actions.
- Visual identity (`assets/branding/`: logo, banner, social image), non-affiliation notice,
  release notes template and configuration.

## [1.0.0]

- USB bulk → CoreMIDI bridge for the Hercules DJ Control MP3 e2.
- Virtual MIDI ports "Hercules MP3 e2" (source and destination) with fixed identifiers.
- LED control (steady and blinking) from MIDI.
- Automatic reconnection, LaunchAgent, `.pkg` installer with statically linked libusb.
- djay mapping provided.
