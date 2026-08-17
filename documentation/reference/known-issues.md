# 🐛 Bug & Issue Tracker

This document serves as the **running, actionable list of known bugs, technical debt, and issues** across **Parable Bloom**. As bugs are investigated, addressed, and verified, check them off (`- [x]`) and record resolution notes or commit hashes.

---

## 📊 Summary Dashboard

| Severity                     | Open   | Resolved | Total  |
| :--------------------------- | :----- | :------- | :----- |
| 🔴 **Critical (Blockers)**   | 4      | 0        | 4      |
| 🟠 **High Priority**         | 9      | 0        | 9      |
| 🟡 **Medium Priority**       | 14     | 0        | 14     |
| 🟢 **Low Priority / Polish** | 10     | 0        | 10     |
| **Total**                    | **37** | **0**    | **37** |

---

## 🔴 Critical Issues (Release Blockers)

Must be resolved prior to public release or store submission.

- [ ] **BUG-C01**: `[Website / Android]` **Inconsistent Google Play Application ID**
  - **Description**: Google Play links reference mismatched IDs (`com.eng618.parablebloom`, `com.garciaericn.parablebloom`, and actual `com.garciaericn.parable_bloom`).
  - **Affected Files**: [`apps/parable-bloom-site/app/page.tsx`](../../apps/parable-bloom-site/app/page.tsx), [`apps/parable-bloom-site/app/about/page.tsx`](../../apps/parable-bloom-site/app/about/page.tsx), [`apps/parable-bloom/android/app/build.gradle.kts`](../../apps/parable-bloom/android/app/build.gradle.kts)
  - **Resolution Criteria**: Unify to `com.garciaericn.parable_bloom` across all website links, fastlane, and documentation.

- [ ] **BUG-C02**: `[Website / iOS]` **App Store URL uses Placeholder ID**
  - **Description**: The site links to dummy App Store ID `id1234567890`.
  - **Affected Files**: [`apps/parable-bloom-site/app/page.tsx`](../../apps/parable-bloom-site/app/page.tsx), [`apps/parable-bloom-site/app/about/page.tsx`](../../apps/parable-bloom-site/app/about/page.tsx)
  - **Resolution Criteria**: Update with real App Store ID or render "Coming Soon" badge until live.

- [ ] **BUG-C03**: `[Website / Marketing]` **Missing OpenGraph Social Sharing Image**
  - **Description**: Missing `og-image.png` causing link previews on social platforms to be blank.
  - **Affected Files**: [`apps/parable-bloom-site/app/layout.tsx`](../../apps/parable-bloom-site/app/layout.tsx), [`apps/parable-bloom-site/public/`](../../apps/parable-bloom-site/public/)
  - **Resolution Criteria**: Add branded 1200×630px `og-image.png` and configure metadata.

- [ ] **BUG-C04**: `[Assets / Legal]` **Incomplete Asset Attributions**
  - **Description**: Only 1 audio file was attributed; remaining sounds, font licenses (Fraunces, Alegreya Sans), and graphics need complete attribution.
  - **Affected Files**: [`documentation/reference/attributions.md`](attributions.md)
  - **Resolution Criteria**: Complete audit of all audio, fonts, textures, and devotions.

---

## 🟠 High Priority Issues

- [ ] **BUG-H01**: `[Flutter Web]` **Web Manifest Uses Template Branding**
  - **Description**: `apps/parable-bloom/web/manifest.json` contains generic Flutter description and title.
  - **Affected Files**: `apps/parable-bloom/web/manifest.json`
  - **Resolution Criteria**: Update name to "Parable Bloom", theme colors, and description.

- [ ] **BUG-H02**: `[Repository / Hygiene]` **Tracked Log Files in Repository**
  - **Description**: Root directory contains build, lint, and analyze log files.
  - **Affected Files**: `.gitignore`, `*.log`
  - **Resolution Criteria**: Add `*.log` to `.gitignore` and untrack root log dumps.

- [ ] **BUG-H03**: `[Android]` **Android Version Code / Version Name Hardcoding**
  - **Description**: Verify version syncing between `pubspec.yaml` and `app/build.gradle.kts`.
  - **Affected Files**: `apps/parable-bloom/android/app/build.gradle.kts`
  - **Resolution Criteria**: Ensure `flutterVersionCode` and `flutterVersionName` are derived properly during release task.

- [ ] **BUG-H04**: `[Store / Marketing]` **Store Listing Screenshots Not Generated**
  - **Description**: Required store screenshots for 6.7" iPhone, 12.9" iPad, and Android devices are missing.
  - **Affected Files**: [`documentation/how-to/app-store-listings/visual-assets.md`](../how-to/app-store-listings/visual-assets.md)
  - **Resolution Criteria**: Execute automated screenshot test and export framed images.

- [ ] **BUG-H05**: `[Legal / Compliance]` **Privacy Policy & Terms Dates Review**
  - **Description**: Review legal dates and verify that account deletion / data collection disclosures are accurate.
  - **Affected Files**: `apps/parable-bloom-site/app/privacy/page.tsx`, `apps/parable-bloom-site/app/terms/page.tsx`
  - **Resolution Criteria**: Update dates and match disclosures to active features.

