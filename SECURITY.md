# Politique de sécurité

## Signaler une vulnérabilité

Merci de **ne pas ouvrir d'issue publique** pour une faille de sécurité. Utilisez le
signalement privé de GitHub (*Security → Report a vulnerability*) sur ce dépôt.

## Périmètre

`jog-bridge` tourne avec les droits de l'utilisateur (LaunchAgent, pas de démon root)
et accède à un périphérique USB précis (VID `06F8`). Il n'ouvre aucun port réseau.

Points sensibles à connaître :

- le `.pkg` n'est **pas signé ni notarisé** ; vérifiez son origine (compilez-le vous-même
  avec `scripts/build-pkg.sh`) ;
- le `postinstall` s'exécute en root pendant l'installation et écrit dans le dossier
  `LaunchAgents` de l'utilisateur connecté ;
- le journal est écrit dans `/tmp/jog-bridge.log`, lisible par les autres utilisateurs
  de la machine ; il ne contient que des événements USB/MIDI.
