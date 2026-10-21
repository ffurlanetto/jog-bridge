# 0004. Static linking of libusb

- Status: Accepted
- Date: 2026-10-21

## Context

The `.pkg` must install on a Mac that does not have Homebrew. A binary dynamically linked to
`libusb-1.0.dylib` would not start without the library.

## Decision

`Package.swift` queries `pkg-config` (`libdir` and `--cflags` of `libusb-1.0`) and links
`libusb-1.0.a` directly through `unsafeFlags`. We deliberately do **not** pass `pkgConfig:` to
`.systemLibrary`: that would bring back `-lusb-1.0` and the dynamic dependency. The `PATH`
given to `pkg-config` includes the Homebrew paths, because Xcode evaluates the manifest without
them.

## Consequences

- The binary is self-contained; Homebrew is only required to build.
- `unsafeFlags` forbids using this package as a dependency of another SwiftPM package.
- The build fails without `brew install libusb pkg-config`.
- **Licence**: libusb is under the **LGPL 2.1**. When distributing a binary that embeds it
  statically, the user must be able to relink it with another version of the library. The
  project's source code and `scripts/build-pkg.sh` being public, anyone can rebuild the binary
  with their own libusb. Keep this in mind if the repository changes licence or distribution
  mode.

## Alternatives considered

- **Dynamic linking + bundled dylib**: paths to rewrite (`install_name_tool`), more fragile.
- **Require Homebrew on the user's machine**: contrary to the goal of a simple installer.
