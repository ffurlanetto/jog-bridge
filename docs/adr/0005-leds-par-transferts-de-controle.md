# 0005. LEDs pilotées par transferts de contrôle

- Statut : Acceptée
- Date : 2026-10-21

## Contexte

L'interface 1 de la console déclare un endpoint OUT bulk (`0x03`, 12 octets), qui semble
être le canal naturel pour les LEDs. En pratique, la taille de paquet déclarée est invalide
et macOS ne crée pas les pipes correspondants : aucun transfert n'est possible par là.

## Décision

Les LEDs sont pilotées par des **transferts de contrôle sur l'endpoint 0** : cinq requêtes
`bmRequestType 0x40`, `bRequest 0x2D + n`, `wValue` = bloc de 16 bits. L'état complet des
5 blocs est renvoyé à chaque changement et après chaque reconnexion. Voir
[usb-protocol.md](../usb-protocol.md).

## Conséquences

- Pas d'endpoint OUT à configurer : l'option `--out` n'existe pas.
- L'état des LEDs est mémorisé côté démon, donc restauré après un débranchement.
- Chaque changement coûte cinq transferts de contrôle (timeout 100 ms chacun) ; acceptable
  pour des LEDs, à surveiller si de l'animation rapide est ajoutée.
- Le protocole vient de la rétro-ingénierie de djcontrol : un autre firmware pourrait se
  comporter autrement.
