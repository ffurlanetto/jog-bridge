#!/bin/bash
# Regenerates assets/branding/AppIcon.icns from assets/branding/logo.svg.
# The .icns is committed; run this only after changing the logo.
set -euo pipefail

cd "$(dirname "$0")/.."

SRC="assets/branding/logo.svg"
OUT="assets/branding/AppIcon.icns"
SET="$(mktemp -d)/AppIcon.iconset"
mkdir -p "$SET"

render() { swift scripts/render-svg.swift "$SRC" "$SET/$2" "$1" "$1"; }

render 16   icon_16x16.png
render 32   icon_16x16@2x.png
render 32   icon_32x32.png
render 64   icon_32x32@2x.png
render 128  icon_128x128.png
render 256  icon_128x128@2x.png
render 256  icon_256x256.png
render 512  icon_256x256@2x.png
render 512  icon_512x512.png
render 1024 icon_512x512@2x.png

iconutil -c icns "$SET" -o "$OUT"
echo "==> $OUT written ($(wc -c < "$OUT" | tr -d ' ') bytes)"
