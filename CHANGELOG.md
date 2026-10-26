# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Changed
- Fine-grained Riverpod watches on heavy screens: `HomeScreen` selects tutorial/level/completed fields, `JournalScreen` selects unlocked scriptures, `TutorialGuideOverlay` selects only the vine states each lesson reads, `GameZoomControls` selects zoom bounds — unrelated provider writes no longer rebuild these widgets.
- Added `GameProgress.firstUncompletedInPlaylist(playlist, completedLevels)` static helper; `nextUncompletedLevel` delegates to it.
- **Vine skin redesign** (rail renderer): textured styles now sample the real
  trellis/ivy texture images with body-pinned cylindrical wrap UVs — natural
  wood grain and flowing vines instead of a repeating baked tile — instead of
  sampling the full-scene JPEGs with world-anchored UVs (the cause of the
  "random color band" look). UVs are cylindrical and body-pinned (`u` around
  the dowel, `v` along the vine arc), so the texture travels with the rigid
  vine; textured tube width is 15px (flat/simple stays 13px).

### Performance
- Cached the debug-mode cell coordinate `TextPainter` per cell in `CellComponent` (was a fresh `TextPainter` + layout per cell per frame).
- Vine rendering "Vine Rail" redesign behind `vineRenderModeProvider` (`rail` default, `legacy` for A/B): invariant baked track + scalar slide controller, sliding-window vertex strip (indexed triangle grid) for textured styles, and an anti-aliased stroked-path pass for the flat/simple style — draw calls independent of vine length, no per-frame blur, exit fade via per-vertex alpha (textured) or uniform alpha (simple). See `documentation/reference/vine-rendering.md`.

### Added
- **Withered vine state restored**: a blocked clear attempt now travels `|solver distance|` cells so the head visibly bumps the blocker and returns, then `markVineAttempted` withers the vine for the session — the strip modulates the real texture with warm bark brown (`VineMetrics.witheredColor`), foliage/caps go brown too, and the flat/simple stroke uses the brown (replacing the old dark-blue/white attempted colors). (Root cause: the rail run folded the solver's negative distance to 0, so the bump — and the attempted flag — never happened.)
- Disk hygiene: `task clean:all` reclaims build/cache disk across Flutter, Nx, Go (`.gotmp`/`.gocache`), Next.js, and the level-builder binary in one shot, printing free-space before/after.

### Fixed
- macOS & iOS builds: completed the Swift Package Manager migration on **both platforms** (all plugins resolve via SPM; `Podfile`/`Pods`/pod xcconfig includes removed). The old iOS `Podfile` hook forced deployment targets per pod (the project sets 16.0 natively); the old macOS hook forced `MACOSX_DEPLOYMENT_TARGET = 11.0`, rejected by modern Xcode. The `flutterfire upload-crashlytics-symbols` phase now locates the SwiftPM `firebase-ios-sdk` checkout that matches Flutter's build layout and skips gracefully when it is absent, instead of failing the build.








## [1.3.0] - 2026-02-04

### Added
- TODO: Document new features

### Changed
- TODO: Document changes

### Fixed
- TODO: Document bug fixes

## [1.2.0] - 2026-02-04

### Added
- TODO: Document new features

### Changed
- TODO: Document changes

### Fixed
- TODO: Document bug fixes

## [1.1.7] - 2026-01-08

### Added
- TODO: Document new features

### Changed
- TODO: Document changes

### Fixed
- TODO: Document bug fixes

## [1.1.6] - 2026-01-07

### Added
- TODO: Document new features

### Changed
- TODO: Document changes

### Fixed
- TODO: Document bug fixes

## [1.1.5] - 2026-01-06

### Added
- TODO: Document new features

### Changed
- TODO: Document changes

### Fixed
- TODO: Document bug fixes

## [1.1.4] - 2026-01-06

### Added
- TODO: Document new features

### Changed
- TODO: Document changes

### Fixed
- TODO: Document bug fixes

## [1.1.3] - 2026-01-06

### Added
- TODO: Document new features

### Changed
- TODO: Document changes

### Fixed
- TODO: Document bug fixes

## [1.1.2] - 2026-01-05

### Added
- TODO: Document new features

### Changed
- TODO: Document changes

### Fixed
- TODO: Document bug fixes

## [1.1.1] - 2026-01-05

### Added
- TODO: Document new features

### Changed
- TODO: Document changes

### Fixed
- TODO: Document bug fixes

## [1.1.0] - 2026-01-05

### Added
- TODO: Document new features

### Changed
- TODO: Document changes

### Fixed
- TODO: Document bug fixes

## [Unreleased]

## [1.3.2] - 2026-02-25

### Added

- Automated release pipeline with Bitwarden Secrets Manager integration
- Android and iOS build automation via GitHub Actions
- Fastlane integration for Google Play and TestFlight uploads
- Automated version bumping script (`scripts/bump_version.dart`)
- Automated changelog generation from git commits (`scripts/update_changelog.dart`)
- Comprehensive release process documentation in `docs/RELEASE_PROCESS.md`

### Changed

- Updated GitHub Actions release workflow to include Android and iOS builds
- Extended Taskfile.yaml with version management and Fastlane tasks

## [1.0.0] - 2025-01-03

### Added

- Initial release of Parable Bloom
- Core game mechanics with vine growth system
- Level progression system with grace mechanic
- Firebase integration for authentication and data persistence
- Hive local storage for offline-first gameplay
- Riverpod state management architecture
- Flame game engine integration
- Level validation and solver system
- Multiple game levels with varying difficulty

### Technical

- Flutter 3.24+ with Dart 3.0+
- Multi-platform support: Web, Android, iOS, Linux, Windows, macOS
- Firebase Hosting deployment pipeline
- Comprehensive test suite for game logic and animations
- Documentation for architecture, game design, and level system

[Unreleased]: https://github.com/eng618/parable-bloom/compare/v1.3.2...HEAD
[1.3.2]: https://github.com/eng618/parable-bloom/releases/tag/v1.3.2
[1.0.0]: https://github.com/eng618/parable-bloom/releases/tag/v1.0.0
