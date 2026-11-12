**English** · [Русский](#русский)

# BetterDiscord Installer 1.0.2 for macOS

Fixes BetterDiscord initialization on Discord **0.0.421 / 0.0.422** and makes
macOS 26 Full Disk Access handling explicit.

## What's fixed

- Uses the official **BetterDiscord Canary 1.14.6+** build. Stable 1.14.5
  loads but does not initialize on Discord 0.0.421+, so the BetterDiscord
  settings section was missing.
- Auto-repair refreshes the Canary asar every 6 hours and restarts Discord when
  it changes.
- Detects macOS 26 App Data protection and shows a **Full Disk Access** card
  with a button that opens the right system settings pane, instead of the
  misleading “core module not found” error.
- Plugins, themes and BetterDiscord settings are preserved.

## Install

1. Download `BetterDiscord-Mac-Installer-1.0.2.dmg`.
2. Drag **BetterDiscord Installer** to **Applications**.
3. macOS 26 blocks unnotarized DMGs from browsers. If the DMG is blocked, use
   the one-line installer:

```sh
curl -fsSL https://raw.githubusercontent.com/R3G1ST/betterdiscord-mac-installer/main/install.sh | bash
```

   or unblock the DMG:

```sh
xattr -d com.apple.quarantine ~/Downloads/BetterDiscord-Mac-Installer-1.0.2.dmg
open ~/Downloads/BetterDiscord-Mac-Installer-1.0.2.dmg
```

4. The installer needs **Full Disk Access** on macOS 26 (the Discord data
   folder is protected). Open the permission card in the app, add
   **BetterDiscord Installer**, enable it, then restart the app.
5. Click **Install BetterDiscord**. Discord restarts automatically.

No administrator password is required for the installation itself.

## Compatibility

- macOS 12 Monterey or newer
- Apple Silicon and Intel (universal)
- Discord Stable / PTB / Canary
- Discord 0.0.421+ uses BetterDiscord Canary

## Checksums (SHA-256)

```text
f27f1c2b0cacd365e1d9948327c33d40ab1474ce3fd17b87a3540e9e45ed7168  BetterDiscord-Mac-Installer-1.0.2.dmg
d797018b92e16616bee02b1222c4b45e43f1c0bb33d227c385a5a577bee0abf0  BetterDiscord-Mac-Installer-1.0.2.zip
```

## Credits

- [BetterDiscord](https://github.com/BetterDiscord/BetterDiscord) — Apache-2.0,
  © BetterDiscord Team (Zerebos and contributors).
- [BetterDiscord Installer](https://github.com/BetterDiscord/Installer) — MIT,
  © BetterDiscord Team. The injection approach is based on the v1.x installer.
- The community workaround from
  [Installer #424](https://github.com/BetterDiscord/Installer/issues/424).
- Discord is a trademark of Discord Inc.

This is an unofficial project and is not affiliated with Discord Inc. or the
BetterDiscord team. Using BetterDiscord may violate Discord's Terms of Service.

---

## Русский

**Исправлена инициализация BetterDiscord на Discord 0.0.421 / 0.0.422.**

- Установщик использует официальную **Canary-сборку BetterDiscord 1.14.6+**.
  Стабильная 1.14.5 на этих версиях Discord не показывает раздел BetterDiscord.
- Автовосстановление раз в 6 часов обновляет Canary-asar и перезапускает
  Discord при изменении.
- На macOS 26 приложение показывает карточку **Full Disk Access** и открывает
  нужный раздел настроек, вместо ложной ошибки «не найден core-модуль».
- Плагины, темы и настройки сохраняются.

### Установка

1. Скачай `BetterDiscord-Mac-Installer-1.0.2.dmg`.
2. Перетащи **BetterDiscord Installer** в **Applications**.
3. Если macOS 26 блокирует DMG, используй one-line installer:

```sh
curl -fsSL https://raw.githubusercontent.com/R3G1ST/betterdiscord-mac-installer/main/install.sh | bash
```

   или сними quarantine:

```sh
xattr -d com.apple.quarantine ~/Downloads/BetterDiscord-Mac-Installer-1.0.2.dmg
open ~/Downloads/BetterDiscord-Mac-Installer-1.0.2.dmg
```

4. На macOS 26 приложению нужен **Full Disk Access** (папка Discord защищена).
   В приложении нажми «Открыть настройки», добавь **BetterDiscord Installer**,
   включи его и перезапусти приложение.
5. Нажми **«Установить BetterDiscord»**. Discord перезапустится автоматически.

Права администратора для самой установки не нужны.
