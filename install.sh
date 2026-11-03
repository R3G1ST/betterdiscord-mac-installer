#!/bin/bash
# BetterDiscord Installer — one-line installer for macOS.
# Usage:
#   curl -fsSL https://raw.githubusercontent.com/R3G1ST/betterdiscord-mac-installer/main/install.sh | bash
#   bash install.sh 1.0.0
set -euo pipefail

REPO="R3G1ST/betterdiscord-mac-installer"
VOL_NAME="BetterDiscord Installer"
APP_NAME="BetterDiscord Installer.app"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

echo "==> BetterDiscord Installer"

if [ -n "${1:-}" ]; then
  VERSION="${1#v}"
  URL="https://github.com/${REPO}/releases/download/v${VERSION}/BetterDiscord-Mac-Installer-${VERSION}.dmg"
else
  echo "==> Ищу последний релиз…"
  URL=$(curl -fsSL "https://api.github.com/repos/${REPO}/releases/latest" \
    | tr ',' '\n' \
    | grep '"browser_download_url"' \
    | grep '\.dmg"' \
    | head -1 \
    | cut -d'"' -f4)
fi

if [ -z "${URL:-}" ]; then
  echo "❌ Не удалось найти DMG в релизах."
  exit 1
fi

echo "==> Скачиваю: $URL"
curl -fL --retry 3 -o "$TMP/installer.dmg" "$URL"

echo "==> Монтирую образ…"
hdiutil attach "$TMP/installer.dmg" -noverify -noautoopen >/dev/null
SRC="/Volumes/${VOL_NAME}/${APP_NAME}"
DEST="/Applications/${APP_NAME}"

cleanup() {
  hdiutil detach "/Volumes/${VOL_NAME}" >/dev/null 2>&1 || true
}

if [ ! -d "$SRC" ]; then
  echo "❌ В образе не найден ${APP_NAME}"
  cleanup
  exit 1
fi

echo "==> Устанавливаю в /Applications…"
rm -rf "$DEST" 2>/dev/null || true
if ! ditto "$SRC" "$DEST" 2>/dev/null; then
  echo "==> /Applications недоступен, ставлю в ~/Applications…"
  mkdir -p "$HOME/Applications"
  DEST="$HOME/Applications/${APP_NAME}"
  rm -rf "$DEST" 2>/dev/null || true
  ditto "$SRC" "$DEST"
fi

cleanup

echo "==> Снимаю quarantine…"
xattr -dr com.apple.quarantine "$DEST" 2>/dev/null || true

echo "==> Запускаю…"
open "$DEST"
echo
echo "✅ Готово: $DEST"
echo "Открой Discord → Настройки (⌘,) → BetterDiscord."
