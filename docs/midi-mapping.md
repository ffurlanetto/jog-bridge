# Mapping MIDI et LEDs

Tout est sur le **canal MIDI 1** côté console → application. Les numéros sont déterminés
par la position dans la trame USB de 38 octets ([protocole](usb-protocol.md)) ; ils sont
donc stables et ne dépendent pas d'un fichier de configuration.

## Console → application

| Source | Message |
|---|---|
| Bouton (octet `n`, bit `b`, avec `n` de 0 à 5) | Note `n × 8 + b` : Note On vélocité 127 à l'appui, Note Off vélocité 0 au relâchement |
| Contrôle analogique (octet `n`, avec `n` de 6 à 18) | CC numéro `n`, valeur = octet ÷ 2 (0…127) |

Un CC n'est émis que si la valeur sur 7 bits change. La première trame reçue après une
connexion fixe l'état initial et n'émet rien.

Les CC 6 à 18 correspondent aux 13 contrôles analogiques ; pour savoir lequel est lequel,
lancez `jog-bridge --dump` et bougez-les un par un.

### Boutons connus

Les boutons qui ont une LED ont un nom (issu de la table de djcontrol) :

| Note | Bouton | Note | Bouton | Note | Bouton |
|---|---|---|---|---|---|
| 8 | Listen A | 16 | Listen B | 32 | Magic |
| 9 | CUE A | 17 | CUE B | 36 | Vinyl |
| 10 | Play A | 18 | Play B | 13 | Folders |
| 1 | Pitch Bend − A | 25 | Pitch Bend − B | 14 | Files |
| 2 | Pitch Bend + A | 26 | Pitch Bend + B | | |
| 37 | Sync A | 35 | Sync B | | |
| 39 | Pitch Reset A | 33 | Pitch Reset B | | |
| 38, 4, 5, 6 | N1 à N4 A | 34, 20, 21, 22 | N1 à N4 B | | |
| 40, 41, 42, 43 | N5 à N8 A | 44, 45, 46, 47 | N5 à N8 B | | |

Les autres bits des octets 0 à 5 (boutons sans LED, comme les touches de navigation) émettent
bien des notes, mais ne sont pas nommés ici : utilisez `--dump`.

## Application → console (LEDs)

Une LED porte **le même numéro de note** que son bouton. Une application qui renvoie
l'état d'un bouton sur la même note allume donc la bonne LED.

| Canal | Effet |
|---|---|
| 1 | LED **fixe** : Note On vélocité > 0 = allumée ; Note Off ou vélocité 0 = éteinte |
| 2 | LED **clignotante** : même principe |

Les autres canaux, les autres types de message et les notes sans LED sont ignorés.

## Ports virtuels

| Port | Sens | Identifiant unique |
|---|---|---|
| « Hercules MP3 e2 » (source) | console → application | `0x48455231` (« HER1 ») |
| « Hercules MP3 e2 » (destination) | application → console | `0x48455232` (« HER2 ») |

Le nom se change avec `--name`. Les identifiants sont fixes pour que l'application DJ
retrouve son mapping d'une session à l'autre.

## Mapping djay

[`Hercules MP3 e2.djayMidiMapping`](../Hercules%20MP3%20e2.djayMidiMapping) associe ces
notes et CC aux commandes de djay. Il utilise les mêmes numéros que ci-dessus (par
exemple `turntable1.playPause` ↔ note 10, soit Play A).
