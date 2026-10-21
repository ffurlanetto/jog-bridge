# Security policy

## Reporting a vulnerability

Please **do not open a public issue** for a security flaw. Use GitHub's private reporting
(*Security → Report a vulnerability*) on this repository.

## Scope

`jog-bridge` runs with the user's rights (LaunchAgent, no root daemon) and accesses one specific
USB device (VID `06F8`). It opens no network port.

Sensitive points to know about:

- the `.pkg` is **neither signed nor notarised**; check its origin (build it yourself with
  `scripts/build-pkg.sh`);
- the `postinstall` script runs as root during installation and writes into the logged-in
  user's `LaunchAgents` folder;
- the log is written to `/tmp/jog-bridge.log`, readable by the other users of the machine; it
  only contains USB/MIDI events.
