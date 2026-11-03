#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"

VERSION="${1:-1.0.0}"
APP="dist/BetterDiscord Installer.app"
VOL_NAME="BetterDiscord Installer"
OUT="dist/BetterDiscord-Mac-Installer-${VERSION}.dmg"
STAGE="build/dmg-stage"
RW="build/rw.dmg"
BG="docs/dmg-background.png"

if [ ! -d "$APP" ]; then
  echo "==> Приложение не найдено, собираю"
  ./build.sh
fi

echo "==> Фон DMG"
mkdir -p build docs
swiftc -O -framework Cocoa -o build/makebg dmg-background.swift
./build/makebg "$BG"

echo "==> Подготовка содержимого"
rm -rf "$STAGE" "$RW" "$OUT"
mkdir -p "$STAGE/.background"
ditto "$APP" "$STAGE/BetterDiscord Installer.app"
ln -s /Applications "$STAGE/Applications"
cp "$BG" "$STAGE/.background/background.png"
if [ -f "docs/dmg-background@2x.png" ]; then
  cp "docs/dmg-background@2x.png" "$STAGE/.background/background@2x.png"
fi
# Готовая раскладка Finder (позиции иконок, фон, размер окна) — нужна для CI,
# где нет графической сессии. Локально AppleScript ниже обновляет её при желании.
if [ -f "dmg/layout.DS_Store" ]; then
  cp "dmg/layout.DS_Store" "$STAGE/.DS_Store"
fi

hdiutil detach "/Volumes/$VOL_NAME" -force >/dev/null 2>&1 || true

echo "==> Создание образа"
hdiutil create -volname "$VOL_NAME" -srcfolder "$STAGE" -ov -format UDRW "$RW" >/dev/null
hdiutil attach "$RW" -readwrite -noverify -noautoopen >/dev/null
VOL="/Volumes/$VOL_NAME"

if [ -f "AppIcon.icns" ]; then
  cp "AppIcon.icns" "$VOL/.VolumeIcon.icns"
  SetFile -a C "$VOL"
fi

if [ "${CI:-}" = "1" ]; then
  echo "==> CI: пропускаю оформление Finder (нет графической сессии)"
else
echo "==> Оформление окна Finder"
set +e
osascript <<'APPLESCRIPT'
with timeout of 60 seconds
    tell application "Finder"
        tell disk "BetterDiscord Installer"
            open
            set current view of container window to icon view
            set toolbar visible of container window to false
            set statusbar visible of container window to false
            set the bounds of container window to {200, 120, 860, 544}
            set viewOptions to the icon view options of container window
            set arrangement of viewOptions to not arranged
            set icon size of viewOptions to 128
            set text size of viewOptions to 13
            set background picture of viewOptions to file ".background:background.png"
            set position of item "BetterDiscord Installer.app" of container window to {170, 180}
            set position of item "Applications" of container window to {490, 180}
            update without registering applications
            delay 2
            close
        end tell
    end tell
end timeout
APPLESCRIPT
LAYOUT=$?
set -e

if [ "$LAYOUT" -ne 0 ]; then
  echo "⚠️  Раскладка Finder не применилась (нет разрешения Automation). Образ создан без оформления."
fi
fi

sync
hdiutil detach "$VOL" >/dev/null
hdiutil convert "$RW" -format UDZO -imagekey zlib-level=9 -o "$OUT" >/dev/null
rm -f "$RW"

# Ad-hoc подпись самого образа (не заменяет нотаризацию, но фиксирует целостность)
codesign --force --sign - "$OUT" >/dev/null 2>&1 || true

echo
echo "Готово: $OUT"
ls -lh "$OUT"
