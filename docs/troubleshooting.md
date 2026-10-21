# Dépannage

## Diagnostic rapide

```sh
launchctl print gui/$(id -u)/local.jog-bridge | grep -E "state|pid|runs|last exit"
tail -30 /tmp/jog-bridge.log
jog-bridge --list
```

Un démarrage sain se termine par :

```
Ports MIDI virtuels « Hercules MP3 e2 » créés.
Console connectée — entrée 0x81 (bulk)
```

## L'installation du .pkg échoue (« erreur pendant l'exécution des scripts »)

Le `postinstall` a retourné un code non nul. Les fichiers ont pourtant déjà été copiés
(binaire et plist), ce qui donne l'impression d'une installation à moitié réussie.

Consulter la cause : `grep -i jog-bridge /var/log/install.log | tail -30`.

Cause connue : `launchctl bootstrap` échoue quand l'agent n'est pas autorisé (ci-dessous) ou
quand un ancien service est encore en cours de déchargement. Depuis la version corrigée, le
script réessaie puis ignore l'échec ; si vous voyez encore l'erreur, vérifiez que vous
installez un `.pkg` construit après la correction (`pkgutil --expand`, puis chercher
`kickstart` dans `Scripts/postinstall`).

## L'agent ne démarre pas : `Bootstrap failed: 5: Input/output error`

Réglages Système → Général → **Ouverture et extensions → Autoriser en arrière-plan** :
l'élément `jog-bridge` doit être activé. Puis :

```sh
launchctl bootstrap gui/$(id -u) ~/Library/LaunchAgents/local.jog-bridge.plist
```

Un état « Pas d'exécution en arrière-plan » dans cette liste signifie que le processus
n'est pas chargé.

## « Impossible de réclamer l'interface »

Une autre application (ou un ancien driver Hercules) tient l'interface USB. Fermez-la, ou
désinstallez le driver. Mixxx et d'autres logiciels DJ peuvent aussi réclamer la console.

## La console est détectée mais rien n'arrive dans l'application DJ

1. `jog-bridge --dump` : chaque action doit afficher une ligne `USB Δ`. Sinon,
   vérifiez l'endpoint avec `--list` et essayez `--in 0x81`.
2. Vérifiez que l'application DJ utilise le port « Hercules MP3 e2 » en entrée **et** en
   sortie.
3. Si un message sort sur le mauvais canal ou avec une autre note, consultez
   [midi-mapping.md](midi-mapping.md).

## Les LEDs ne s'allument pas

- L'application doit renvoyer la même note que le bouton, sur le canal 1 (fixe) ou 2
  (clignotante). Voir [midi-mapping.md](midi-mapping.md).
- `--dump` affiche `MIDI → LEDs : …` pour chaque message reçu de l'application. S'il
  n'apparaît rien, l'application n'envoie pas sur la destination « Hercules MP3 e2 ».
- Un journal `Écriture LED : …` signale une erreur USB.

## Gatekeeper bloque le .pkg

Le paquet n'est pas signé. Clic droit → *Ouvrir*, ou *Réglages Système → Confidentialité
et sécurité → Ouvrir quand même*.

## Signaler un problème

Joignez `jog-bridge --list`, la sortie de `--dump` et `/tmp/jog-bridge.log`.
