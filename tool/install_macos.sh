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

# The Firebase project and Google sign-in clients live in a git-ignored file;
# without it the app builds with the local demo account instead.
DEFINES=()
if [ -f nova_cloud.json ]; then
  DEFINES=(--dart-define-from-file=nova_cloud.json)
else
  echo "(no nova_cloud.json — building without Google sign-in and cloud history)"
fi

echo "==> Building release…"
# The odd expansion keeps macOS's bash 3.2 happy with an empty array under -u.
"$FLUTTER" build macos --release ${DEFINES[@]+"${DEFINES[@]}"}

SRC="build/macos/Build/Products/Release/$APP_NAME"
[ -d "$SRC" ] || { echo "Build not found: $SRC"; exit 1; }

echo "==> Installing to ${DEST}…"
rm -rf "$DEST"
cp -R "$SRC" "$DEST"

# Clear quarantine and ad-hoc sign, otherwise Gatekeeper complains on every
# launch. The widget extension inside keeps its own signature: macOS loads
# widgets only from a sandboxed extension, while the app itself runs outside
# the sandbox (macos/Runner/Release.entitlements says why).
echo "==> Clearing quarantine and signing…"
xattr -dr com.apple.quarantine "$DEST" 2>/dev/null || true
codesign --force --sign - --entitlements macos/Runner/Release.entitlements "$DEST"

# Fail loudly if the widgets would no longer load, rather than install that.
if ! codesign -d --entitlements - --xml "$DEST/Contents/PlugIns/NovaWidgets.appex" 2>/dev/null \
    | grep -Eq 'app-sandbox</key>[[:space:]]*<true/>'; then
  echo "The widget extension lost its sandbox — not installing a broken build." >&2
  exit 1
fi

echo
echo "Done. Nova is in Applications and opens with a double click."
open -R "$DEST"
