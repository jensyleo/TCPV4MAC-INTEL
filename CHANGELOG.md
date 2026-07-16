# Changelog

All notable changes to **TCPV4MAC-INTEL**. Format based on
[Keep a Changelog](https://keepachangelog.com/); this project follows
[Semantic Versioning](https://semver.org/).

This repository is the Intel (x86_64) compatible fork of
[TCPV4MAC](https://github.com/jensyleo/TCPV4MAC). Entries below either
originate here or are ported from upstream, adapted where this fork's
architecture differs.

## [Unreleased]

### Added — 2026-07-16 · External dashboard card
- Added an **External** card to the dashboard (last card, right beside
  **Loopback**), mirroring the IPv4/IPv6 and TCP/UDP two-way switch cards.
  (Ported from upstream.)

### Fixed — 2026-07-16 · README corrections vs actual code
- Fixed highlight colors: "amber" not "yellow" (matches `RowColor.swift`), and
  documented the persistent unsigned/listening/loopback/root color cues.
- Fixed the export claim: no TXT export exists; JSON is clipboard-copy only,
  not a file export — only CSV is an actual file export.
- Fixed the roadmap: kill process is already shipped (Phase 1), not a
  Phase 4 item; only closing an individual connection remains a future item.
- Unlike upstream, the Architecture section still lists Combine: this fork
  genuinely uses `ObservableObject`/Combine instead of `@Observable`, as part
  of the macOS 13 / Intel compatibility changes below.

## [1.1.0] — 2026-07-14

### Added
- Intel (x86_64) Mac compatibility, as a universal binary alongside Apple
  Silicon (arm64):
  - Lowered `MACOSX_DEPLOYMENT_TARGET` from 26.0 to 13.0 (macOS 26 dropped
    Intel support).
  - Lowered `swift-tools-version` from 6.0 to 5.9 and `SWIFT_VERSION` from
    6.0 to 5.0 (Swift 6 requires Xcode 16 / macOS 14+).
  - Replaced `@Observable` (macOS 14+) with `ObservableObject`/`@Published`
    in `ConnectionsViewModel`, updating all consumers to
    `@ObservedObject`/`@StateObject`.
  - Replaced `.inspector()` (macOS 14+) with a manual `HStack` side panel in
    `ContentView`.
  - Added `CompatUnavailableView` as a macOS 13-compatible replacement for
    `ContentUnavailableView` (macOS 14+).

### Fixed
- Two concurrency diagnostics surfaced under Swift 5 language mode (missing
  `await` on a `@MainActor` call, actor-isolated dictionary mutation).

## [1.0.0] — 2026-07-02

First release. A complete, lightweight macOS TCP/UDP connection inspector
(Sysinternals-TCPView-inspired): live table, filters, search, inspector, color
rules, context menu, CSV/JSON copy & export, admin mode, settings, uninstaller.
