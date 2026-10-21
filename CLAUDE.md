@AGENTS.md

## Spécifique à Claude Code

- Le projet est ouvert dans Xcode : préférer `BuildProject` et `XcodeRefreshCodeIssuesInFile`
  pour vérifier la compilation. En ligne de commande, `swift build -c release` suffit.
- Les tests matériels (`--list`, `--dump`) exigent la console branchée ; ne pas conclure
  qu'une modification USB/MIDI fonctionne sans les avoir exécutés ou sans le dire clairement.
- Demander avant d'installer le `.pkg`, de manipuler le LaunchAgent (`launchctl`), de
  committer ou de pousser.
- Se limiter à la tâche demandée : pas de refactorisation opportuniste, pas de fichiers de
  documentation supplémentaires hors de `docs/`.
