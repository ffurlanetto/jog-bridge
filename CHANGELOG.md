# Changelog

Format inspiré de [Keep a Changelog](https://keepachangelog.com/fr/1.1.0/) ;
versionnage [SemVer](https://semver.org/lang/fr/).

## [Non publié]

### Modifié
- **Le projet est renommé `jog-bridge`** (anciennement `hercules-bridge`) pour ne pas
  employer la marque Hercules comme nom ([ADR 0008](docs/adr/0008-nom-du-projet-et-marques-tierces.md)).
  Binaire, `.pkg`, plist, journal et label launchd changent : `local.jog-bridge`,
  `/usr/local/bin/jog-bridge`, `/tmp/jog-bridge.log`. Les ports MIDI (« Hercules MP3 e2 »)
  et leurs identifiants sont inchangés, les mappings existants restent valables.
  Une ancienne installation doit être désinstallée à la main (`launchctl bootout
  gui/$(id -u)/local.hercules-bridge`, puis suppression de l'ancien plist et binaire).

### Corrigé
- `postinstall` : un échec de `launchctl bootstrap` (par exemple erreur 5 quand l'élément
  n'est pas encore autorisé dans *Ouverture et extensions*) ne fait plus échouer
  l'installation du `.pkg`. Le chargement est réessayé puis suivi d'un `kickstart`.

### Ajouté
- Documentation : `docs/` (architecture, protocole USB, mapping MIDI, développement,
  dépannage, identité), ADR, `AGENTS.md`, `CLAUDE.md`, `CONTRIBUTING.md`, `SECURITY.md`,
  licence MIT.
- Identité visuelle (`assets/branding/` : logo, bannière, image sociale), mention de
  non-affiliation, gabarit et configuration des notes de release.

## [1.0.0]

- Passerelle USB bulk → CoreMIDI pour la Hercules DJ Control MP3 e2.
- Ports MIDI virtuels « Hercules MP3 e2 » (source et destination) à identifiants fixes.
- Pilotage des LEDs (fixes et clignotantes) depuis MIDI.
- Reconnexion automatique, LaunchAgent, installeur `.pkg` avec libusb lié statiquement.
- Mapping djay fourni.
