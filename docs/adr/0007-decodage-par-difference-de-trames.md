# 0007. Décodage des trames par différence

- Statut : Acceptée
- Date : 2026-10-21

## Contexte

La console n'envoie pas d'événements mais des **trames d'état de 38 octets en continu**
(boutons en bits, contrôles analogiques en octets). Les applications DJ attendent des
événements MIDI (notes, CC), et un mapping stable par MIDI Learn.

## Décision

`HerculesFrameDecoder` compare chaque trame à la précédente et ne produit que des messages
pour les octets qui ont changé :

- bouton (octet `n`, bit `b`) → note `n × 8 + b`, canal 1, Note On vélocité 127 à l'appui et
  Note Off au relâchement ;
- contrôle analogique (octet `n`) → CC `n`, valeur = octet ÷ 2, émis seulement si la valeur
  sur 7 bits change ;
- la première trame fixe l'état initial sans rien émettre ; le compteur (octet 37) est
  ignoré.

La table des LEDs réutilise les mêmes numéros de notes pour que renvoyer l'état d'un bouton
sur sa note allume sa LED ([ADR 0005](0005-leds-par-transferts-de-controle.md)).

## Conséquences

- Aucun fichier de mapping à maintenir : les numéros découlent de la disposition de la trame.
- Les numéros sont un **contrat public** : les mappings des utilisateurs en dépendent, y compris
  le mapping djay fourni. Les changer est un changement cassant.
- Les boutons sans LED ne sont pas nommés dans la documentation ; `--dump` permet de les
  identifier.
- La trame est une disposition observée, pas une spécification : un autre firmware ou modèle
  (`--pid`) peut en avoir une différente.
