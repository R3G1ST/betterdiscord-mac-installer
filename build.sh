#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"

APP_NAME="BetterDiscord Installer"
APP="dist/${APP_NAME}.app"

rm -rf build dist icon1024.png AppIcon.iconset AppIcon.icns
mkdir -p build dist

echo "==> Сборка arm64"
swiftc -O -swift-version 5 -target arm64-apple-macos12.0 -framework Cocoa \
  -o build/bd-arm64 main.swift

echo "==> Сборка x86_64"
swiftc -O -swift-version 5 -target x86_64-apple-macos12.0 -framework Cocoa \
  -o build/bd-x86_64 main.swift

echo "==> Universal binary"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
lipo -create build/bd-arm64 build/bd-x86_64 \
  -output "$APP/Contents/MacOS/BetterDiscordInstaller"

echo "==> Иконка"
swiftc -O -framework Cocoa -o build/makeicon makeicon.swift
./build/makeicon >/dev/null

mkdir -p AppIcon.iconset
sips -z 16 16     icon1024.png --out AppIcon.iconset/icon_16x16.png      >/dev/null
sips -z 32 32     icon1024.png --out AppIcon.iconset/icon_16x16@2x.png   >/dev/null
sips -z 32 32     icon1024.png --out AppIcon.iconset/icon_32x32.png      >/dev/null
sips -z 64 64     icon1024.png --out AppIcon.iconset/icon_32x32@2x.png   >/dev/null
sips -z 128 128   icon1024.png --out AppIcon.iconset/icon_128x128.png    >/dev/null
sips -z 256 256   icon1024.png --out AppIcon.iconset/icon_128x128@2x.png >/dev/null
sips -z 256 256   icon1024.png --out AppIcon.iconset/icon_256x256.png    >/dev/null
sips -z 512 512   icon1024.png --out AppIcon.iconset/icon_256x256@2x.png >/dev/null
sips -z 512 512   icon1024.png --out AppIcon.iconset/icon_512x512.png    >/dev/null
cp icon1024.png   AppIcon.iconset/icon_512x512@2x.png

iconutil -c icns AppIcon.iconset -o AppIcon.icns
cp AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"

echo "==> Info.plist"
cp Info.plist "$APP/Contents/Info.plist"
printf 'APPL????' > "$APP/Contents/PkgInfo"

echo "==> Подпись (ad-hoc)"
codesign --force --deep --sign - --identifier app.betterdiscord.installer.local "$APP"
codesign --verify --deep --strict "$APP"

echo
echo "Готово: $APP"
echo "Проверка CLI:"
"$APP/Contents/MacOS/BetterDiscordInstaller" --cli-status
