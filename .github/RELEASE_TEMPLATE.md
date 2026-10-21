# jog-bridge vX.Y.Z

<!-- Une phrase : ce que cette version apporte. -->

## Nouveautés

- 

## Corrections

- 

## Installation

1. Téléchargez `jog-bridge-X.Y.Z.pkg` ci-dessous.
2. **Ce paquet n'est pas signé ni notarisé.** macOS le bloquera au premier double-clic :
   clic droit → *Ouvrir*, ou *Réglages Système → Confidentialité et sécurité → Ouvrir
   quand même*.
3. Après l'installation, vérifiez que l'élément `jog-bridge` est activé dans *Réglages
   Système → Général → Ouverture et extensions → Autoriser en arrière-plan*. Sans cela,
   l'agent ne démarre pas.
4. Branchez la console : le port MIDI « Hercules MP3 e2 » apparaît dans votre logiciel DJ.

Vérifier l'intégrité du téléchargement :

```sh
shasum -a 256 jog-bridge-X.Y.Z.pkg
# attendu : <SHA-256>
```

Vous préférez compiler vous-même ? Voir le [README](../README.md#2-compiler).

## Mise à jour et désinstallation

Réinstaller le `.pkg` remplace le binaire et recharge l'agent. Pour désinstaller :

```sh
launchctl bootout gui/$(id -u)/local.jog-bridge
rm ~/Library/LaunchAgents/local.jog-bridge.plist
sudo rm /usr/local/bin/jog-bridge
```

## Matériel testé

- Hercules DJ Control MP3 e2 (`06F8:B105`)

---

*jog-bridge est un projet indépendant, non affilié à Guillemot Corporation ni à Hercules, et
ni approuvé ni sponsorisé par eux. Hercules est une marque de Guillemot Corporation.*

Changelog complet : [CHANGELOG.md](../CHANGELOG.md)
