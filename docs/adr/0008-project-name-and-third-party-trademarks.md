# 0008. Project name and third-party trademarks

- Status: Accepted
- Date: 2026-10-21

## Context

The project was called `hercules-bridge`. "Hercules" is a trademark of Guillemot Corporation:
using it as the first element of the name of a public repository, binary and package may suggest
an official tool. Besides, the project has no technical reason to be limited to one model.

## Decision

- The project is called **jog-bridge**. The name cites no trademark (checked: no GitHub
  repository of the same name at the time of the choice; no trademark database search).
- The rename affects the SwiftPM package, the `Sources/jog-bridge` folder, the binary, the
  `.pkg`, the plist, the launchd label `local.jog-bridge`, the log `/tmp/jog-bridge.log` and
  the documentation.
- "Hercules" remains in use **to describe the supported hardware**: MIDI port names ("Hercules
  MP3 e2"), the manufacturer declared to CoreMIDI, the djay mapping file, internal types
  (`HerculesDevice`, `HerculesLEDs`…).
- A non-affiliation notice appears in the README and the release notes
  ([branding](../branding.md)).
- The MIDI ports' unique identifiers (`HER1`, `HER2`) do not change, to preserve existing
  mappings ([ADR 0003](0003-virtual-coremidi-ports-with-fixed-ids.md)).

## Consequences

- An installation of the old version (`local.hercules-bridge`) must be uninstalled by hand: the
  two agents would fight over the USB interface. The project not having been published, no
  automatic migration is provided.
- The MIDI port names do not follow the project name: this is intended, they designate the
  device.
- If another model is added, its name will appear in the same way (ports, docs), never in the
  project name.
- This choice reduces the trademark risk without removing it; it is not legal advice.

## Alternatives considered

- **Keep `hercules-bridge`** with a non-affiliation notice: riskier.
- **`dj-bridge`**: generic, hard to find, close to `django-bridge` and `djay-pro-bridge`.
- **`e2midi`**: ties the project to a single model.
