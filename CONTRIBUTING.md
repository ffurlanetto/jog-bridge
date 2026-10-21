# Contribuer

Merci de votre intérêt ! Les contributions sont bienvenues : corrections, support d'autres
modèles Hercules, documentation du protocole, tests.

## Mise en route

```sh
xcode-select --install
brew install libusb pkg-config
swift build -c release
```

Voir [docs/development.md](docs/development.md) pour le détail (exécution, `--dump`,
packaging).

## Avant d'ouvrir une pull request

- `swift build -c release` passe sans avertissement nouveau.
- Si le comportement USB ou MIDI change, vous l'avez testé avec une console réelle et vous
  indiquez le modèle (`--list`) dans la description.
- La documentation est à jour : `docs/usb-protocol.md`, `docs/midi-mapping.md`, `README.md`.
- Une décision structurante (liaison, protocole, distribution…) s'accompagne d'un ADR dans
  [`docs/adr/`](docs/adr/README.md).
- Les changements visibles par l'utilisateur sont notés dans [`CHANGELOG.md`](CHANGELOG.md).

## Style

- Swift 5.9, indentation 4 espaces, PascalCase pour les types, camelCase sinon.
- Commentaires et messages de log en français, orientés vers le *pourquoi*.
- Pas de dépendance Swift externe.

## Contraintes de compatibilité

Ne changez pas sans en discuter :

- les numéros de notes et de CC (`octet × 8 + bit`, CC = index d'octet) : ils définissent
  les mappings des utilisateurs ;
- les identifiants uniques des ports MIDI virtuels ;
- l'identifiant du LaunchAgent `local.jog-bridge`.

## Signaler un bug ou un nouveau matériel

Utilisez les modèles d'issue. Joignez toujours la sortie de :

```sh
jog-bridge --list
jog-bridge --dump     # en reproduisant le problème
tail -50 /tmp/jog-bridge.log
```

## Licence

En contribuant, vous acceptez que votre code soit publié sous licence [MIT](LICENSE).