- [ ] **BUG-H06**: `[Testing / QA]` **Zero Widget Tests for Screen Layer**
  - **Description**: Screen-level rendering and user interaction flows need automated widget test coverage.
  - **Affected Files**: `apps/parable-bloom/test/`
  - **Resolution Criteria**: Add widget tests for GameScreen, JournalScreen, and SettingsScreen.

- [ ] **BUG-H07**: `[Marketing / Support]` **Contact Email Standardization**
  - **Description**: Multiple email formats (`ParableBloom@`, `parablebloom.support@`) across site and app.
  - **Affected Files**: `README.md`, `apps/parable-bloom-site/`
  - **Resolution Criteria**: Standardize on primary contact address.

- [ ] **BUG-H08**: `[Repository / Hygiene]` **AI Tool Configuration Clutter**
  - **Description**: Remove or gitignore non-essential local config folders.
  - **Affected Files**: `.gitignore`
  - **Resolution Criteria**: Review tracked directories and ignore local-only artifacts.

- [ ] **BUG-H09**: `[Android]` **Flutter Template Scaffolding Comment in Gradle**
  - **Description**: Leftover template comment `// TODO: Specify your own unique Application ID`.
  - **Affected Files**: `apps/parable-bloom/android/app/build.gradle.kts`
  - **Resolution Criteria**: Clean up comment.

---

## 🟡 Medium Priority Issues

- [ ] **BUG-M01**: `[Codebase]` **Resolve or Triage Code TODO Comments**
  - **Description**: 7 legacy TODO comments in codebase need triage.
  - **Affected Files**: `game_screen.dart`, `settings_screen.dart`, `background_audio_controller.dart`
  - **Resolution Criteria**: Complete tasks or log as post-v1 backlog issues.

- [ ] **BUG-M02**: `[Documentation]` **Release Scope in Game Design Document**
  - **Description**: Clarify initial v1 release scope vs. future roadmap features.
  - **Affected Files**: [`documentation/explanation/game-design.md`](../explanation/game-design.md)
  - **Resolution Criteria**: Add "Release Scope" section.

- [ ] **BUG-M03**: `[Documentation]` **Architecture Guide Refresh**
  - **Description**: Remove legacy placeholders and ensure provider diagrams reflect Riverpod code generation.
  - **Affected Files**: [`documentation/explanation/architecture.md`](../explanation/architecture.md)
  - **Resolution Criteria**: Verify all state management descriptions match current implementation.

- [ ] **BUG-M04**: `[i18n]` **Localization Infrastructure**
  - **Description**: Strings are currently hardcoded in English.
  - **Affected Files**: `apps/parable-bloom/lib/`
  - **Resolution Criteria**: Document English-only for v1, prepare `.arb` structure for future l10n.

- [ ] **BUG-M05**: `[Audio]` **Sound Mute / Volume Settings**
  - **Description**: Allow players to toggle background music and sound effects in Settings.
  - **Affected Files**: `apps/parable-bloom/lib/features/settings/`, `background_audio_controller.dart`
  - **Resolution Criteria**: Add volume/mute controls in Settings screen.

- [ ] **BUG-M06**: `[Analytics / Privacy]` **Analytics Opt-Out in Settings**
  - **Description**: Provide user privacy toggle to disable telemetry.
  - **Affected Files**: `apps/parable-bloom/lib/features/settings/`, `analytics_service.dart`
  - **Resolution Criteria**: Implement opt-out switch calling `FirebaseAnalytics.setAnalyticsCollectionEnabled(false)`.

- [ ] **BUG-M07**: `[Level Engine]` **Self-Blocking Vine Deadlock Edge Case**
  - **Description**: Verify solver prevents snake loops where vine heads are trapped in self-blocking geometries.
  - **Affected Files**: `tools/level-builder/pkg/validator/structural.go`
  - **Resolution Criteria**: Structural validation tests pass for all 105 levels.

- [ ] **BUG-M08**: `[UI / Animations]` **Grid Layout Overflow on Compact Mobile Screens**
  - **Description**: Transcendent 16×20 grids on smaller aspect-ratio displays need auto-scaling.
  - **Affected Files**: `apps/parable-bloom/lib/core/game_board_layout.dart`
  - **Resolution Criteria**: Verify board scales to fit within safe area without overflow.

- [ ] **BUG-M09**: `[Cloud Sync]` **Offline to Online Conflict Resolution**
  - **Description**: Ensure local progress merges cleanly when a guest user authenticates after offline play.
  - **Affected Files**: `apps/parable-bloom/lib/features/game/data/repositories/firebase_game_progress_repository.dart`
  - **Resolution Criteria**: Verified via unit tests in `progress_sync_test.dart`.

- [ ] **BUG-M10**: `[Devotions]` **Devotion Reflection Library Expansion**
  - **Description**: Ensure reflections rotate and link appropriately to unlocked themes.
  - **Affected Files**: `apps/parable-bloom/assets/data/biblical_themes.json`
  - **Resolution Criteria**: All 5 themes populated with 2–3 questions per passage.

