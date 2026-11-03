# Changelog

All notable changes to this project are documented here.
The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/).

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
