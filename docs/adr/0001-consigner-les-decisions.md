# 0001. Consigner les décisions d'architecture

- Statut : Acceptée
- Date : 2026-10-21

## Contexte

Le projet repose sur des choix qui ne se devinent pas à la lecture du code : accès USB en
espace utilisateur, liaison statique, LEDs par transferts de contrôle, distribution non
signée. Sans trace écrite, ils risquent d'être « corrigés » par erreur.

## Décision

Nous consignons chaque décision structurante dans `docs/adr/`, au format du
[gabarit](template.md), un fichier par décision, numéroté dans l'ordre.

## Conséquences

- Les contributeurs (et les agents de code) trouvent le *pourquoi* au même endroit.
- Une décision se change en ajoutant un ADR, pas en réécrivant l'historique.
- Un léger coût de rédaction pour chaque changement structurant.
