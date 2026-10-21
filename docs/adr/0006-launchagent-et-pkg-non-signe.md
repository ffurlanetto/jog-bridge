# 0006. LaunchAgent et installeur `.pkg` non signé

- Statut : Acceptée
- Date : 2026-10-21

## Contexte

Le démon doit tourner en permanence et se reconnecter à la console. Il doit aussi pouvoir
être installé par quelqu'un qui n'est pas développeur, depuis une release GitHub. Le projet
n'a pas de compte Apple Developer ni de certificat Developer ID.

## Décision

- Le démon est un **LaunchAgent** utilisateur (`local.jog-bridge`, `RunAtLoad`,
  `KeepAlive`, `ProcessType Interactive`), pas un démon système : il tourne dans la
  session de l'utilisateur, avec ses droits. Les ports MIDI virtuels sont ceux de cette
  session.
- La distribution se fait par un `.pkg` construit par `scripts/build-pkg.sh` : binaire dans
  `/usr/local/bin`, plist copié dans `~/Library/LaunchAgents` par un `postinstall`.
- Le `.pkg` **n'est pas signé ni notarisé** ; le README explique comment contourner
  Gatekeeper.
- Le `postinstall` **ne fait jamais échouer l'installation** à cause de `launchctl` :
  `bootstrap` est réessayé, suivi d'un `kickstart`, et les erreurs sont ignorées.

## Conséquences

- Premier lancement : macOS exige d'autoriser l'élément dans *Ouverture et extensions →
  Autoriser en arrière-plan*. Tant que ce n'est pas fait, `launchctl bootstrap` échoue avec
  l'erreur 5. Le script ne peut pas l'accorder à la place de l'utilisateur ; sans la
  tolérance aux erreurs, l'installeur affichait « échec » alors que tous les fichiers étaient
  en place.
- Le `postinstall` désigne l'utilisateur via `/dev/console` : une installation sans session
  graphique (à distance, écran de connexion) ne cible pas le bon compte.
- `KeepAlive` ne sert qu'en cas de crash : l'absence de la console n'arrête pas le
  processus ([architecture](../architecture.md)).
- Signer et notariser le `.pkg` supprimerait l'avertissement Gatekeeper ; à envisager si le
  projet obtient un Developer ID.

## Alternatives écartées

- **LaunchDaemon (root)** : droits inutiles et ports MIDI hors de la session utilisateur.
- **Lancement manuel seulement** : disponible (README), mais pas adapté à un usage courant.
