<p align="center">
  <img src="assets/branding/banner.svg" alt="jog-bridge — USB-to-MIDI bridge for DJ controllers on macOS" width="100%">
</p>

<p align="center">
  <a href="https://github.com/ffurlanetto/jog-bridge/actions/workflows/ci.yml"><img src="https://github.com/ffurlanetto/jog-bridge/actions/workflows/ci.yml/badge.svg" alt="CI"></a>
  <a href="LICENSE"><img src="https://img.shields.io/badge/licence-MIT-blue" alt="Licence MIT"></a>
  <img src="https://img.shields.io/badge/macOS-12%2B-lightgrey" alt="macOS 12+">
  <img src="https://img.shields.io/badge/Swift-5.9-orange" alt="Swift 5.9">
</p>

# jog-bridge

**Passerelle USB → MIDI pour contrôleurs DJ sur macOS.** Branchez la console, ouvrez votre
logiciel DJ : elle apparaît comme un périphérique MIDI, LEDs comprises.

Aujourd'hui, **jog-bridge** prend en charge la **Hercules DJ Control MP3 e2**.

La console n'est pas un périphérique MIDI standard : elle expose une interface USB
« vendor specific » (classe `0xFF`) et envoie en continu des trames d'état de 38 octets
sur un endpoint bulk. Ce petit démon lit ces trames avec libusb, les convertit en
messages MIDI et les publie sur un port **MIDI virtuel « Hercules MP3 e2 »** visible par
n'importe quelle application (djay, rekordbox, Serato…). Le sens inverse fonctionne
aussi : les messages MIDI renvoyés par l'application allument les LEDs de la console.

Aucune extension noyau, aucun DriverKit, aucun droit administrateur à l'usage.

