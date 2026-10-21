# Identité et usage de la marque

## Nom

**jog-bridge** (en minuscules, avec le trait d'union). Le nom évoque les jog wheels des
contrôleurs DJ et ne cite aucune marque : le projet n'est pas lié à un seul modèle. Voir
[ADR 0008](adr/0008-nom-du-projet-et-marques-tierces.md).

## Textes

| Usage | Texte |
|---|---|
| Tagline | USB-to-MIDI bridge for DJ controllers on macOS |
| Description GitHub | USB-to-MIDI bridge for DJ controllers on macOS. Exposes the Hercules DJ Control MP3 e2 as a CoreMIDI device, LEDs included. |
| Présentation (FR) | Passerelle USB → MIDI pour contrôleurs DJ sur macOS. |
| Topics GitHub | `dj`, `midi`, `coremidi`, `macos`, `usb`, `libusb`, `swift`, `dj-controller`, `hercules`, `launchagent` |

Les textes GitHub sont en anglais pour être trouvables ; le README et les docs restent en
français comme le code.

## Mention de non-affiliation

> jog-bridge est un projet indépendant, non affilié à Guillemot Corporation ni à Hercules,
> et ni approuvé ni sponsorisé par eux. Hercules est une marque de Guillemot Corporation.

À reprendre telle quelle dans le README, les notes de release et toute page de présentation.

## Règles d'usage des marques tierces

- Citer « Hercules DJ Control MP3 e2 » pour **décrire la compatibilité** (matériel supporté,
  nom des ports MIDI, fichier de mapping) : oui.
- Nommer le dépôt, le binaire, le paquet ou le logo d'après la marque : non.
- Reprendre un logo, une image ou une photo produit d'un tiers : non.
- Suggérer un partenariat ou une approbation : non.

Le topic `hercules` sert à la découverte (matériel supporté) ; il peut être retiré si
Guillemot en fait la demande. Ceci n'est pas un avis juridique.

## Éléments visuels

Tous dans `assets/branding/` ; ils sont originaux et publiés sous la licence du projet.

| Fichier | Usage |
|---|---|
| `logo.svg` / `logo.png` (512×512) | Icône du projet |
| `banner.svg` | En-tête du README |
| `social-preview.svg` / `social-preview.png` (1280×640) | Image de prévisualisation sociale GitHub |

Le logo représente un plateau de jog wheel (anneau cyan, repère magenta) traversé par une
arche de pont reliant deux points : USB d'un côté, MIDI de l'autre.

### Palette

| Rôle | Couleur |
|---|---|
| Fond | `#0B1220` (dégradé vers `#12223D`) |
| Plateau | `#111C33` |
| Accent principal | `#22D3EE` |
| Repère | `#F472B6` |
| Texte | `#F8FAFC`, secondaire `#CBD5E1` / `#94A3B8` |

Les SVG utilisent une pile de polices système ; le rendu du texte varie légèrement selon la
plateforme. Les PNG sont des rendus de référence.

### Régénérer les PNG

Après modification d'un SVG, rendre à la taille exacte avec un script AppKit (macOS) :

```sh
swift render.swift social-preview.svg social-preview.png 1280 640
swift render.swift logo.svg logo.png 512 512
```

où `render.swift` charge le SVG dans un `NSImage`, le dessine dans un `NSBitmapImageRep` de
la taille voulue et écrit le PNG. (`qlmanage -t` ne convient pas : il produit des vignettes
carrées recadrées.)

## Configurer le dépôt GitHub

Après création du dépôt :

```sh
gh repo edit --description "USB-to-MIDI bridge for DJ controllers on macOS. Exposes the Hercules DJ Control MP3 e2 as a CoreMIDI device, LEDs included." \
  --add-topic dj --add-topic midi --add-topic coremidi --add-topic macos --add-topic usb \
  --add-topic libusb --add-topic swift --add-topic dj-controller --add-topic hercules \
  --add-topic launchagent
```

L'image de prévisualisation sociale ne se définit pas par l'API : *Settings → General →
Social preview → Upload an image* avec `assets/branding/social-preview.png`.
