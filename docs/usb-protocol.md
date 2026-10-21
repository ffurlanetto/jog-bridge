# Protocole USB de la Hercules DJ Control MP3 e2

Établi par rétro-ingénierie ; la séquence d'initialisation et la table des LEDs
proviennent de [foomatic/djcontrol](https://github.com/foomatic/djcontrol). Ce document
décrit ce que le code de ce dépôt fait réellement.

## Identification

| Champ | Valeur |
|---|---|
| Vendor ID | `0x06F8` (Hercules) |
| Product ID | `0xB105` (DJ Control MP3 e2) |
| Classe des interfaces | `0xFF` (vendor specific) : aucun pilote macOS générique |

Exemple de sortie de `jog-bridge --list` :

```
Périphérique 06F8:B105 (bus 0, adresse 3)
  Interface 0 alt 0 — classe 0xFF
    Endpoint 0x81 IN  bulk (max 64 octets)
  Interface 1 alt 0 — classe 0xFF
    Endpoint 0x82 IN  bulk (max 12 octets)
    Endpoint 0x03 OUT bulk (max 12 octets)
```

Le code réclame l'**interface 0** par défaut et lit son endpoint IN (`0x81`). L'interface 1
est décrite avec des tailles de paquet invalides et macOS n'en crée pas les pipes ; elle
n'est pas utilisée pour les données.

## Initialisation

Après `libusb_claim_interface`, la console reçoit cette séquence (`HerculesDevice.initialize`),
dont les réponses sont ignorées :

1. Requêtes de contrôle IN (`bmRequestType 0xC0`, 2 octets) : `0x2C` / `wValue 0`, puis
   `0x29` avec `wValue` = `0x0300`, `0x0400`, `0x0500`, `0x0600`.
2. `0x2C` deux fois, puis `0x29` avec `0x0300`, `0x0400`, `0x0500`, `0x0600`, `0x0200`.
3. `CLEAR_FEATURE(ENDPOINT_HALT)` sur l'endpoint `0x82`.
4. Requête de contrôle OUT (`bmRequestType 0x40`) `0x27`, sans données.

Chaque transfert a un timeout de 500 ms. Le rôle exact de chaque requête n'est pas
documenté ; la séquence est reprise telle quelle de djcontrol.

## Trames d'entrée

La console envoie en continu des trames de **38 octets** sur l'endpoint IN. Toute trame
d'une autre longueur est ignorée (et journalisée avec `--dump`).

| Octets | Contenu |
|---|---|
| 0…5 | Boutons, 1 bit par bouton (1 = appuyé) |
| 6…18 | Potentiomètres, faders et encodeurs, valeur sur 8 bits |
| 20, 36 | Recopies d'état liées à l'octet 3 (informatif, non converti en MIDI) |
| 37 | Compteur de séquence (ignoré) |

Les octets 19 et 21…35 ne sont pas interprétés. Le décodage en MIDI est décrit dans
[midi-mapping.md](midi-mapping.md).

## LEDs

Les LEDs se pilotent par **transferts de contrôle sur l'endpoint 0**, pas par les endpoints
bulk. La console a 5 blocs de 16 bits :

| Élément | Valeur |
|---|---|
| `bmRequestType` | `0x40` (OUT, vendor, device) |
| `bRequest` | `0x2D + n`, avec `n` = index du bloc (0…4) |
| `wValue` | le bloc de 16 bits |
| Données | aucune |
| Timeout | 100 ms |

Les blocs 0 à 2 portent les LEDs **fixes**, les blocs 2 à 4 les LEDs **clignotantes**. Le
bloc 2 porte les deux : bits 0…6 clignotants, bits 8…15 fixes. À chaque changement, les
5 blocs sont réenvoyés ; ils le sont aussi après une reconnexion. La correspondance
bouton → bloc/bit est dans `Sources/jog-bridge/LEDs.swift`.

## Déconnexion

Une erreur de lecture autre que timeout, overflow ou interruption est traitée comme une
déconnexion : l'interface est libérée et la boucle réessaie d'ouvrir la console toutes les
2 s.
