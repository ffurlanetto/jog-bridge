# AGENTS.md

Instructions pour les agents de code (Claude Code, Codex, Cursor, Copilot…) qui travaillent
sur ce dépôt. Les humains liront plutôt le [README](README.md) et [CONTRIBUTING.md](CONTRIBUTING.md).

## Projet

`jog-bridge` est un démon macOS en ligne de commande (Swift 5.9, macOS 12+) qui lit
les trames USB de la Hercules DJ Control MP3 e2 avec libusb et les publie sur des ports
MIDI virtuels CoreMIDI. Les messages MIDI reçus pilotent les LEDs de la console.

Un seul exécutable, aucune dépendance Swift externe. libusb est une dépendance C
système, liée statiquement.

## Commandes

```sh
brew install libusb pkg-config      # prérequis de compilation
swift build -c release              # binaire : .build/release/jog-bridge
.build/release/jog-bridge --list   # diagnostic USB (console branchée)
.build/release/jog-bridge --dump   # trafic USB et MIDI en direct
./scripts/build-pkg.sh 1.0.0        # dist/jog-bridge-1.0.0.pkg
```

Il n'y a pas encore de tests automatisés. La vérification passe par la compilation et,
quand la console est branchée, par `--dump`.

## Structure

| Chemin | Rôle |
|---|---|
| `Sources/jog-bridge/main.swift` | Assemblage : config, USB, ports MIDI, signaux, thread de lecture |
| `Sources/jog-bridge/Config.swift` | Options CLI, erreurs, `log()` (stderr), `hex()` |
| `Sources/jog-bridge/HerculesDevice.swift` | Accès libusb, initialisation, reconnexion, envoi des LEDs |
| `Sources/jog-bridge/FrameDecoder.swift` | Trame USB de 38 octets → messages MIDI (par différence) |
| `Sources/jog-bridge/LEDs.swift` | Note MIDI → bit de LED, état des 5 blocs de 16 bits |
| `Sources/jog-bridge/MIDIStreamParser.swift` | Découpage d'un flux d'octets MIDI en messages (sens app → console) |
| `Sources/jog-bridge/VirtualMIDIPorts.swift` | Source et destination CoreMIDI virtuelles |
| `Sources/CLibUSB/` | Module système (`shim.h`, `module.modulemap`) pour libusb |
| `scripts/build-pkg.sh`, `scripts/pkg/postinstall` | Construction et post-installation du `.pkg` |
| `local.jog-bridge.plist` | LaunchAgent |
| `docs/` | Architecture, protocole, mapping, ADR |

## Conventions

- Style du code existant : indentation 4 espaces, types en PascalCase, le reste en camelCase.
- Les commentaires et les messages de log sont **en français** ; garder cette langue.
- Les commentaires expliquent le *pourquoi* (contraintes matérielles, particularités du
  protocole), pas le *quoi*.
- Pas de Combine ; préférer async/await si de l'asynchrone est introduit.
- Les logs vont sur **stderr** via `log(_:)` (le LaunchAgent redirige vers `/tmp/jog-bridge.log`).
- Ne pas ajouter de dépendance Swift sans en discuter : le binaire doit rester autonome.

## Pièges connus

- **Les LEDs ne passent pas par les endpoints bulk** de l'interface 1 : leur taille de
  paquet est invalide et macOS ne crée pas les pipes. Elles passent par des transferts de
  contrôle sur l'endpoint 0 (requêtes `0x2D…0x31`). Voir [ADR 0005](docs/adr/0005-leds-par-transferts-de-controle.md).
- **Concurrence** : trois contextes — thread principal (`dispatchMain`, signaux), thread
  `hercules-usb-reader` (boucle USB), thread CoreMIDI (callback de la destination
  virtuelle). `HerculesDevice` protège `handle`, `endpoints` et `ledBlocks` avec un
  `NSLock` ; `leds` et `ledParser` (dans `main.swift`) ne sont touchés que depuis le thread CoreMIDI.
- **`Package.swift` utilise `unsafeFlags`** (liaison statique de libusb). Le paquet ne peut
  donc pas être utilisé comme dépendance d'un autre paquet. Ne pas passer `pkgConfig:` à
  `.systemLibrary` : cela réintroduit `-lusb-1.0` et la dépendance dynamique. Voir
  [ADR 0004](docs/adr/0004-liaison-statique-de-libusb.md).
- **Les notes MIDI sont dérivées de la position dans la trame** (`octet × 8 + bit`), et la
  table des LEDs réutilise ces mêmes numéros. Changer l'un casse l'autre et casse les
  mappings des utilisateurs (dont `Hercules MP3 e2.djayMidiMapping`).
- **Les identifiants uniques des ports MIDI sont fixes** (`0x48455231`, `0x48455232`) pour
  que les applications retrouvent leur mapping. Ne pas les changer.
- **`launchctl bootstrap` peut échouer** (erreur 5) si l'élément n'est pas autorisé dans
  *Ouverture et extensions*. Le `postinstall` ne doit jamais faire échouer l'installation
  pour cette raison.
- `dist/` et `.build/` ne sont jamais committés.

## Nom et marques

Le projet s'appelle **jog-bridge** ; ne pas réintroduire `hercules-bridge`. « Hercules »
n'est employé que pour désigner le matériel (ports MIDI, mapping, docs, types internes). Ne
pas ajouter de logo ni d'image d'un tiers. Voir [docs/branding.md](docs/branding.md) et
[ADR 0008](docs/adr/0008-nom-du-projet-et-marques-tierces.md).

## Ce qu'il ne faut pas faire sans demande explicite

- Installer le `.pkg`, charger ou décharger le LaunchAgent sur la machine de l'utilisateur.
- Committer, pousser, créer une release.
- Modifier les identifiants USB, les numéros de notes/CC ou les identifiants de ports MIDI.

## Documentation

Mettre à jour la documentation avec le code : `docs/usb-protocol.md` et
`docs/midi-mapping.md` pour le comportement, un nouvel ADR (`docs/adr/`) pour toute
décision structurante, et `CHANGELOG.md` pour tout changement visible par l'utilisateur.
