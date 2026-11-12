# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

- Case Portman UI SFX (credit: “Case Portman Audio”) and the Antoinemax Nature Sounds Pack (CC-BY 4.0). Played cues live under `assets/audio/sfx/`. Credits are on the site `/attributions` page and in Settings → About. Existing vine cues moved to `sfx/vines/`.
- Soft UI and vine feedback uses those packs: Case Portman menu open/close, click, confirm, and cancel; a quiet foliage rustle while a vine slides; the existing bloom, blocked, grace, and level-complete cues, with a short foliage swell on a clear. Ambient nature loops stay unused so they do not compete with the music.

### Changed

- Garden music and sound effects play through `flutter_soloud` (one mixer, voices over FFI). A tap no longer seeks a separate `just_audio` player. The music loop streams from disk. Effect clips stay in memory. Web stays on the main-thread SoLoud build so Firebase Auth popups keep working.
- Shipped audio is about 3.3 MB. Played UI cues are 16-bit 44.1 kHz mono WAV without the embedded cover image, and `background.mp3` is 128 kbps 44.1 kHz. Unused Case Portman clips and nature ambients, footsteps, and streams live in `apps/parable-bloom/audio-source/` and are not bundled.
- Gameplay SFX pack (`assets/audio/sfx/`) with slide/rustle, bloom, blocked, grace loss, level complete, and UI tap cues; separate SFX toggle alongside music.
- Visual refresh palette (parchment cream / forest green light; moonlit soil / moss dark) with Home botanical framing assets and garden ornaments.

### Fixed

- Flutter lint follows Flutter stable's Material split. App and test code import `package:material_ui/material_ui.dart`, and Cupertino localizations come from `package:cupertino_ui/cupertino_ui.dart`. Generated l10n still names the old delegates, so `l10n.yaml` ignores that deprecation. The app registers the new delegates itself.
- Android publish runs Gradle on JDK 21. AGP 9.3 release lint crashes on JDK 17 while analyzing `firebase_core` because `List.removeLast()` is missing. The app still compiles to JVM 17.
- Android release builds use Gradle 9.5.0 and Android Gradle Plugin 9.3.1. Flutter stable rejects Gradle below 9.3.1, and AGP 9.3 requires Gradle 9.5. Google services is 4.5.0 and the Crashlytics Gradle plugin is 3.0.8 so those plugins still apply.
- Pinch-to-zoom keeps the board point under the fingers in place. Moving the pinch also drags the board, including while zoom is at its limit.
- Android background music now starts while the garden is visible and stops when the app leaves the screen. The loop is no longer started by the first background transition, and a `play()` that never finishes can no longer block pause. Sound effects share a game audio session with the loop instead of exclusive media focus, and a cue load runs once even if preload and the first tap overlap.
- Background music keeps playing through an interrupted load, a web tap that lands while `background.mp3` is still loading, and transient `inactive` lifecycle states. Leaving the app pauses the loop instead of tearing the player down. Retriggered sound effects no longer cancel the cue that was about to play.
- Lesson 1 accepts a tap on any cell of its vine. The head highlight and `"Tap head to slide"` prompt stay as the guide.
- Finishing the tutorial unlocks the starter journal entry (`growth_seed_word` / Luke 8:11) even when an older registry used `lesson_1` or `lesson_10`, or only the module id `seed_starter` was stored. Remote module and theme registries that are not the current schema version are ignored.
- Leaving a level clears the game instance from the provider container captured while the screen was active, so unmount no longer throws `Using "ref" when a widget is about to or has been unmounted`.
- Cloud-sync timeouts and interrupted audio loads stay on warning breadcrumbs. Sentry issues are opened from `LoggerService.error`.
- Bundled `level_mappings` stay in effect when a cached or remote modules registry has a missing, empty, or partial map. Registry entries still override the same key.

### Changed

- Habit / retention loop: removed the once-per-day session-close / “come back tomorrow” overlay (and related Hive flags, level-complete habit hooks, and `habit_session_close_*` analytics). Kept next-day Home welcome-back via `habitSessionProvider.recordOpen()` + `habit_day_return`.
- Tutorial lesson boards densified to match main-game visual occupancy: longer vines / fuller grids (L1 remains a single vine; L2–L4 fully tiled; L5 ~88%). Guide overlay highlights read vine heads from layout data instead of hardcoded cells.
- Tutorial validation now hard-fails self-blocking vines (head exit ray intersects own body) via shared `ValidateStructural` / `ValidateSelfBlocking`; fixed Lesson 4 `vine_1` and Lesson 5 `vine_1` layouts that pointed into their own bodies.
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

- Soft habit / retention loop (MVP): Home welcome-back after a prior calendar day via local Hive visit timestamps (`habitSessionProvider`) and `habit_day_return` analytics. No session-close overlay, streaks, or push/local notifications.
- Play Store screenshot integration test expanded (`integration_test/app_screenshots_test.dart`): six scenes per theme (home, mid-puzzle gameplay, Level Complete, scripture journal, settings with Theme toggle, tutorial), captured in light + dark via `task release:android:screenshots`. Gameplay capture now polls for async level load and seeds ~1/3 cleared vines for a mid-puzzle look.
- **Withered vine state restored**: a blocked clear attempt now travels `|solver distance|` cells so the head visibly bumps the blocker and returns, then `markVineAttempted` withers the vine for the session — the strip modulates the real texture with warm bark brown (`VineMetrics.witheredColor`), foliage/caps go brown too, and the flat/simple stroke uses the brown (replacing the old dark-blue/white attempted colors). (Root cause: the rail run folded the solver's negative distance to 0, so the bump — and the attempted flag — never happened.)
- Disk hygiene: `task clean:all` reclaims build/cache disk across Flutter, Nx, Go (`.gotmp`/`.gocache`), Next.js, and the level-builder binary in one shot, printing free-space before/after.

### Fixed

- Home wooden cross: keep original silhouette AA on `cross_wood.png`, strip the white matte ground plate, recolor residual light/white edge RGB to nearest wood (alpha unchanged) so dark olive no longer shows a light fringe, and draw a soft `BlendMode.multiply` contact shadow in Flutter.
- Play Store screenshot capture loads the module registry and levels from bundled assets when `SCREENSHOT_MODE` disables Firebase, so `task release:android:screenshots` reaches the home screen instead of failing on a missing Firebase app. Frames are saved with `adb screencap` because `takeScreenshot()` hangs on the API 37 emulator.
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
