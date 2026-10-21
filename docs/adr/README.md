# Décisions d'architecture (ADR)

Chaque décision structurante est consignée dans un fichier numéroté, qu'on ne réécrit pas :
si une décision change, on ajoute un nouvel ADR qui remplace l'ancien (statut « Remplacé
par »). Gabarit : [template.md](template.md).

| N° | Titre | Statut |
|---|---|---|
| [0001](0001-consigner-les-decisions.md) | Consigner les décisions d'architecture | Acceptée |
| [0002](0002-libusb-en-espace-utilisateur.md) | Accès USB par libusb en espace utilisateur | Acceptée |
| [0003](0003-ports-midi-virtuels-coremidi.md) | Ports MIDI virtuels CoreMIDI à identifiants fixes | Acceptée |
| [0004](0004-liaison-statique-de-libusb.md) | Liaison statique de libusb | Acceptée |
| [0005](0005-leds-par-transferts-de-controle.md) | LEDs pilotées par transferts de contrôle | Acceptée |
| [0006](0006-launchagent-et-pkg-non-signe.md) | LaunchAgent et installeur `.pkg` non signé | Acceptée |
| [0007](0007-decodage-par-difference-de-trames.md) | Décodage des trames par différence | Acceptée |
| [0008](0008-nom-du-projet-et-marques-tierces.md) | Nom du projet et marques tierces | Acceptée |

> Les ADR 0002 à 0008 ont été rédigés a posteriori à partir du code et de l'historique du
> projet. Leur contexte et leurs conséquences sont reconstitués ; corrigez-les si une
> motivation d'origine diffère.
