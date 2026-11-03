**English** · [Русский](#русский)

# BetterDiscord Installer 1.0.0 for macOS

A native, animated installer and self-healing auto-repair agent for
[BetterDiscord](https://betterdiscord.app) on macOS.

## macOS 26 Tahoe: DMG blocked?

macOS 26 blocks unnotarized DMGs downloaded through a browser, and
right-click → Open no longer bypasses it. Use the one-line installer:

```sh
curl -fsSL https://raw.githubusercontent.com/R3G1ST/betterdiscord-mac-installer/main/install.sh | bash
```

Or unblock the DMG manually:

```sh
xattr -d com.apple.quarantine ~/Downloads/BetterDiscord-Mac-Installer-1.0.0.dmg
open ~/Downloads/BetterDiscord-Mac-Installer-1.0.0.dmg
# after dragging to Applications:
xattr -dr com.apple.quarantine "/Applications/BetterDiscord Installer.app"
```

This is a limitation of unnotarized software on macOS 26 — Apple notarization
requires a paid Developer ID. On macOS 15 and earlier, right-click → Open works.

## Install

1. Download `BetterDiscord-Mac-Installer-1.0.0.dmg`.
2. Open the DMG and drag **BetterDiscord Installer** to **Applications**.
3. First launch: **right-click → Open → Open** (the app is ad-hoc signed but not
   notarized, so macOS asks once).
4. Click **Install BetterDiscord**. Discord restarts automatically.
5. Open Discord → **User Settings (⌘,)** → **BetterDiscord**.

No administrator password is required. The installer never modifies
`/Applications/Discord.app`.

## Highlights

- Native SwiftUI UI with animated gradients, glow, hover/press effects and
  smooth window resizing.
- One-click install / reinstall / remove.
- Auto-repair LaunchAgent checks every 2 minutes and re-applies the injection
  after Discord updates — even if the app is closed or deleted.
- Supports Discord Stable, PTB and Canary.
- Keeps plugins, themes and settings.
- Universal binary: Apple Silicon + Intel, macOS 12 Monterey or newer.
- Open source, MIT, no telemetry, no bundled third-party code.

## Compatibility

- macOS 12 Monterey or newer
- Apple Silicon and Intel
- Discord Stable / PTB / Canary
- Discord installed in `/Applications` or `~/Applications`

## Checksums (SHA-256)

```text
d64beed321b5c63b2f3a819c0785d3b218b29300cea47a010e88c88bf4f57722  BetterDiscord-Mac-Installer-1.0.0.dmg
d09f960c9fcaa6e6acff3356222ce26e39764b0266443c6e402f3b0e284847f6  BetterDiscord-Mac-Installer-1.0.0.zip
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

1. Скачай `BetterDiscord-Mac-Installer-1.0.0.dmg`.
2. Открой DMG и перетащи **BetterDiscord Installer** в **Applications**.
3. Первый запуск: **правый клик → Открыть → Открыть** (приложение подписано
   ad-hoc и не нотаризовано, macOS спросит один раз).
4. Нажми **«Установить BetterDiscord»** — Discord перезапустится.
5. Discord → **Настройки (⌘,)** → **BetterDiscord**.

Права администратора не нужны, `/Applications/Discord.app` не изменяется.
Автовосстановление включено по умолчанию и переживает обновления Discord.
