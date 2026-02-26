## 1.4.2 (2026-02-26)

### 🚀 Features

- Implement user account deletion, integrate Firebase Crashlytics. ([3e6d0e9](https://github.com/eng618/parable-bloom/commit/3e6d0e9))

### ❤️ Thank You

- Eric N. Garcia @eng618

## 1.4.1 (2026-02-26)

This was a version bump only for hugo-site to align it with other projects, there were no code changes.

## 1.4.0 (2026-02-25)

### 🚀 Features

- Introduce new withered vine assets with a rotting wood effect, update the classic spritesheet, and adjust the `tapEffectLight` theme color. ([f3cb392](https://github.com/eng618/parable-bloom/commit/f3cb392))
- Dynamically fetch and increment Android build number from Google Play's internal track. ([9c437ef](https://github.com/eng618/parable-bloom/commit/9c437ef))

### ❤️ Thank You

- Eric N. Garcia @eng618

## 1.3.2 (2026-02-25)

### 🚀 Features

- Initialize Flutter workspace and integrate dependency management into the release workflow. ([78e4e03](https://github.com/eng618/parable-bloom/commit/78e4e03))
- Integrate Nx Release for automated versioning, updating release process documentation and `nx.json` configuration. ([cf98382](https://github.com/eng618/parable-bloom/commit/cf98382))
- Introduce 'build' version specifier in the release workflow, enhancing the version script to always increment build numbers and improve version string parsing. ([bebfd99](https://github.com/eng618/parable-bloom/commit/bebfd99))
- Add large vine head assets and update spritesheet generation to include separation and correct joint alignment for heads and tails. ([6321d05](https://github.com/eng618/parable-bloom/commit/6321d05))
- Add user-configurable board zoom setting with persistence and camera integration. ([ce4767f](https://github.com/eng618/parable-bloom/commit/ce4767f))
- Conditionally skip Firebase deployment steps if the `FIREBASE_SERVICE_ACCOUNT_KEY` secret is missing. ([2d96517](https://github.com/eng618/parable-bloom/commit/2d96517))
- Automatically enable cloud sync on user authentication, improve AuthScreen error handling, and add comprehensive auth tests and documentation. ([34507c1](https://github.com/eng618/parable-bloom/commit/34507c1))
- Enable Dependabot for Go and npm, and configure Firebase preview deployments with `--no-authorized-domains` to address auth sync warnings. ([01a6a7b](https://github.com/eng618/parable-bloom/commit/01a6a7b))
- Implement Nx caching for build and test tasks, enhancing CI performance and documenting its usage. ([18c4f32](https://github.com/eng618/parable-bloom/commit/18c4f32))
- Add scripts to generate geometric and assemble classic vine spritesheets, and update documentation. ([369108d](https://github.com/eng618/parable-bloom/commit/369108d))
- overhaul ui: ([b5ec1a4](https://github.com/eng618/parable-bloom/commit/b5ec1a4))
- various updated to hugo site ([9e6387c](https://github.com/eng618/parable-bloom/commit/9e6387c))
- Add Trellis vine style and a setting to toggle between Classic and Trellis visuals. ([2f6eeda](https://github.com/eng618/parable-bloom/commit/2f6eeda))
- **docs:** add 3 cards to homepage for web, android, and ios links ([55bb423](https://github.com/eng618/parable-bloom/commit/55bb423))
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
- Implement Firebase authentication with sign-in/up, anonymous access, and integrate cloud game progress synchronization on user login. ([f526856](https://github.com/eng618/parable-bloom/commit/f526856))
- Add `DEPLOY_SKIPPED` and `APP_ENV` environment variables and update `if` expression syntax in the web deploy workflow. ([ac62fcb](https://github.com/eng618/parable-bloom/commit/ac62fcb))
- Configure adaptive launcher icons for Android. ([afa35a6](https://github.com/eng618/parable-bloom/commit/afa35a6))
- Remove `path_provider_foundation` plugin from macOS, add `lb:upgrade` to general upgrade task, and update Flutter dependencies. ([c80366c](https://github.com/eng618/parable-bloom/commit/c80366c))
- Add workflow_dispatch trigger with a full_test input that overrides path filtering for job outputs. ([f6e8f2f](https://github.com/eng618/parable-bloom/commit/f6e8f2f))
- Conditionally run Codacy coverage reporter based on token presence and allow it to continue on error. ([10df26e](https://github.com/eng618/parable-bloom/commit/10df26e))
- Generate dummy Firebase options and conditionally skip deployment in CI/CD when the Firebase token is missing. ([496370a](https://github.com/eng618/parable-bloom/commit/496370a))
- Add `hugo:get` task for streamlined Hugo setup and update the Hugo site's base URL. ([e6313f7](https://github.com/eng618/parable-bloom/commit/e6313f7))
- Introduce GitHub Actions workflows for game and level builder releases, adjust Hugo's publish directory, and update gitignore. ([3ded465](https://github.com/eng618/parable-bloom/commit/3ded465))
- **level-generator:** create gen2 for better coverage, and efficient generation ([#24](https://github.com/eng618/parable-bloom/pull/24))
- Implement batch level generation and logging enhancements ([8616c80](https://github.com/eng618/parable-bloom/commit/8616c80))
- Implement direction-based growth strategy for vine placement ([3e3a6a0](https://github.com/eng618/parable-bloom/commit/3e3a6a0))
- Introduce generator presets and difficulty configurations ([66b8c3f](https://github.com/eng618/parable-bloom/commit/66b8c3f))
- **level-builder:** Add benchmarks for structural validation and solvability checks ([d89d652](https://github.com/eng618/parable-bloom/commit/d89d652))
- **level-builder:** add validation stats upload to workflows and update .gitignore ([7c6d643](https://github.com/eng618/parable-bloom/commit/7c6d643))
- **tutorial:** Implement lesson providers and progress tracking ([78ac82f](https://github.com/eng618/parable-bloom/commit/78ac82f))
- **hugo:** integrate Hugo site with configuration, content, and deployment setup ([36b4128](https://github.com/eng618/parable-bloom/commit/36b4128))
- **level-builder:** add level generation, validation, and tutorial support ([2331c07](https://github.com/eng618/parable-bloom/commit/2331c07))
- **tutorials:** Add tutorial levels and integrate into game progression ([e5a0a24](https://github.com/eng618/parable-bloom/commit/e5a0a24))
- **theme:** update shadow colors and icon styles to align with theme color scheme ([86393e9](https://github.com/eng618/parable-bloom/commit/86393e9))
- **theme:** integrate dynamic color support and enhance color management ([1b644a6](https://github.com/eng618/parable-bloom/commit/1b644a6))
- update level design principles and validation to enforce full coverage occupancy ([662f7ad](https://github.com/eng618/parable-bloom/commit/662f7ad))
- replace confetti with pond ripple and ripple fireworks effects for celebrations ([d42761c](https://github.com/eng618/parable-bloom/commit/d42761c))
- **release:** add macOS and iOS build configurations to the release workflow ([a1a49ae](https://github.com/eng618/parable-bloom/commit/a1a49ae))
- **release:** add steps to download Linux and Windows builds before creating a release ([43ce264](https://github.com/eng618/parable-bloom/commit/43ce264))
- **release:** setup auto releases ([#18](https://github.com/eng618/parable-bloom/pull/18))
- **game:** implement tap effect visuals and update theme color management ([#16](https://github.com/eng618/parable-bloom/issues/16))
- **analytics:** add game analytics and tap tracking ([631f84a](https://github.com/eng618/parable-bloom/commit/631f84a))
- **ci:** integrate Firebase config generation in CI pipeline ([9c3856f](https://github.com/eng618/parable-bloom/commit/9c3856f))
- add Firebase web configuration with placeholder replacement ([02022af](https://github.com/eng618/parable-bloom/commit/02022af))
- **game:** add Firebase game progress repository with offline-first sync ([42dff33](https://github.com/eng618/parable-bloom/commit/42dff33))
- integrate Firebase for authentication and Firestore ([3382ce5](https://github.com/eng618/parable-bloom/commit/3382ce5))
- Add dependency injection setup and game data models ([f2da56d](https://github.com/eng618/parable-bloom/commit/f2da56d))
- add iOS and macOS build configurations with CocoaPods ([a7441a7](https://github.com/eng618/parable-bloom/commit/a7441a7))
- add confetti celebration for level completion ([7eda4a3](https://github.com/eng618/parable-bloom/commit/7eda4a3))
- Add initial game assets, levels, extensive design documentation, and update core game logic and dependencies. ([3c45e49](https://github.com/eng618/parable-bloom/commit/3c45e49))
- add Codacy CLI v2 installation script ([f48ad96](https://github.com/eng618/parable-bloom/commit/f48ad96))
- initialize Flutter game project with build tasks and components ([4bc8b1b](https://github.com/eng618/parable-bloom/commit/4bc8b1b))

### 🩹 Fixes

- **ci:** explicitly pass project to firebase deploy commands ([b949957](https://github.com/eng618/parable-bloom/commit/b949957))
- **ci:** restore build-hugo.yml ([2f3466f](https://github.com/eng618/parable-bloom/commit/2f3466f))
- **ci:** ensure flutter dependencies are fetched before flutterfire configure ([6e6d737](https://github.com/eng618/parable-bloom/commit/6e6d737))
- **gen:** correct validation flag and regenerate modules ([cf4ea89](https://github.com/eng618/parable-bloom/commit/cf4ea89))
- Ensure Firebase CI token is present in GitHub Actions workflows to prevent failures. ([c3883e3](https://github.com/eng618/parable-bloom/commit/c3883e3))
- **ci:** Change golangci-lint installation method to use go install ([4e8945a](https://github.com/eng618/parable-bloom/commit/4e8945a))
- **release:** correct paths for packaging Linux, Windows, and macOS builds ([1003794](https://github.com/eng618/parable-bloom/commit/1003794))
- **bump_version:** reset build number to 1 for version bump types ([f25e9ac](https://github.com/eng618/parable-bloom/commit/f25e9ac))
- **ci:** update deploy workflow to trigger on CI completion and adjust checkout action ([c4d646f](https://github.com/eng618/parable-bloom/commit/c4d646f))

### ❤️ Thank You

- Eric Garcia @eng618
- Eric N. Garcia @eng618