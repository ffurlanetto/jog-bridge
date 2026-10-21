#!/bin/bash
# Builds a self-contained .pkg: binary statically linked to libusb + LaunchAgent,
# installed and started automatically by the postinstall script.
set -euo pipefail

cd "$(dirname "$0")/.."

VERSION="${1:-1.0.0}"
IDENTIFIER="local.jog-bridge"
BUILD_DIR=".build/pkg"
ROOT_DIR="$BUILD_DIR/root"
SCRIPTS_DIR="$BUILD_DIR/scripts"
OUT_DIR="dist"
OUT_PKG="$OUT_DIR/jog-bridge-$VERSION.pkg"

echo "==> Building (release)"
swift build -c release

rm -rf "$BUILD_DIR"
mkdir -p "$ROOT_DIR/usr/local/bin" "$SCRIPTS_DIR" "$OUT_DIR"

cp .build/release/jog-bridge "$ROOT_DIR/usr/local/bin/jog-bridge"
chmod 755 "$ROOT_DIR/usr/local/bin/jog-bridge"

cp scripts/pkg/postinstall "$SCRIPTS_DIR/postinstall"
chmod 755 "$SCRIPTS_DIR/postinstall"
cp local.jog-bridge.plist "$SCRIPTS_DIR/local.jog-bridge.plist"

pkgbuild \
    --root "$ROOT_DIR" \
    --identifier "$IDENTIFIER" \
    --version "$VERSION" \
    --install-location / \
    --scripts "$SCRIPTS_DIR" \
    "$OUT_PKG"

echo "==> Package created: $OUT_PKG"
