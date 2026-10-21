---
name: Bug
about: Something does not work
labels: bug
---

## Problem

<!-- What happens, what you expected. -->

## Environment

- macOS:
- Chip (Apple Silicon / Intel):
- jog-bridge version:
- Installation (pkg / manual):
- DJ application:

## Diagnosis

```
# the installed executable is /Applications/Jog Bridge.app/Contents/MacOS/jog-bridge
jog-bridge --list
```

```
launchctl print gui/$(id -u)/local.jog-bridge | grep -E "state|pid|runs|last exit"
```

```
tail -50 /tmp/jog-bridge.log
```

<!-- If the problem concerns inputs/LEDs, add the output of `jog-bridge --dump`. -->