- [ ] **BUG-M11**: `[Website]` **Website SEO & Metadata Verification**
  - **Description**: Ensure canonical tags, titles, and meta descriptions are configured across all Next.js routes.
  - **Affected Files**: `apps/parable-bloom-site/app/`
  - **Resolution Criteria**: Run lighthouse audit or verify metadata tags.

- [ ] **BUG-M12**: `[Dependencies]` **Unused Dependencies Cleanup**
  - **Description**: Audit `pubspec.yaml` to ensure no orphaned dependencies remain.
  - **Affected Files**: `apps/parable-bloom/pubspec.yaml`
  - **Resolution Criteria**: Remove or utilize packages.

- [ ] **BUG-M13**: `[Security]` **Firestore Security Rules Audit**
  - **Description**: Validate that only authenticated owners can write to `user_progress` and public can only read levels.
  - **Affected Files**: `firestore.rules`
  - **Resolution Criteria**: Rules test passing in emulator.

- [ ] **BUG-M14**: `[CI / Build]` **CI Build Artifact Caching**
  - **Description**: Cache Flutter artifacts and Go build caches to speed up CI runs.
  - **Affected Files**: `.github/workflows/ci.yml`
  - **Resolution Criteria**: CI runtime under 4 minutes.

---

## 🟢 Low Priority / Polish

- [ ] **BUG-L01**: `[Tooling]` **Level Generator CLI Output Formatting**
  - **Description**: Enhance terminal color output during `--verbose` validation.
  - **Affected Files**: `tools/level-builder/pkg/ui/`
  - **Resolution Criteria**: Clean tables and progress bars.

- [ ] **BUG-L02**: `[Juice / FX]` **Bloom Completion Particle Dispersion**
  - **Description**: Add subtle floral particle burst upon completing the final vine of a level.
  - **Affected Files**: `apps/parable-bloom/lib/features/game/presentation/flame/`
  - **Resolution Criteria**: Smooth 60 FPS particle animation.

- [ ] **BUG-L03**: `[Haptics]` **Haptic Feedback on Vine Slide & Block**
  - **Description**: Integrate subtle haptic feedback triggers for tap, slide, blocked, and bloom events.
  - **Affected Files**: `apps/parable-bloom/lib/features/game/`
  - **Resolution Criteria**: Configurable in Settings.

- [ ] **BUG-L04**: `[Website]` **Next.js 404 Page Customization**
  - **Description**: Add garden-themed custom 404 page.
  - **Affected Files**: `apps/parable-bloom-site/app/not-found.tsx`
  - **Resolution Criteria**: Branded not-found layout.

- [ ] **BUG-L05**: `[Documentation]` **Add Architecture Component Diagram**
  - **Description**: Replace ASCII component chart with Mermaid or rendered SVG.
  - **Affected Files**: [`documentation/explanation/architecture.md`](../explanation/architecture.md)
  - **Resolution Criteria**: Clear visual diagram.

- [ ] **BUG-L06**: `[A11y]` **Screen Reader Support for Vine Directions**
  - **Description**: Ensure Semantics widgets announce vine color, orientation, and length for screen readers.
  - **Affected Files**: `apps/parable-bloom/lib/features/game/`
  - **Resolution Criteria**: Basic TalkBack/VoiceOver navigable.

- [ ] **BUG-L07**: `[Website]` **Dark Mode Toggle on Marketing Site**
  - **Description**: Add light/dark theme toggle matching app theme palette.
  - **Affected Files**: `apps/parable-bloom-site/components/`
  - **Resolution Criteria**: Preserves user preference in localStorage.

- [ ] **BUG-L08**: `[Performance]` **Level JSON Parse Caching**
  - **Description**: Pre-warm commonly accessed level files into memory on app launch.
  - **Affected Files**: `apps/parable-bloom/lib/features/game/`
  - **Resolution Criteria**: Benchmark load times.

- [ ] **BUG-L09**: `[Store]` **App Store Submission Tracker Population**
  - **Description**: Fill in tracking dates as builds are submitted to TestFlight and Google Play Internal Track.
  - **Affected Files**: [`documentation/how-to/app-store-listings/templates/android-checklist.md`](../how-to/app-store-listings/templates/android-checklist.md)
  - **Resolution Criteria**: Checklists filled out during release.

- [ ] **BUG-L10**: `[Android]` **Android Namespace Clean Up**
  - **Description**: Rename legacy directory structure `com/example/parable_weave` to match current package name.
  - **Affected Files**: `apps/parable-bloom/android/app/src/main/kotlin/`
  - **Resolution Criteria**: Directory path matches `applicationId`.

---

## 📝 How to Log a New Bug

When adding a new bug to this list, format it using the standard schema:

```markdown
- [ ] **BUG-[SEVERITY][NUM]**: `[Subsystem]` **Short Descriptive Title**
  - **Description**: Clear explanation of the bug, symptoms, and expected behavior.
  - **Affected Files**: `path/to/file`
  - **Resolution Criteria**: What defines this bug as resolved.
```
