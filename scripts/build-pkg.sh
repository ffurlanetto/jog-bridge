#!/bin/bash
# Builds a self-contained .pkg: an app bundle + LaunchAgent, installed and started automatically
# by the postinstall script.
#
# The bundle holds two executables (ADR 0012): the status panel (jog-bridge-panel, the bundle's
# main executable, opened when the user clicks the app) and the daemon (jog-bridge, statically
# linked to libusb, run by the LaunchAgent). It also gives System Settings → Login Items a proper
# name and icon (ADR 0011); there is no loose binary in /usr/local/bin.
set -euo pipefail

cd "$(dirname "$0")/.."

VERSION="${1:-1.0.0}"
IDENTIFIER="local.jog-bridge"
BUNDLE_ID="io.github.ffurlanetto.jog-bridge"   # must match local.jog-bridge.plist
APP_NAME="Jog Bridge"
BUILD_DIR=".build/pkg"
ROOT_DIR="$BUILD_DIR/root"
SCRIPTS_DIR="$BUILD_DIR/scripts"
OUT_DIR="dist"
OUT_PKG="$OUT_DIR/jog-bridge-$VERSION.pkg"
APP_DIR="$ROOT_DIR/Applications/Jog Bridge.app"

echo "==> Building (release)"
swift build -c release

rm -rf "$BUILD_DIR"
mkdir -p "$APP_DIR/Contents/MacOS" "$APP_DIR/Contents/Resources" "$SCRIPTS_DIR" "$OUT_DIR"

cp .build/release/jog-bridge "$APP_DIR/Contents/MacOS/jog-bridge"
cp .build/release/jog-bridge-panel "$APP_DIR/Contents/MacOS/jog-bridge-panel"
chmod 755 "$APP_DIR/Contents/MacOS/jog-bridge" "$APP_DIR/Contents/MacOS/jog-bridge-panel"
cp assets/branding/AppIcon.icns "$APP_DIR/Contents/Resources/AppIcon.icns"

cat > "$APP_DIR/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleIdentifier</key>
    <string>$BUNDLE_ID</string>
    <key>CFBundleName</key>
    <string>$APP_NAME</string>
    <key>CFBundleDisplayName</key>
    <string>$APP_NAME</string>
    <!-- The panel is the main executable; the daemon is started by launchd, not by a click. -->
    <key>CFBundleExecutable</key>
    <string>jog-bridge-panel</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>$VERSION</string>
    <key>CFBundleVersion</key>
    <string>$VERSION</string>
    <key>LSMinimumSystemVersion</key>
    <string>13.0</string>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>LSApplicationCategoryType</key>
    <string>public.app-category.music</string>
</dict>
</plist>
PLIST
plutil -lint "$APP_DIR/Contents/Info.plist" >/dev/null

# Ad-hoc signatures: each executable, then the bundle (sealing the Info.plist and the icon). They
# carry no Team ID (there is no Developer ID, ADR 0006), so this is integrity, not identity.
codesign --force --sign - "$APP_DIR/Contents/MacOS/jog-bridge"
codesign --force --sign - "$APP_DIR/Contents/MacOS/jog-bridge-panel"
codesign --force --sign - "$APP_DIR"

cp scripts/pkg/postinstall "$SCRIPTS_DIR/postinstall"
chmod 755 "$SCRIPTS_DIR/postinstall"
cp local.jog-bridge.plist "$SCRIPTS_DIR/local.jog-bridge.plist"

# pkgbuild treats the .app as a component and, by default, as *relocatable*: the installer
# could then update another copy of the same bundle id found elsewhere on the disk (a build
# folder, for instance) instead of installing here. Pin the location, and always overwrite
# (no version check) so a test build can replace any other.
COMPONENTS="$BUILD_DIR/components.plist"
pkgbuild --analyze --root "$ROOT_DIR" "$COMPONENTS" >/dev/null
# `--analyze` omits a key on some macOS versions: set it if present, add it otherwise.
for key in BundleIsRelocatable BundleIsVersionChecked; do
    /usr/libexec/PlistBuddy -c "Set :0:$key false" "$COMPONENTS" 2>/dev/null \
        || /usr/libexec/PlistBuddy -c "Add :0:$key bool false" "$COMPONENTS"
done

pkgbuild \
    --root "$ROOT_DIR" \
    --component-plist "$COMPONENTS" \
    --identifier "$IDENTIFIER" \
    --version "$VERSION" \
    --install-location / \
    --scripts "$SCRIPTS_DIR" \
    "$OUT_PKG"

echo "==> Package created: $OUT_PKG"
