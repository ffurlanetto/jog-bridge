---
name: Bug
about: Quelque chose ne fonctionne pas
labels: bug
---

## Problème

<!-- Ce qui se passe, ce que vous attendiez. -->

## Environnement

- macOS :
- Puce (Apple Silicon / Intel) :
- Version de jog-bridge :
- Installation (pkg / manuelle) :
- Application DJ :

## Diagnostic

```
jog-bridge --list
```

```
launchctl print gui/$(id -u)/local.jog-bridge | grep -E "state|pid|runs|last exit"
```

```
tail -50 /tmp/jog-bridge.log
```

<!-- Si le problème concerne les entrées/LEDs, ajoutez la sortie de `jog-bridge --dump`. -->
