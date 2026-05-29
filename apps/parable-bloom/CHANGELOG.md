## 1.5.0 (2026-05-29)

### 🚀 Features

- implement reactive cloud sync state providers and update architecture documentation ([83e7c44](https://github.com/eng618/parable-bloom/commit/83e7c44))
- implement screen tracking, specific event logging, and user-configurable telemetry opt-out settings ([8a5ec71](https://github.com/eng618/parable-bloom/commit/8a5ec71))
- revamp the vine aesthetics ([9386d16](https://github.com/eng618/parable-bloom/commit/9386d16))
- implement interactive tutorial guide overlay with coordinate-based highlights and collision feedback ([3046c16](https://github.com/eng618/parable-bloom/commit/3046c16))
- add connectivity stream provider and tests for syncOnReconnect behavior ([acb4d75](https://github.com/eng618/parable-bloom/commit/acb4d75))
- add tests for syncToCloud behavior with local data synchronization ([d81e33b](https://github.com/eng618/parable-bloom/commit/d81e33b))
- enhance cloud sync error handling with detailed logging and retry recovery ([7798e5b](https://github.com/eng618/parable-bloom/commit/7798e5b))
- add cloud sync conflict resolution tests in FirebaseGameProgressRepository ([c131043](https://github.com/eng618/parable-bloom/commit/c131043))
- add connectivity handling and synchronization on reconnect in game progress repository ([d276f0f](https://github.com/eng618/parable-bloom/commit/d276f0f))
- implement retry mechanism for cloud read operations with exponential backoff in FirebaseGameProgressRepository ([8423e8a](https://github.com/eng618/parable-bloom/commit/8423e8a))
- add retry logic for transient Firebase write errors in repository tests ([3e1699b](https://github.com/eng618/parable-bloom/commit/3e1699b))
- implement retry mechanism for cloud write operations in FirebaseGameProgressRepository ([09dc2cb](https://github.com/eng618/parable-bloom/commit/09dc2cb))
- extend logLevelComplete method in FakeAnalytics and FakeAnalyticsService to include attempts and elapsedSeconds parameters ([a56fec9](https://github.com/eng618/parable-bloom/commit/a56fec9))
- add configurable cloud read and write timeouts to Firebase game progress repository ([971ca2d](https://github.com/eng618/parable-bloom/commit/971ca2d))
- enhance error handling and fallback mechanisms in module loading and settings repository ([9b03b1d](https://github.com/eng618/parable-bloom/commit/9b03b1d))
- add jni to Flutter FFI plugin list for Linux and Windows ([73eea00](https://github.com/eng618/parable-bloom/commit/73eea00))
- add level attempt count and start timestamp providers with analytics integration ([51c9523](https://github.com/eng618/parable-bloom/commit/51c9523))
- add automated iOS screenshot capture and upload via Fastlane Snapshot ([917387e](https://github.com/eng618/parable-bloom/commit/917387e))
- Integrate Plausible Analytics client and update AnalyticsService for dual tracking ([34f928e](https://github.com/eng618/parable-bloom/commit/34f928e))
- Implement cloud sync functionality with conflict resolution ([11df7ca](https://github.com/eng618/parable-bloom/commit/11df7ca))
- add module providers and integrate into game and home screens ([167fef0](https://github.com/eng618/parable-bloom/commit/167fef0))
- implement ParableBloomApp and HomeScreen, restructure app folder organization ([3c1eea2](https://github.com/eng618/parable-bloom/commit/3c1eea2))
- refactor game progress storage keys and improve animation timing constants ([5eca57a](https://github.com/eng618/parable-bloom/commit/5eca57a))
- add tests for markAttempted grace decrement and anyVineAnimating reset logic ([642b436](https://github.com/eng618/parable-bloom/commit/642b436))
- enhance VineComponent animation logic and add test for animatingClear state ([2306983](https://github.com/eng618/parable-bloom/commit/2306983))
- implement GameBoardLayout for consistent grid and cell management across game components ([7ce5a65](https://github.com/eng618/parable-bloom/commit/7ce5a65))
- update macOS deployment target to 11.0 and improve pod build settings ([195a47c](https://github.com/eng618/parable-bloom/commit/195a47c))
- add macOS toolchain checks and doctor command for Flutter development ([28d96b2](https://github.com/eng618/parable-bloom/commit/28d96b2))
- add FlutterFire CLI installation and authentication checks to Firebase tasks ([fc968f4](https://github.com/eng618/parable-bloom/commit/fc968f4))
- **parable-bloom-site:** modernize site with Tailwind CSS v4, full GV Tech UI adoption, and Support FAB ([#44](https://github.com/eng618/parable-bloom/pull/44))
- add validation script and update configurations for improved development workflow ([04fc77f](https://github.com/eng618/parable-bloom/commit/04fc77f))
- add initial components and configuration for Parable Bloom site ([f4e551b](https://github.com/eng618/parable-bloom/commit/f4e551b))
- **logger:** improve crashlytics initialization handling and update logging methods ([7349134](https://github.com/eng618/parable-bloom/commit/7349134))
- **logging:** Introduce LoggerService for centralized logging and error reporting ([1c4e5eb](https://github.com/eng618/parable-bloom/commit/1c4e5eb))

### 🩹 Fixes

- watch authUserProvider in cloud sync status providers to ensure reactive updates on auth changes ([ccafb33](https://github.com/eng618/parable-bloom/commit/ccafb33))
- add missing directory ([1028fbf](https://github.com/eng618/parable-bloom/commit/1028fbf))
- revert bun version to 1.3.9 ([68e5e72](https://github.com/eng618/parable-bloom/commit/68e5e72))

### ❤️ Thank You

- Copilot @Copilot
- eng618 @eng618
- Eric N. Garcia @eng618

## 1.4.2 (2026-02-26)

### 🚀 Features

- add password reset for accounts ([e04db94](https://github.com/eng618/parable-bloom/commit/e04db94))
- Implement user account deletion, integrate Firebase Crashlytics. ([3e6d0e9](https://github.com/eng618/parable-bloom/commit/3e6d0e9))

### ❤️ Thank You

- Eric N. Garcia @eng618

## 1.4.1 (2026-02-26)

This was a version bump only for parable-bloom to align it with other projects, there were no code changes.

## 1.4.0 (2026-02-25)

### 🚀 Features

- Introduce new withered vine assets with a rotting wood effect, update the classic spritesheet, and adjust the `tapEffectLight` theme color. ([f3cb392](https://github.com/eng618/parable-bloom/commit/f3cb392))
- Adjust visual scaling of game elements including cell size, tap effects, grid dots, debug text, and projection lines. ([7a35222](https://github.com/eng618/parable-bloom/commit/7a35222))

### 🩹 Fixes

- Update GameProgress equality and hash code to include all fields and add comprehensive equality tests. ([3b22dea](https://github.com/eng618/parable-bloom/commit/3b22dea))

### ❤️ Thank You

- Eric N. Garcia @eng618

## 1.3.2 (2026-02-25)

### 🚀 Features

- Initialize Flutter workspace and integrate dependency management into the release workflow. ([78e4e03](https://github.com/eng618/parable-bloom/commit/78e4e03))
- Integrate Nx Release for automated versioning, updating release process documentation and `nx.json` configuration. ([cf98382](https://github.com/eng618/parable-bloom/commit/cf98382))
- Introduce 'build' version specifier in the release workflow, enhancing the version script to always increment build numbers and improve version string parsing. ([bebfd99](https://github.com/eng618/parable-bloom/commit/bebfd99))
- replace stylized grid with a `cross.png` image asset on the home screen. ([ecdcc25](https://github.com/eng618/parable-bloom/commit/ecdcc25))
- Add large vine head assets and update spritesheet generation to include separation and correct joint alignment for heads and tails. ([6321d05](https://github.com/eng618/parable-bloom/commit/6321d05))
- Add user-configurable board zoom setting with persistence and camera integration. ([ce4767f](https://github.com/eng618/parable-bloom/commit/ce4767f))
- Conditionally skip Firebase deployment steps if the `FIREBASE_SERVICE_ACCOUNT_KEY` secret is missing. ([2d96517](https://github.com/eng618/parable-bloom/commit/2d96517))
- Automatically enable cloud sync on user authentication, improve AuthScreen error handling, and add comprehensive auth tests and documentation. ([34507c1](https://github.com/eng618/parable-bloom/commit/34507c1))
- Enable Dependabot for Go and npm, and configure Firebase preview deployments with `--no-authorized-domains` to address auth sync warnings. ([01a6a7b](https://github.com/eng618/parable-bloom/commit/01a6a7b))
- Implement Nx caching for build and test tasks, enhancing CI performance and documenting its usage. ([18c4f32](https://github.com/eng618/parable-bloom/commit/18c4f32))
- Add scripts to generate geometric and assemble classic vine spritesheets, and update documentation. ([369108d](https://github.com/eng618/parable-bloom/commit/369108d))
- overhaul ui: ([b5ec1a4](https://github.com/eng618/parable-bloom/commit/b5ec1a4))
- update app icon ([bf35eac](https://github.com/eng618/parable-bloom/commit/bf35eac))
- Add Trellis vine style and a setting to toggle between Classic and Trellis visuals. ([2f6eeda](https://github.com/eng618/parable-bloom/commit/2f6eeda))
- Implement sprite-based rendering for game backgrounds and vine components. ([61e7d8c](https://github.com/eng618/parable-bloom/commit/61e7d8c))
- Add radiating tap effects, integrate Firebase Crashlytics, and update site documentation. ([cfe7153](https://github.com/eng618/parable-bloom/commit/cfe7153))
- Add GitHub Actions workflows for Hugo site build and web deployment with PR previews, and update architecture documentation to reflect new CI/CD processes. ([bf56f82](https://github.com/eng618/parable-bloom/commit/bf56f82))
- Extend Firebase configuration to all platforms and centralize dummy options generation into a script. ([b0878a1](https://github.com/eng618/parable-bloom/commit/b0878a1))
- update to nx workspace ([#34](https://github.com/eng618/parable-bloom/pull/34))
- Implement Release Please for automated versioning and update existing release workflows to upload assets to published releases. ([0002bf2](https://github.com/eng618/parable-bloom/commit/0002bf2))
- Update Flutter SDK to 3.41.1, enhance Firebase repository testing mocks, add `syncFromCloud` stubs to fake repositories, and introduce a documentation agent rule. ([f722dae](https://github.com/eng618/parable-bloom/commit/f722dae))
- add documentation agent rule; refactor level builder tests by consolidating regression tests and simplifying task execution. ([9cf6544](https://github.com/eng618/parable-bloom/commit/9cf6544))
- Add self-blocking vine validation, enhance test tasks with coverage and gotestsum, and update documentation formatting and difficulty values. ([8d3395c](https://github.com/eng618/parable-bloom/commit/8d3395c))
- **gen2:** updates ([b636f5f](https://github.com/eng618/parable-bloom/commit/b636f5f))

### 🩹 Fixes

- add `isWithered` property to `VineState` and use it directly for rendering withered vines. ([ede96cb](https://github.com/eng618/parable-bloom/commit/ede96cb))
- **ci:** explicitly pass project to firebase deploy commands ([b949957](https://github.com/eng618/parable-bloom/commit/b949957))
- **ci:** restore build-hugo.yml ([2f3466f](https://github.com/eng618/parable-bloom/commit/2f3466f))
- **ci:** ensure flutter dependencies are fetched before flutterfire configure ([6e6d737](https://github.com/eng618/parable-bloom/commit/6e6d737))
- **gen:** correct validation flag and regenerate modules ([cf4ea89](https://github.com/eng618/parable-bloom/commit/cf4ea89))

### ❤️ Thank You

- Eric Garcia @eng618
- Eric N. Garcia @eng618