# 🚀 Parable Bloom — Launch-Readiness Audit Report

**Audit Date:** June 23, 2026
**App Version:** 1.5.1+27
**Scope:** Full application sweep — Flutter app, Next.js site, documentation, CI/CD, scripts, and tools

---

## Executive Summary

Parable Bloom is a well-architected, thoroughly documented Flutter puzzle game that demonstrates strong engineering practices. The codebase is clean, CI/CD is robust, and the Next.js marketing site is functional. However, there are several **critical and high-priority issues** that must be resolved before public release, primarily around **inconsistent app identifiers**, **missing store assets**, **incomplete attributions**, and **web manifest branding**.

| Priority | Count |
|----------|-------|
| 🔴 Critical | 4 |
| 🟠 High | 9 |
| 🟡 Medium | 14 |
| 🟢 Low | 10 |
| **Total** | **37** |

---

## 🔴 Critical Issues (Must fix before launch)

### C-1: Inconsistent Google Play App ID Across Website

- **Category:** Website & Marketing Alignment
- **Files:**
  - [page.tsx](file:///Users/engarcia/Development/parable-bloom/apps/parable-bloom-site/app/page.tsx#L24) → `com.eng618.parablebloom`
  - [about/page.tsx](file:///Users/engarcia/Development/parable-bloom/apps/parable-bloom-site/app/about/page.tsx#L58) → `com.garciaericn.parablebloom`
  - [build.gradle.kts](file:///Users/engarcia/Development/parable-bloom/apps/parable-bloom/android/app/build.gradle.kts#L28) → `com.garciaericn.parable_bloom` (actual)
  - [RELEASE_PROCESS.md](file:///Users/engarcia/Development/parable-bloom/documentation/RELEASE_PROCESS.md) → `com.garciaericn.parablebloom`
- **Description:** The Google Play Store URL references at least **three different app IDs**: `com.eng618.parablebloom`, `com.garciaericn.parablebloom`, and the actual Android applicationId `com.garciaericn.parable_bloom`. None of the website URLs match the actual applicationId.
- **Impact:** Users clicking "Get on Google Play" will land on a 404 page. Store links will be completely broken.
- **Action:** Determine the final, correct application ID and update ALL references across the site, documentation, and build config to match exactly.
- **Effort:** 1-2 hours

---

### C-2: Apple App Store URL is a Placeholder

- **Category:** Website & Marketing Alignment
- **Files:**
  - [page.tsx](file:///Users/engarcia/Development/parable-bloom/apps/parable-bloom-site/app/page.tsx#L32) → `id1234567890`
  - [page.tsx](file:///Users/engarcia/Development/parable-bloom/apps/parable-bloom-site/app/page.tsx#L105) (hero link)
  - [about/page.tsx](file:///Users/engarcia/Development/parable-bloom/apps/parable-bloom-site/app/about/page.tsx#L46) → different URL format
- **Description:** The App Store link uses a dummy ID (`id1234567890`). The about page uses yet another format (`/app/parable-bloom` without an ID). Both will lead to broken links.
- **Impact:** iOS users cannot find or download the app. App Store link is completely non-functional.
- **Action:** Once the app is submitted and approved, update with the real App Store ID. If not yet submitted, mark these links with proper "Coming Soon" behavior that doesn't navigate to a broken URL.
- **Effort:** 30 minutes (once IDs are known)

---

### C-3: Missing OG Image for Social Sharing

- **Category:** Website & Marketing Alignment
- **File:** [layout.tsx](file:///Users/engarcia/Development/parable-bloom/apps/parable-bloom-site/app/layout.tsx#L9) references `metadataBase: new URL('https://parable-bloom.pages.dev')`
- **Description:** No Open Graph image (`og-image.png`) exists in the `public/` directory. The layout references a metadataBase but no explicit `openGraph.images` is configured. Social sharing on Twitter, Facebook, LinkedIn, and Discord will show no preview image.
- **Impact:** Poor social media presence. Shared links will look unpolished and unprofessional, reducing click-through rates.
- **Action:** Create a branded 1200×630px OG image and add it to `public/`. Configure explicit `openGraph` metadata in the root layout.
- **Effort:** 1-2 hours

---

### C-4: Incomplete Asset Attributions — License Compliance Risk

- **Category:** Legal & Compliance
- **File:** [ATTRIBUTIONS.md](file:///Users/engarcia/Development/parable-bloom/documentation/ATTRIBUTIONS.md)
- **Description:** Only 1 audio file (`background.mp3`) is attributed. The app ships with 4 audio files (`bloom.mp3`, `grace.mp3`, `slide.mp3`, `tap.mp3`), 7+ devotion images, watercolor backgrounds, and the Playfair Display font — none of which are attributed. The Lottie animation (`bloom_complete.json`) also lacks attribution.
- **Impact:** Potential copyright infringement. App store rejection if a reviewer identifies unlicensed assets. Legal liability.
- **Action:** Audit every asset in `assets/audio/`, `assets/images/`, `assets/fonts/`, and `assets/lottie/`. Document source, license, and any required attribution for each. Add missing attributions.
- **Effort:** 2-4 hours

---

## 🟠 High Priority Issues (Should fix before launch)

### H-1: Web Manifest Uses Default Flutter Blue Branding

- **Category:** UI/UX
- **Files:**
  - [manifest.json](file:///Users/engarcia/Development/parable-bloom/apps/parable-bloom/web/manifest.json#L6-L7): `background_color: #0175C2`, `theme_color: #0175C2`
  - [index.html](file:///Users/engarcia/Development/parable-bloom/apps/parable-bloom/web/index.html) — no `<meta name="theme-color">` set
- **Description:** The PWA manifest uses Flutter's default blue (`#0175C2`) instead of the app's brand green (`#177245` as used on the marketing site). The web index.html also lacks a theme-color meta tag.
- **Impact:** The PWA install screen, browser address bar, and task switcher will show Flutter's blue instead of the app's grace green branding. Inconsistent brand experience.
- **Action:** Update `manifest.json` theme/background colors to match the app's brand color. Add `<meta name="theme-color" content="#177245">` to `index.html`.
- **Effort:** 15 minutes

---

### H-2: Development Artifacts Committed to Repository

- **Category:** Code & Release Readiness
- **Files:**
  - `snapshot.log` (56KB) — dependency snapshot from 2025-07-17
  - `apps/parable-bloom/firestore-debug.log` — Firebase emulator debug log
  - `tools/level-builder/test-results/` — JUnit test results directory
  - `apps/parable-bloom/build/` — build output directory
  - `apps/parable-bloom/coverage/` — test coverage reports
- **Description:** Several development artifacts and build outputs are tracked in the repository. These add noise, increase clone size, and may contain sensitive debugging information.
- **Impact:** Unprofessional repository appearance. Increased clone size. Potential information leakage.
- **Action:** Add these paths to `.gitignore`, remove them from tracking with `git rm --cached`, and commit.
- **Effort:** 30 minutes

---

### H-3: SECURITY.md is Minimal

- **Category:** Documentation
- **File:** [SECURITY.md](file:///Users/engarcia/Development/parable-bloom/SECURITY.md)
- **Description:** The security policy is only 10 lines. It references "Master branch" (should be "main"), lacks a supported versions table, has no vulnerability disclosure timeline, and doesn't describe the handling process.
- **Impact:** Users and security researchers have no clear guidance on how vulnerabilities will be handled. App stores may review this.
- **Action:** Expand with: supported versions table, expected response timeline (e.g., 48h acknowledgment, 30-day fix target), scope of security coverage, and PGP key or security contact details.
- **Effort:** 1 hour

---

### H-4: App Store Listing Screenshots Not Created

- **Category:** Launch Readiness
- **Files:**
  - [media-assets.md](file:///Users/engarcia/Development/parable-bloom/documentation/app-store-listings/shared/media-assets.md) — lists required screenshot dimensions
  - [submission-tracker.md](file:///Users/engarcia/Development/parable-bloom/documentation/app-store-listings/submission-tracker.md) — mostly empty
- **Description:** Both Apple and Google require specific screenshot assets for store listings. The documentation templates reference these but the actual screenshot files have not been created. Integration test `app_screenshots_test.dart` exists for automated screenshot capture, which is good.
- **Impact:** Cannot submit to app stores without screenshots. Submission will be blocked.
- **Action:** Run the screenshot integration test to generate base screenshots. Create polished, framed versions at required dimensions (iPhone 6.7", iPad 12.9", Android phone/tablet).
- **Effort:** 4-8 hours

---

### H-5: Privacy Policy and Terms Dates May Need Updating

- **Category:** Legal & Compliance
- **Files:**
  - [privacy/page.tsx](file:///Users/engarcia/Development/parable-bloom/apps/parable-bloom-site/app/privacy/page.tsx#L14-L17): Effective Feb 4, 2026 / Last Updated March 13, 2026
  - [terms/page.tsx](file:///Users/engarcia/Development/parable-bloom/apps/parable-bloom-site/app/terms/page.tsx#L14-L17): Effective Feb 4, 2026 / Last Updated Feb 23, 2026
- **Description:** The privacy policy and terms of service have "Last Updated" dates from earlier in 2026. If any changes have been made to data collection, features, or policies since those dates, the documents need updating. The privacy policy mentions account deletion features that should be verified as implemented.
- **Impact:** Outdated legal documents can create compliance issues and erode user trust.
- **Action:** Review both documents against current app functionality. Update dates if any content changes are made. Verify all referenced features (e.g., account deletion via Settings) actually work.
- **Effort:** 1-2 hours

---

### H-6: No Widget Tests for UI Layer

- **Category:** Code & Release Readiness
- **File:** [test/](file:///Users/engarcia/Development/parable-bloom/apps/parable-bloom/test) directory
- **Description:** The `test/` directory contains unit tests for models and services, but there are **zero widget tests** for any screens or UI components. The game screen, settings screen, dashboard, level selection, daily devotion, and help screens are all untested at the widget level.
- **Impact:** UI regressions cannot be caught automatically. Confidence in UI correctness is low for release.
- **Action:** Add widget tests for critical screens: game screen, dashboard, settings, and level selection. At minimum, test that screens render without errors and key interactions work.
- **Effort:** 8-16 hours (can be phased post-launch)

---

### H-7: Contact Email Inconsistency Across Project

- **Category:** Website & Marketing Alignment
- **Description:** Multiple email addresses are used across the project:
  - Site privacy/terms: `parablebloom.support@garciaericn.com`
  - Delete account page: `parablebloom.account+delete@garciaericn.com`
  - README.md: `ParableBloom@garciaericn.com`
  - .env.example: `ParableBloom@garciaericn.com`
  - SECURITY.md: `security@garciaericn.com`
- **Impact:** Users may be confused about which email to use. Support emails could go to wrong inboxes if not all aliases are configured.
- **Action:** Verify all email aliases are properly configured and receiving mail. Consider standardizing to one primary support email in user-facing content and document the purpose of each alias internally.
- **Effort:** 1 hour

---

### H-8: AI Tool Configuration Directories in Repository

- **Category:** Code & Release Readiness
- **Files:** `.agent/`, `.gitnexus/`, `.clinerules/`, `.cline`
- **Description:** Multiple AI assistant configuration directories and files are present in the repository. These contain workspace-specific AI configurations that are irrelevant to contributors and may contain sensitive prompts or patterns.
- **Impact:** Repository clutter. Contributors may be confused by these directories. Potential information leakage.
- **Action:** Add these to `.gitignore`. Remove from tracking if they don't need to be shared.
- **Effort:** 15 minutes

---

### H-9: Android TODO Comment from Flutter Template

- **Category:** Code & Release Readiness
- **File:** [build.gradle.kts](file:///Users/engarcia/Development/parable-bloom/apps/parable-bloom/android/app/build.gradle.kts#L27)
- **Description:** Line 27 contains the Flutter template TODO: `// TODO: Specify your own unique Application ID`. This is a leftover from project scaffolding and suggests the app ID may not have been intentionally chosen.
- **Impact:** Minor — cosmetic issue, but signals incomplete setup to reviewers. Should be removed to confirm the app ID is intentional.
- **Action:** Remove the TODO comment. Verify the applicationId is correct and intentional.
- **Effort:** 5 minutes

---

## 🟡 Medium Priority Issues

### M-1: 7 TODO Comments in Application Source Code

- **Category:** Code & Release Readiness
- **Description:** TODOs found across the Flutter codebase:

| File | Line | TODO |
|------|------|------|
| [game_screen.dart](file:///Users/engarcia/Development/parable-bloom/apps/parable-bloom/lib/features/game/screens/game_screen.dart) | ~135 | Remove when implementing proper purchase flow |
| [game_screen.dart](file:///Users/engarcia/Development/parable-bloom/apps/parable-bloom/lib/features/game/screens/game_screen.dart) | ~141 | Debug buttons need recount |
| [settings_screen.dart](file:///Users/engarcia/Development/parable-bloom/apps/parable-bloom/lib/features/settings/screens/settings_screen.dart) | 13 | Create way to turn off hints/sound |
| [level_validation_service.dart](file:///Users/engarcia/Development/parable-bloom/apps/parable-bloom/lib/features/level/services/level_validation_service.dart) | 57 | Check for >4 vines |
| [theme.dart](file:///Users/engarcia/Development/parable-bloom/apps/parable-bloom/lib/app/theme.dart) | 42 | Commented out for future use |
| [grid_board_widget.dart](file:///Users/engarcia/Development/parable-bloom/apps/parable-bloom/lib/features/level/widgets/grid_board_widget.dart) | 158 | Add back vine emoji text |
| [daily_devotion_service.dart](file:///Users/engarcia/Development/parable-bloom/apps/parable-bloom/lib/features/daily_devotion/services/daily_devotion_service.dart) | 29 | Add more devotions |
| [audio_service.dart](file:///Users/engarcia/Development/parable-bloom/apps/parable-bloom/lib/services/audio_service.dart) | ~90 | Make configurable through settings |

- **Impact:** Indicates incomplete features. The debug button TODOs are behind `kDebugMode` gates so they won't appear in release, but should be tracked.
- **Action:** Triage each TODO: resolve, convert to GitHub Issues for post-launch, or remove if no longer relevant.
- **Effort:** 2-3 hours

---

### M-2: GAME_DESIGN.md References Unimplemented Features

- **Category:** Documentation
- **File:** [GAME_DESIGN.md](file:///Users/engarcia/Development/parable-bloom/documentation/GAME_DESIGN.md)
- **Description:** References "Power-Up System", "Achievement System", "Marketplace", and "Multiplayer" as planned features without clarity on whether they're for this release or future versions.
- **Impact:** Internal confusion about release scope. Potential miscommunication with stakeholders.
- **Action:** Add a "Release Scope" section clearly marking which features are v1.0 and which are future roadmap items.
- **Effort:** 30 minutes

---

### M-3: ARCHITECTURE.md Has TODO Placeholders and Potentially Outdated Content

- **Category:** Documentation
- **File:** [ARCHITECTURE.md](file:///Users/engarcia/Development/parable-bloom/documentation/ARCHITECTURE.md)
- **Description:** Contains `TODO: Add architectural diagram image` and `TODO: Add metrics dashboard screenshot`. Some sections may reference outdated state management patterns (e.g., `StateNotifier`) while the codebase uses Riverpod code generation (`@riverpod`).
- **Impact:** Misleading architecture documentation could confuse new contributors.
- **Action:** Remove or fulfill TODO placeholders. Verify state management descriptions match the current codebase. Add the architectural diagram if available.
- **Effort:** 2-3 hours

---

### M-4: No Localization/i18n Infrastructure

- **Category:** UI/UX
- **Description:** All user-facing strings are hardcoded in English throughout the Flutter app. There is no `intl` package usage despite it being in `pubspec.yaml` dependencies, no `.arb` files, and no localization delegates configured.
- **Impact:** Cannot support non-English users. The `intl` dependency is unused weight. If targeting a global audience, this limits reach.
- **Action:** For v1.0, this is acceptable if targeting English-only. Consider extracting strings to `.arb` files as a post-launch improvement. Document the decision.
- **Effort:** 8-16 hours (post-launch)

---

### M-5: CONTRIBUTING.md References Incorrect Test Command

- **Category:** Documentation
- **File:** [CONTRIBUTING.md](file:///Users/engarcia/Development/parable-bloom/CONTRIBUTING.md)
- **Description:** Likely references `flutter test` directly instead of the project's standard `task test:all` which runs tests across all monorepo modules via Nx.
- **Impact:** New contributors may miss running the full test suite.
- **Action:** Update test instructions to use `task test:all` and explain the monorepo test strategy.
- **Effort:** 15 minutes

---

### M-6: No ProGuard/R8 Rules for Android Release

- **Category:** Code & Release Readiness
- **File:** [build.gradle.kts](file:///Users/engarcia/Development/parable-bloom/apps/parable-bloom/android/app/build.gradle.kts)
- **Description:** The release build type does not configure `isMinifyEnabled`, `isShrinkResources`, or ProGuard rules. While Flutter handles most obfuscation, certain Firebase and third-party libraries may require keep rules.
- **Impact:** Larger APK size. Potential runtime crashes from aggressive minification on release builds.
- **Action:** Add `isMinifyEnabled = true`, `isShrinkResources = true`, and appropriate ProGuard rules for Firebase and other dependencies.
- **Effort:** 2-4 hours (including testing)

---

### M-7: Web index.html Lacks Open Graph and Twitter Card Meta Tags

- **Category:** Website & Marketing Alignment
- **File:** [index.html](file:///Users/engarcia/Development/parable-bloom/apps/parable-bloom/web/index.html)
- **Description:** The Flutter web app's `index.html` has a basic description meta tag but no Open Graph or Twitter card tags. When the web app URL (`parable-bloom.web.app`) is shared on social media, it will have a poor preview.
- **Impact:** Poor social sharing experience for the web version of the game.
- **Action:** Add OG title, description, image, and Twitter card meta tags to `index.html`.
- **Effort:** 30 minutes

---

### M-8: No Error Boundary/Crash Recovery UX in Flutter App

- **Category:** Bug Review
- **Description:** While `firebase_crashlytics` is integrated for crash reporting, there's no user-facing error recovery flow. If a level fails to load or data corruption occurs, the user experience is unclear.
- **Impact:** Users hitting errors have no graceful recovery path, potentially leading to app uninstalls.
- **Action:** Add error widgets/screens for common failure cases (level load failure, data corruption). Implement a "reset progress" option as a last resort.
- **Effort:** 4-8 hours

---

### M-9: Footer Copyright Says "GVTech" but README Says "Eric Garcia"

- **Category:** Website & Marketing Alignment
- **Files:**
  - [site-shell.tsx](file:///Users/engarcia/Development/parable-bloom/apps/parable-bloom-site/components/site-shell.tsx#L71): `© {year} GVTech. All rights reserved.`
  - [LICENSE](file:///Users/engarcia/Development/parable-bloom/LICENSE): `Copyright (c) Eric Garcia`
  - Privacy/Terms pages reference "GVTech"
- **Description:** The entity name is inconsistent — "GVTech" on the site and legal pages vs "Eric Garcia" in the LICENSE file.
- **Impact:** Legal ambiguity about the copyright holder. Should be consistent across all public-facing materials.
- **Action:** Decide on the official entity name and update all references to match.
- **Effort:** 30 minutes

---

### M-10: Site metadataBase URL Doesn't Match Primary Domain

- **Category:** Website & Marketing Alignment
- **File:** [layout.tsx](file:///Users/engarcia/Development/parable-bloom/apps/parable-bloom-site/app/layout.tsx#L9)
- **Description:** The `metadataBase` is set to `https://parable-bloom.pages.dev` (Cloudflare Pages URL), not a custom domain like `parablebloom.com`.
- **Impact:** SEO signals point to the deployment platform URL. Canonical URLs may not resolve correctly if a custom domain is configured.
- **Action:** If a custom domain is planned, update `metadataBase` to the primary domain. Configure proper redirects from the `.pages.dev` URL.
- **Effort:** 15 minutes

---

### M-11: "Coming Soon" Store Links Navigate to Broken URLs

- **Category:** UI/UX
- **Files:** [page.tsx](file:///Users/engarcia/Development/parable-bloom/apps/parable-bloom-site/app/page.tsx#L21-L35) (platform cards)
- **Description:** The "Coming Soon" platform cards for Android and iOS still have `href` links that navigate to (broken) store URLs. Users clicking "Coming Soon" buttons will land on dead pages.
- **Impact:** Poor user experience. Confused users. Potential loss of interest.
- **Action:** For "Coming Soon" items, either disable the link/button or show a toast/modal saying "Coming soon! Sign up for notifications" instead of navigating to a dead URL.
- **Effort:** 1 hour

---

### M-12: Daily Devotion Content is Limited

- **Category:** UI/UX
- **File:** [daily_devotion_service.dart](file:///Users/engarcia/Development/parable-bloom/apps/parable-bloom/lib/features/daily_devotion/services/daily_devotion_service.dart#L29)
- **Description:** The daily devotion feature has a TODO to "Add more devotions." With only 7 devotion images, the content will repeat weekly. For a feature called "daily devotion," this may disappoint users.
- **Impact:** Repetitive content reduces long-term engagement. Users may perceive the feature as incomplete.
- **Action:** Either expand the devotion content library or set expectations appropriately in the UI (e.g., "Weekly Reflection" instead of "Daily Devotion").
- **Effort:** 2-4 hours

---

### M-13: `intl` Package Dependency May Be Unused

- **Category:** Code & Release Readiness
- **File:** [pubspec.yaml](file:///Users/engarcia/Development/parable-bloom/apps/parable-bloom/pubspec.yaml)
- **Description:** The `intl` package is listed as a dependency but no localization setup (`.arb` files, localization delegates) was found. If it's only used for date/number formatting, that's fine. If it was intended for l10n but never set up, it's dead weight.
- **Impact:** Minor — unnecessary dependency increases app size slightly.
- **Action:** Verify if `intl` is actively used. If only for formatting, keep it. If unused, remove it.
- **Effort:** 15 minutes

---

### M-14: No Analytics Opt-Out in Flutter App

- **Category:** Privacy & Compliance
- **Description:** The privacy policy mentions Firebase Analytics and references Plausible Analytics opt-out for the website. However, there's no visible opt-out mechanism in the Flutter app's settings for Firebase Analytics. The TODO about configurable settings reinforces this.
- **Impact:** May not comply with GDPR/CCPA requirements in all jurisdictions. Users cannot opt out of analytics tracking in the app.
- **Action:** Add an analytics opt-out toggle in Settings. Implement `FirebaseAnalytics.instance.setAnalyticsCollectionEnabled(false)` when toggled off.
- **Effort:** 2-4 hours

---

## 🟢 Low Priority Issues

### L-1: `snapshot.log` and Debug Logs Should Be Gitignored

- **Category:** Code & Release Readiness
- **Action:** Already covered in H-2, but specifically add to `.gitignore`: `snapshot.log`, `firestore-debug.log`, `**/test-results/`
- **Effort:** 5 minutes

### L-2: Audio Service Configuration TODO

- **Category:** Code & Release Readiness
- **File:** [audio_service.dart](file:///Users/engarcia/Development/parable-bloom/apps/parable-bloom/lib/services/audio_service.dart)
- **Description:** Volume and audio settings are not user-configurable. The TODO suggests this was planned.
- **Action:** Convert to a GitHub Issue for post-launch. The current hardcoded settings work fine for v1.
- **Effort:** N/A (tracking only)

### L-3: No iOS Build in CI Pipeline

- **Category:** Code & Release Readiness
- **File:** [ci.yml](file:///Users/engarcia/Development/parable-bloom/.github/workflows/ci.yml)
- **Description:** CI builds web and Android but not iOS. This is understandable (macOS runners are expensive), but means iOS-specific issues won't be caught automatically.
- **Action:** Consider adding an iOS build job that runs on pushes to `main` only (not PRs) to catch platform-specific issues before release.
- **Effort:** 2-4 hours

### L-4: Vine Emoji Text Removed from Grid (TODO)

- **Category:** UI/UX
- **File:** [grid_board_widget.dart](file:///Users/engarcia/Development/parable-bloom/apps/parable-bloom/lib/features/level/widgets/grid_board_widget.dart#L158)
- **Description:** Vine emoji text was removed from grid cells with a TODO to add it back. This is a design decision that should be explicitly resolved.
- **Action:** Decide whether to add the emoji back or remove the TODO. Convert to GitHub Issue if deferring.
- **Effort:** 30 minutes

### L-5: Level Validation Question About >4 Vines

- **Category:** Bug Review
- **File:** [level_validation_service.dart](file:///Users/engarcia/Development/parable-bloom/apps/parable-bloom/lib/features/level/services/level_validation_service.dart#L57)
- **Description:** Open question about whether to validate for more than 4 vines on a grid.
- **Action:** Resolve the design question and either add the validation or remove the TODO.
- **Effort:** 30 minutes

### L-6: Potential Flame Dependency Optimization

- **Category:** Code & Release Readiness
- **Description:** Flame (`^1.23.0`) is actively used in the game components (confirmed: `garden_game.dart`, `vine_component.dart`, `grid_component.dart`, `tap_effect_component.dart`, etc.). This is NOT unused — it's a core dependency. No action needed.
- **Effort:** None

### L-7: Theme.dart Has Commented-Out Code

- **Category:** Code & Release Readiness
- **File:** [theme.dart](file:///Users/engarcia/Development/parable-bloom/apps/parable-bloom/lib/app/theme.dart#L42)
- **Description:** Code commented out "for potential future use." Commented-out code adds noise.
- **Action:** Remove commented code or extract to a design reference document.
- **Effort:** 5 minutes

### L-8: App Store Submission Tracker is Empty Template

- **Category:** Launch Readiness
- **File:** [submission-tracker.md](file:///Users/engarcia/Development/parable-bloom/documentation/app-store-listings/submission-tracker.md)
- **Description:** The submission tracker template exists but hasn't been filled in with actual submission data.
- **Action:** Begin filling in as submissions are made.
- **Effort:** Ongoing

### L-9: RELEASE_PROCESS.md Fastlane References

- **Category:** Documentation
- **File:** [RELEASE_PROCESS.md](file:///Users/engarcia/Development/parable-bloom/documentation/RELEASE_PROCESS.md)
- **Description:** Some sections may reference Fastlane for automated deployment, but it's unclear if Fastlane is actually configured in the project. No `Fastfile` or `Appfile` was found.
- **Action:** Remove Fastlane references if not using it, or set it up if planned.
- **Effort:** 30 min (doc cleanup) or 4-8 hours (Fastlane setup)

### L-10: Kotlin Android Source Path References Legacy Package Name

- **Category:** Code & Release Readiness
- **Description:** The Android `MainActivity.kt` file is located at `com/example/parable_weave/` which appears to be a legacy package path. While the actual package in the file may be correct, the directory structure is misleading.
- **Impact:** Minor — the build system uses `applicationId` from `build.gradle.kts`, not the directory path. But it's confusing.
- **Action:** Rename the directory to match the actual namespace if it hasn't been done.
- **Effort:** 30 minutes

---

## 📋 Prioritized Launch Checklist

### Phase 1: Pre-Submission Blockers (Critical)

- [ ] **C-1**: Resolve Google Play App ID inconsistency across all files
- [ ] **C-2**: Fix or disable Apple App Store placeholder URLs
- [ ] **C-3**: Create and configure OG image for social sharing
- [ ] **C-4**: Complete asset attributions for all audio, images, fonts, and animations

### Phase 2: Pre-Launch Must-Haves (High)

- [ ] **H-1**: Update web manifest and index.html theme colors to brand green
- [ ] **H-2**: Gitignore and remove development artifacts from repository
- [ ] **H-3**: Expand SECURITY.md with proper vulnerability disclosure policy
- [ ] **H-4**: Generate app store listing screenshots using integration tests
- [ ] **H-5**: Review and update Privacy Policy and Terms of Service dates
- [ ] **H-7**: Verify all contact email aliases are properly configured
- [ ] **H-8**: Gitignore AI tool configuration directories
- [ ] **H-9**: Remove Flutter template TODO from build.gradle.kts

### Phase 3: Pre-Launch Should-Haves (Medium)

- [ ] **M-1**: Triage all 7 TODO comments — resolve or convert to issues
- [ ] **M-2**: Add release scope section to GAME_DESIGN.md
- [ ] **M-3**: Update ARCHITECTURE.md — remove TODO placeholders, verify accuracy
- [ ] **M-5**: Update CONTRIBUTING.md test instructions
- [ ] **M-6**: Configure ProGuard/R8 for Android release builds
- [ ] **M-7**: Add OG/Twitter meta tags to Flutter web index.html
- [ ] **M-9**: Resolve copyright holder name inconsistency (GVTech vs Eric Garcia)
- [ ] **M-10**: Update metadataBase to primary/custom domain if applicable
- [ ] **M-11**: Fix "Coming Soon" links to not navigate to broken store URLs
- [ ] **M-14**: Add analytics opt-out toggle to Flutter app settings

### Phase 4: Post-Launch Improvements (Medium-Low)

- [ ] **H-6**: Add widget tests for critical UI screens
- [ ] **M-4**: Implement localization infrastructure
- [ ] **M-8**: Add error boundaries and crash recovery UX
- [ ] **M-12**: Expand daily devotion content library
- [ ] **M-13**: Audit `intl` package usage
- [ ] **L-2**: Make audio settings user-configurable
- [ ] **L-3**: Add iOS build to CI pipeline
- [ ] **L-4**: Resolve vine emoji text design decision
- [ ] **L-5**: Resolve >4 vines validation question
- [ ] **L-7**: Remove commented-out code from theme.dart
- [ ] **L-9**: Resolve Fastlane references in RELEASE_PROCESS.md
- [ ] **L-10**: Fix legacy Android source directory path

---

## ✅ What's Already Good

The following areas demonstrate strong practices that should be maintained:

| Area | Assessment |
|------|-----------|
| **Code Architecture** | Clean feature-based architecture with proper separation of concerns |
| **State Management** | Riverpod with code generation — modern and maintainable |
| **Firebase Integration** | Crashlytics, Analytics properly configured. Dummy options for CI ✅ |
| **Firestore Security Rules** | Restrictive rules requiring auth, user-scoped data access ✅ |
| **CI/CD Pipeline** | Multi-job CI with analyze, test, build. Automated releases ✅ |
| **Signing Config** | Android signing via environment variables, no hardcoded secrets ✅ |
| **Level Generation** | Go-based solver ensures all levels are solvable ✅ |
| **Unit Test Coverage** | Models and services have solid test coverage ✅ |
| **Integration Tests** | App flow tests and screenshot generation tests exist ✅ |
| **Nx Monorepo** | Well-configured workspace with caching ✅ |
| **SEO (Site)** | Sitemap, robots.txt, meta descriptions, semantic HTML ✅ |
| **Legal Pages** | Privacy policy (with COPPA), Terms of Service, Delete Account page ✅ |
| **Plausible Analytics** | Self-hosted, privacy-focused analytics on the site ✅ |
| **Debug Code Gating** | All debug buttons properly behind `kDebugMode` ✅ |
| **No Hardcoded Secrets** | No API keys, passwords, or credentials in source code ✅ |

---

> [!IMPORTANT]
> The 4 critical issues (C-1 through C-4) are **hard blockers** for any public release. The inconsistent app IDs (C-1) will result in completely broken store links on launch day. Address these first.