> **jog-bridge est un projet indépendant, non affilié à Guillemot Corporation ni à
> Hercules, et ni approuvé ni sponsorisé par eux.** Le protocole USB a été établi par
> rétro-ingénierie (voir [Crédits](#crédits) et [Marques](#marques)).

## Fonctionnalités

- Boutons → notes MIDI, potentiomètres / faders / encodeurs → Control Change.
- LEDs pilotables depuis l'application DJ (fixes et clignotantes).
- Reconnexion automatique quand on branche ou débranche la console.
- Démarrage automatique à l'ouverture de session (LaunchAgent).
- Binaire autonome : libusb est lié statiquement.
- Mapping djay prêt à l'emploi : [`Hercules MP3 e2.djayMidiMapping`](Hercules%20MP3%20e2.djayMidiMapping).

## 1. Prérequis

```sh
xcode-select --install          # outils de compilation Swift
brew install libusb pkg-config
```

macOS 12 ou plus récent. Homebrew n'est nécessaire que sur la machine qui compile.

> Si un ancien driver Hercules a été installé sur ce Mac, désinstallez-le : il
> s'approprie l'interface USB et la passerelle ne pourra pas la réclamer.

## 2. Compiler

```sh
swift build -c release
```

Le binaire est dans `.build/release/jog-bridge`.

## 3. Vérifier la console (première fois)

Branchez la console, puis :

```sh
.build/release/jog-bridge --list
```

On attend un périphérique `06F8:B105`. Sur une MP3 e2, l'interface 0 expose un endpoint
**IN bulk `0x81`** (c'est lui qui porte les trames d'état) ; l'interface 1 expose
`0x82` / `0x03`, inutilisables tels quels (voir [protocole USB](docs/usb-protocol.md)).
La passerelle détecte l'endpoint seule ; si la détection se trompe, forcez-le avec
`--in 0x81`.

Puis testez en direct :

```sh
.build/release/jog-bridge --dump
```

Bougez le crossfader, appuyez sur Play : chaque action affiche les octets qui ont changé
dans la trame USB et le message MIDI correspondant. **Ctrl-C** pour arrêter.

Pour un contrôle indépendant, l'utilitaire *Configuration audio et MIDI* de macOS
(Fenêtre → Afficher le studio MIDI) doit montrer le port « Hercules MP3 e2 » tant
que la passerelle tourne.

## 4. Installer en démarrage automatique

### Via le .pkg (recommandé)

```sh
./scripts/build-pkg.sh 1.0.0        # produit dist/jog-bridge-1.0.0.pkg
open dist/jog-bridge-1.0.0.pkg
```

Le `.pkg` n'est pas signé par un Developer ID : Gatekeeper le bloquera au premier
double-clic (« développeur non identifié »). Clic droit → *Ouvrir*, ou *Réglages
Système → Confidentialité et sécurité → Ouvrir quand même*.

L'installation copie le binaire dans `/usr/local/bin/`, installe le LaunchAgent dans
`~/Library/LaunchAgents/` et le démarre immédiatement.

**Autorisation en arrière-plan.** Au premier démarrage, macOS demande d'autoriser
l'élément `jog-bridge`. Vérifiez qu'il est activé dans *Réglages Système →
Général → Ouverture et extensions → Autoriser en arrière-plan*. Tant qu'il est
désactivé, launchd refuse de charger l'agent (`Bootstrap failed: 5: Input/output error`).
Une fois activé, déconnectez-vous / reconnectez-vous, ou chargez l'agent à la main :

```sh
launchctl bootstrap gui/$(id -u) ~/Library/LaunchAgents/local.jog-bridge.plist
```

### Manuellement

```sh
sudo install -m 755 .build/release/jog-bridge /usr/local/bin/
cp local.jog-bridge.plist ~/Library/LaunchAgents/
launchctl bootstrap gui/$(id -u) ~/Library/LaunchAgents/local.jog-bridge.plist
```

Vérifier que le service tourne :

```sh
launchctl print gui/$(id -u)/local.jog-bridge | grep -E "state|pid|runs|last exit"
tail -f /tmp/jog-bridge.log
```

### Désinstaller

```sh
launchctl bootout gui/$(id -u)/local.jog-bridge
rm ~/Library/LaunchAgents/local.jog-bridge.plist
sudo rm /usr/local/bin/jog-bridge
```

## 5. Dans le logiciel DJ

Sélectionnez le contrôleur « Hercules MP3 e2 » (entrée et sortie) dans les réglages MIDI,
puis soit utilisez le mapping djay fourni, soit le **MIDI Learn** pour associer chaque
bouton. Les identifiants des ports sont fixes : le mapping est conservé d'une session à
l'autre. La table complète des notes et des CC est dans
[docs/midi-mapping.md](docs/midi-mapping.md).

## Options

| Option | Rôle |
|---|---|
| `--list` | Liste les périphériques Hercules et leurs endpoints |
| `--dump` | Affiche les changements d'état de la console et les messages MIDI échangés |
| `--name <nom>` | Renomme les ports MIDI virtuels |
| `--pid <hex>` | Autre Product ID (MP3 LE, Glow…) — non testé |
| `--interface <n>` | Interface USB à réclamer (défaut 0) |
| `--in <hex>` | Force l'endpoint d'entrée (ex. `0x81`) |
| `--help` | Affiche l'aide |

## Dépannage

- **« Impossible de réclamer l'interface »** : un driver Hercules est encore installé,
  ou une autre application (Mixxx) tient déjà la console. Fermez-la.
- **Rien dans `--dump`** : vérifiez l'endpoint avec `--list`, essayez `--in 0x81`.
- **L'agent ne démarre pas après l'installation** : voir l'autorisation en arrière-plan
  ci-dessus.

Plus de détails dans [docs/troubleshooting.md](docs/troubleshooting.md).

## Documentation

- [Architecture](docs/architecture.md)
- [Protocole USB](docs/usb-protocol.md)
- [Mapping MIDI et LEDs](docs/midi-mapping.md)
- [Développement](docs/development.md)
- [Dépannage](docs/troubleshooting.md)
- [Identité et marques](docs/branding.md)
- [Décisions d'architecture (ADR)](docs/adr/README.md)
- [Contribuer](CONTRIBUTING.md) · [Changelog](CHANGELOG.md) · [Sécurité](SECURITY.md)

## Limites

- macOS uniquement. Un portage iPadOS n'est pas possible tel quel : voir
  [ADR 0002](docs/adr/0002-libusb-en-espace-utilisateur.md).
- Seule la MP3 e2 (`06F8:B105`) a été testée.

## Crédits

La séquence d'initialisation et la table des LEDs viennent des travaux de
rétro-ingénierie de [foomatic/djcontrol](https://github.com/foomatic/djcontrol)
(`Protocol.txt`, `djcontrol.py`).

## Marques

Hercules est une marque de Guillemot Corporation. djay, rekordbox, Serato, Mixxx, macOS,
CoreMIDI et les autres noms cités appartiennent à leurs propriétaires respectifs. Ils ne
sont employés que pour indiquer la compatibilité (« fonctionne avec ») : ce projet n'a
aucun lien avec ces sociétés. Les éléments visuels de jog-bridge (`assets/branding/`) sont
originaux et ne reprennent aucun logo de tiers. Voir [docs/branding.md](docs/branding.md).

## Licences

Code du projet : [MIT](LICENSE).

Le binaire distribué dans le `.pkg` embarque [libusb](https://libusb.info), sous licence
**LGPL 2.1**, lié statiquement. Le code source du projet et les scripts de build étant
publics, le binaire peut être relié avec une autre version de libusb (voir
[ADR 0004](docs/adr/0004-liaison-statique-de-libusb.md)).
