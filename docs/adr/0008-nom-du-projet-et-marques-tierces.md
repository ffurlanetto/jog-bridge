# 0008. Nom du projet et marques tierces

- Statut : Acceptée
- Date : 2026-10-21

## Contexte

Le projet s'appelait `hercules-bridge`. « Hercules » est une marque de Guillemot Corporation :
l'utiliser comme premier élément du nom d'un dépôt public, d'un binaire et d'un paquet peut
laisser croire à un outil officiel. Par ailleurs, le projet n'a pas de raison technique de se
limiter à un modèle.

## Décision

- Le projet s'appelle **jog-bridge**. Le nom ne cite aucune marque (vérifié : aucun dépôt
  GitHub du même nom au moment du choix ; pas de recherche dans les bases de marques).
- Le renommage touche le paquet SwiftPM, le dossier `Sources/jog-bridge`, le binaire, le
  `.pkg`, le plist, le label launchd `local.jog-bridge`, le journal `/tmp/jog-bridge.log`
  et la documentation.
- « Hercules » reste employé **pour décrire le matériel supporté** : nom des ports MIDI
  (« Hercules MP3 e2 »), fabricant déclaré à CoreMIDI, fichier de mapping djay, types
  internes (`HerculesDevice`, `HerculesLEDs`…).
- Une mention de non-affiliation figure dans le README et les notes de release
  ([branding](../branding.md)).
- Les identifiants uniques des ports MIDI (`HER1`, `HER2`) ne changent pas, afin de
  préserver les mappings existants ([ADR 0003](0003-ports-midi-virtuels-coremidi.md)).

## Conséquences

- Une installation de l'ancienne version (`local.hercules-bridge`) doit être désinstallée à
  la main : les deux agents se disputeraient l'interface USB. Le projet n'ayant pas été
  publié, aucune migration automatique n'est fournie.
- Les noms des ports MIDI ne suivent pas le nom du projet : c'est voulu, ils désignent
  l'appareil.
- Si un autre modèle est ajouté, son nom apparaîtra de la même façon (ports, docs), jamais
  dans le nom du projet.
- Ce choix réduit le risque lié à la marque sans l'éliminer ; il ne constitue pas un avis
  juridique.

## Alternatives écartées

- **Garder `hercules-bridge`** avec une mention de non-affiliation : plus risqué.
- **`dj-bridge`** : générique, difficile à trouver, proche de `django-bridge` et de
  `djay-pro-bridge`.
- **`e2midi`** : colle le projet à un seul modèle.
