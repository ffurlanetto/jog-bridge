# Architecture

`jog-bridge` est un exécutable unique. Il fait le pont entre l'USB propriétaire de la
console et CoreMIDI.

```
                 ┌──────────────────────── jog-bridge ────────────────────────┐
                 │                                                                  │
 Console  ──USB──►  HerculesDevice ──trame 38 o──► HerculesFrameDecoder ──MIDI──►  VirtualMIDIPorts ──► App DJ
 (06F8:B105)     │  (libusb, thread       │                                         │   (source virtuelle)
                 │   hercules-usb-reader) │                                         │
                 │                        ◄── setLEDs ◄── HerculesLEDs ◄── MIDIStreamParser ◄── (destination virtuelle) ◄── App DJ
                 └──────────────────────────────────────────────────────────────────┘
```

## Composants

| Composant | Fichier | Responsabilité |
|---|---|---|
| Assemblage | `main.swift` | Lit la config, crée l'appareil et les ports, installe la gestion de SIGINT/SIGTERM, lance le thread de lecture, puis `dispatchMain()`. |
| Configuration | `Config.swift` | Options CLI, erreurs (`BridgeError`), `log()` sur stderr, `hex()`. |
| Appareil USB | `HerculesDevice.swift` | Ouvre la console (VID/PID), réclame l'interface, détecte l'endpoint IN, joue la séquence d'initialisation, lit en boucle, se reconnecte, envoie les LEDs. |
| Décodeur de trames | `FrameDecoder.swift` | Compare chaque trame de 38 octets à la précédente et n'émet que les changements, en notes et CC. |
| LEDs | `LEDs.swift` | Traduit une note MIDI (canal 1 ou 2) en bit dans 5 blocs de 16 bits. |
| Analyseur MIDI | `MIDIStreamParser.swift` | Reconstitue des messages MIDI complets à partir des octets reçus de l'application (running status, SysEx, temps réel). |
| Ports MIDI | `VirtualMIDIPorts.swift` | Crée une source et une destination CoreMIDI virtuelles à identifiants fixes. |
| LaunchAgent | `local.jog-bridge.plist` | Démarre et maintient le processus en session utilisateur. |

## Flux console → application

1. `HerculesDevice.run` lit en boucle l'endpoint IN (timeout de 200 ms).
2. Chaque transfert de 38 octets est passé à `HerculesFrameDecoder.decode`. La première
   trame fixe l'état initial et n'émet rien. Les autres produisent des notes (boutons) et
   des CC (analogiques) pour les octets qui ont changé.
3. `VirtualMIDIPorts.send` publie chaque message avec `MIDIReceived` sur la source virtuelle.

## Flux application → console (LEDs)

1. L'application écrit sur la destination virtuelle ; CoreMIDI appelle le bloc de
   `MIDIDestinationCreateWithBlock` sur son propre thread.
2. `MIDIStreamParser` découpe les octets en messages ; `HerculesLEDs.apply` met à jour
   les blocs si la note correspond à une LED.
3. Si un bloc a changé, `HerculesDevice.setLEDs` envoie les 5 blocs par transferts de
   contrôle ([protocole](usb-protocol.md)). À la reconnexion, l'état mémorisé est renvoyé.

## Concurrence

| Contexte | Rôle | État touché |
|---|---|---|
| Thread principal (`dispatchMain`) | Signaux SIGINT/SIGTERM : ferme l'USB puis `exit(0)`. | — |
| `hercules-usb-reader` | Boucle de lecture USB, décodeur, envoi MIDI. | `decoder` (local au thread) |
| Thread CoreMIDI | Réception des messages de l'application. | `leds`, `ledParser` (globaux de `main.swift`, uniquement ici) |

`HerculesDevice` protège `handle`, `endpoints` et `ledBlocks` par un `NSLock` : le thread
USB ouvre et ferme la connexion pendant que le thread CoreMIDI écrit les LEDs.

## Cycle de vie et reconnexion

`HerculesDevice.init` ne fait qu'initialiser libusb : l'absence de la console n'est pas
une erreur. La boucle `run` réessaie `open()` toutes les 2 s (« En attente de la console… »)
et repasse en attente si une lecture échoue (« Console déconnectée »). Le processus reste
donc vivant sans la console ; le `KeepAlive` du LaunchAgent ne sert qu'en cas de crash.

Seules deux erreurs sont fatales au démarrage (`exit(1)`) : l'échec de `libusb_init` et
l'échec de création des ports CoreMIDI.

## Distribution

`scripts/build-pkg.sh` compile en release, assemble l'arborescence
(`/usr/local/bin/jog-bridge`) et appelle `pkgbuild` avec `scripts/pkg/postinstall`.
Le script copie le plist dans le dossier `LaunchAgents` de l'utilisateur connecté (déterminé
via `/dev/console`) puis charge l'agent. Voir [ADR 0006](adr/0006-launchagent-et-pkg-non-signe.md).
