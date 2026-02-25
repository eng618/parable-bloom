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