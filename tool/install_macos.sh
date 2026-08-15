#!/bin/bash
# Builds Nova and installs it into /Applications so it opens with a normal
# double click.
#
# Why this exists: the app is not signed with an Apple Developer certificate,
# so macOS quarantines copied builds and insists on "right click -> Open".
# Clearing the quarantine flag removes that requirement.
set -euo pipefail

FLUTTER="${FLUTTER:-/opt/homebrew/bin/flutter}"
APP_NAME="Nova.app"
DEST="/Applications/Nova.app"

cd "$(dirname "$0")/.."

echo "==> Building release…"
"$FLUTTER" build macos --release

SRC="build/macos/Build/Products/Release/$APP_NAME"
[ -d "$SRC" ] || { echo "Build not found: $SRC"; exit 1; }

echo "==> Installing to $DEST…"
rm -rf "$DEST"
cp -R "$SRC" "$DEST"

# Clear quarantine and ad-hoc sign, otherwise Gatekeeper complains on every
# launch.
echo "==> Clearing quarantine…"
xattr -dr com.apple.quarantine "$DEST" 2>/dev/null || true
codesign --force --deep --sign - "$DEST" 2>/dev/null || true

echo
echo "Done. Nova is in Applications and opens with a double click."
open -R "$DEST"
