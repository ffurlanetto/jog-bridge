# Architecture Decision Records (ADR)

Every structural decision is recorded in a numbered file that is not rewritten: if a decision
changes, a new ADR is added that replaces the old one (status "Superseded by"). Template:
[template.md](template.md).

| No. | Title | Status |
|---|---|---|
| [0001](0001-record-architecture-decisions.md) | Record architecture decisions | Accepted |
| [0002](0002-userspace-usb-access-with-libusb.md) | Userspace USB access with libusb | Accepted |
| [0003](0003-virtual-coremidi-ports-with-fixed-ids.md) | Virtual CoreMIDI ports with fixed identifiers | Accepted |
| [0004](0004-static-linking-of-libusb.md) | Static linking of libusb | Accepted |
| [0005](0005-leds-via-control-transfers.md) | LEDs driven by control transfers | Accepted |
| [0006](0006-launchagent-and-unsigned-pkg.md) | LaunchAgent and unsigned `.pkg` installer | Accepted |
| [0007](0007-frame-diff-decoding.md) | Frame decoding by difference | Accepted |
| [0008](0008-project-name-and-third-party-trademarks.md) | Project name and third-party trademarks | Accepted |
| [0009](0009-guardrails-enforced-outside-the-model.md) | Guardrails enforced outside the model: secrets and tests | Accepted |
| [0010](0010-delivery-flow.md) | Delivery flow: branch, draft, wait for CI | Accepted |

> ADRs 0002 to 0010 were written after the fact from the code and the project history. Their
> context and consequences are reconstructed; correct them if an original motivation differs.
