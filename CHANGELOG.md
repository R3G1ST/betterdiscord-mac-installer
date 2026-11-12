# Changelog

All notable changes to this project are documented here.
The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/).

## [1.0.2] — 2026-11-12

### Fixed

- Use the official BetterDiscord **Canary 1.14.6+** build. Stable 1.14.5 does not
  initialize on Discord 0.0.421/0.0.422 (settings section missing).
- Auto-repair refreshes the Canary asar every 6 hours and restarts Discord when
  it changes.
- Detect macOS 26 App Data protection and show a **Full Disk Access** guidance
  card instead of the misleading "core module not found" error.
- Reinstalling keeps plugins, themes and BetterDiscord settings.

## [1.0.1] — 2026-11-11

### Fixed

- Full Disk Access detection and an in-app permission card for macOS 26.
- Auto-repair now runs through the signed app instead of a shell script, so one
  Full Disk Access grant covers future Discord updates.

## [1.0.0] — 2026-11-03

### Added

- Native SwiftUI installer for BetterDiscord on macOS.
- One-click install, reinstall and remove flows.
- Automatic injection through Discord's per-user `discord_desktop_core` module,
  without modifying `/Applications/Discord.app`.
- LaunchAgent-based auto-repair after Discord updates (every 2 minutes).
- Support for Discord Stable, PTB and Canary.
- Animated interface: gradients, glows, hover/press effects, smooth window
  resizing, status transitions and success animation.
- Universal binary (Apple Silicon + Intel), macOS 12+.
- Styled DMG with custom background and volume icon.
- English and Russian documentation.
