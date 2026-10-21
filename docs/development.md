# Développement

## Prérequis

```sh
xcode-select --install
brew install libusb pkg-config
```

`Package.swift` interroge `pkg-config` à l'évaluation du manifeste pour trouver la
bibliothèque statique `libusb-1.0.a` et les en-têtes. Il ajoute lui-même les chemins
Homebrew (`/opt/homebrew`, `/usr/local`) au `PATH`, car Xcode évalue le manifeste sans
ce `PATH`.

## Compiler et lancer

```sh
swift build -c release
.build/release/jog-bridge --list     # console branchée
.build/release/jog-bridge --dump     # trafic USB et MIDI
```

Le projet s'ouvre aussi dans Xcode (*File → Open…* sur le dossier ou `Package.swift`).

Si l'agent installé tourne, il tient déjà la console : arrêtez-le avant de lancer une version
de développement.

```sh
launchctl bootout gui/$(id -u)/local.jog-bridge
# … essais …
launchctl bootstrap gui/$(id -u) ~/Library/LaunchAgents/local.jog-bridge.plist
```

## Déboguer

- `--dump` journalise chaque octet de trame qui change (`USB Δ : [03] 00→04`), le message
  MIDI produit (`→ MIDI : 90 0A 7F`) et les messages reçus de l'application
  (`MIDI → LEDs : …`).
- Les logs vont sur stderr ; sous LaunchAgent : `/tmp/jog-bridge.log`.
- *Configuration audio et MIDI → Fenêtre → Afficher le studio MIDI* montre les ports
  virtuels ; *Moniteur MIDI* (ou toute application de monitoring) permet de vérifier le flux.

## Tests

Il n'y a pas encore de tests automatisés. `HerculesFrameDecoder`, `HerculesLEDs` et
`MIDIStreamParser` sont des structures sans dépendance matérielle et se prêtent bien à des
tests unitaires avec le framework Testing (cible `jog-bridgeTests` à créer ; les types
sont `internal` dans un `executableTarget`, ce qui impose `@testable import`).

## Construire le .pkg

```sh
./scripts/build-pkg.sh 1.0.0
```

Le script compile, assemble `.build/pkg/root` et `.build/pkg/scripts`, puis écrit
`dist/jog-bridge-<version>.pkg`. Ces deux dossiers sont ignorés par git.

Vérifier le contenu d'un pkg sans l'installer :

```sh
pkgutil --expand dist/jog-bridge-1.0.0.pkg /tmp/pkg-check
cat /tmp/pkg-check/Scripts/postinstall
```

Vérifier que le binaire n'a pas de dépendance dynamique à libusb :

```sh
otool -L .build/release/jog-bridge     # ne doit pas lister libusb
```

Journal d'installation en cas d'échec :
`grep -i jog-bridge /var/log/install.log | tail -30`.

## Publier une version

1. Mettre à jour `CHANGELOG.md`.
2. `./scripts/build-pkg.sh X.Y.Z`, puis `shasum -a 256 dist/jog-bridge-X.Y.Z.pkg`.
3. Créer le tag `vX.Y.Z` et joindre le `.pkg` à la release GitHub, en partant de
   [`.github/RELEASE_TEMPLATE.md`](../.github/RELEASE_TEMPLATE.md) (somme SHA-256, mention
   que le paquet n'est pas signé : [ADR 0006](adr/0006-launchagent-et-pkg-non-signe.md)).
