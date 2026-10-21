# 0004. Liaison statique de libusb

- Statut : Acceptée
- Date : 2026-10-21

## Contexte

Le `.pkg` doit s'installer sur un Mac qui n'a pas Homebrew. Un binaire lié dynamiquement à
`libusb-1.0.dylib` ne démarrerait pas sans la bibliothèque.

## Décision

`Package.swift` interroge `pkg-config` (`libdir` et `--cflags` de `libusb-1.0`) et lie
`libusb-1.0.a` directement via `unsafeFlags`. On ne passe volontairement **pas** `pkgConfig:`
à `.systemLibrary` : cela ferait réapparaître `-lusb-1.0` et la dépendance dynamique. Le
`PATH` donné à `pkg-config` inclut les chemins Homebrew, car Xcode évalue le manifeste sans
eux.

## Conséquences

- Le binaire est autonome ; Homebrew n'est requis que pour compiler.
- `unsafeFlags` interdit d'utiliser ce paquet comme dépendance d'un autre paquet SwiftPM.
- La compilation échoue sans `brew install libusb pkg-config`.
- **Licence** : libusb est sous **LGPL 2.1**. En distribuant un binaire qui l'embarque
  statiquement, il faut permettre à l'utilisateur de le relier avec une autre version de la
  bibliothèque. Le code source du projet et `scripts/build-pkg.sh` étant publics, chacun peut
  reconstruire le binaire avec sa propre libusb. À conserver si le dépôt change de licence
  ou de mode de distribution.

## Alternatives écartées

- **Liaison dynamique + dylib embarquée** : chemins à réécrire (`install_name_tool`), plus
  fragile.
- **Exiger Homebrew chez l'utilisateur** : contraire à l'objectif d'un installeur simple.
