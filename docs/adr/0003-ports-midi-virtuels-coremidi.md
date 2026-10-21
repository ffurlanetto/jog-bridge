# 0003. Ports MIDI virtuels CoreMIDI à identifiants fixes

- Statut : Acceptée
- Date : 2026-10-21

## Contexte

Les logiciels DJ (djay, rekordbox, Serato…) ne parlent pas USB propriétaire : ils attendent
un périphérique MIDI. Il faut aussi un chemin de retour pour les LEDs, et que le mapping
d'un utilisateur survive à un redémarrage.

## Décision

Le démon crée avec CoreMIDI une **source virtuelle** (console → application) et une
**destination virtuelle** (application → console), toutes deux nommées « Hercules MP3 e2 »
(modifiable par `--name`). Leurs identifiants uniques sont fixes : `0x48455231` (« HER1 »)
et `0x48455232` (« HER2 »). Le fabricant est « Hercules ».

## Conséquences

- Fonctionne avec toute application MIDI macOS, sans configuration spécifique.
- Les applications retrouvent leur mapping et leur sélection de périphérique.
- Les ports n'existent que tant que le démon tourne.
- Changer ces identifiants casse les mappings existants : à ne faire que dans une version
  majeure, avec une note de migration.
