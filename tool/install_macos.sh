#!/bin/bash
# Собирает Nova и ставит в /Applications так, чтобы приложение открывалось
# обычным двойным кликом.
#
# Зачем нужен скрипт: приложение не подписано сертификатом Apple Developer,
# поэтому macOS помечает скачанные/скопированные сборки карантином и требует
# «правый клик → Открыть». Снятие метки карантина убирает это требование.
set -euo pipefail

FLUTTER="${FLUTTER:-/opt/homebrew/bin/flutter}"
APP_NAME="net_pulse.app"
DEST="/Applications/Nova.app"

cd "$(dirname "$0")/.."

echo "==> Собираю релизную версию…"
"$FLUTTER" build macos --release

SRC="build/macos/Build/Products/Release/$APP_NAME"
[ -d "$SRC" ] || { echo "Сборка не найдена: $SRC"; exit 1; }

echo "==> Ставлю в $DEST…"
rm -rf "$DEST"
cp -R "$SRC" "$DEST"

# Снимаем карантин и подписываем «для себя» (ad-hoc), иначе Gatekeeper
# ругается при каждом запуске.
echo "==> Снимаю карантин…"
xattr -dr com.apple.quarantine "$DEST" 2>/dev/null || true
codesign --force --deep --sign - "$DEST" 2>/dev/null || true

echo
echo "Готово. Nova лежит в «Программах» и открывается двойным кликом."
open -R "$DEST"
