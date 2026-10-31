# 📖 Reference: Known Constraints & Platform Compatibility

This document serves as an information-oriented technical reference detailing supported platforms, runtime requirements, known operational constraints, and development troubleshooting notes for **Parable Bloom**.

---

## 📱 Supported Platforms & System Requirements

| Target Platform | Minimum OS / Runtime                                                  | Recommended Environment       | Notes                                                          |
| :-------------- | :-------------------------------------------------------------------- | :---------------------------- | :------------------------------------------------------------- |
| **iOS**         | iOS 16.0+                                                             | iPhone 12+ / iPad (10th gen+) | Hardware-accelerated Metal rendering via Flutter Flame engine. |
| **Android**     | Android 5.0 (API 21+)                                                 | Android 11+ (API 30+)         | Supports ARM64, ARMv7, and x86_64 architectures.               |
| **Web (PWA)**   | Evergreen browsers (Chrome 119+, Safari 17+, Firefox 120+, Edge 119+) | Modern desktop/tablet browser | WebGL 2.0 and WebAssembly enabled.                             |
| **macOS**       | macOS 11.0 (Big Sur)+                                                 | macOS 14 (Sonoma)+            | Apple Silicon & Intel Universal binary.                        |

---

## ⚙️ Platform Behaviors & Operational Notes

### 1. Web Audio Autoplay Policies

- **Behavior**: Modern web browsers restrict audio playback until a direct user gesture (tap/click) occurs on the document.
- **Handling**: `BackgroundAudioController` automatically buffers initialization and resumes audio playback smoothly upon the first user interaction on the canvas.

### 2. Canvas Scaling & Viewport Adaptability

- **Behavior**: Larger puzzle grids (such as the _Transcendent_ tier 16×20 boards) dynamically scale to preserve the playable area on compact mobile displays (e.g., iPhone SE or narrow aspect ratio Android devices).
- **Control**: Users can manually adjust their preferred board zoom scale multiplier (0.5× to 2.0× on fit-to-board) in the Settings menu at any time.

### 3. Offline-First Cloud Synchronization

- **Behavior**: Game progress is stored locally in `Hive` and synchronizes asynchronously with Cloud `Firestore` when network connectivity is detected.
- **Merge Strategy**: When an anonymous guest player signs in with a permanent account, local progress merges seamlessly with cloud progress records using maximum level completion timestamps.

---

## 🛠️ Developer Environment & Troubleshooting

### Go Level Builder Toolchain

- **Requirement**: Go `1.27.1` is the canonical version across the entire workspace.
- **Validation**: Run `task lb:test` or `task lb:build` to verify level generation tools.

### iOS Builds Use Swift Package Manager (2026-10)

- **Behavior**: All iOS plugins resolve through Swift Package Manager, like macOS; the CocoaPods integration (`Podfile`, `Pods/`, pod xcconfig includes) has been removed from `ios/`.
- **Deployment target**: The Runner project keeps `IPHONEOS_DEPLOYMENT_TARGET = 16.0` natively (previous Podfile `post_install` hook forced the same value per pod; no longer needed).

### iOS CocoaPods Deployment Target (iOS 16.0) — pre-2026-10 (resolved)

- **Behavior (historical)**: Newer transitive Swift frameworks (e.g. `Promises`, `FirebaseSessions`) specified a minimum deployment target of iOS 16.0, enforced via the old `Podfile` `post_install` hook. Superseded by the SPM migration: the project-level target is set natively.

### macOS Builds Use Swift Package Manager (2026-10)

- **Behavior**: All macOS plugins resolve through Swift Package Manager; the CocoaPods integration (`Podfile`, `Pods/`, pod xcconfig includes) has been removed from `macos/`.
- **Gotcha (resolved)**: The old Podfile `post_install` hook forced `MACOSX_DEPLOYMENT_TARGET = 11.0` on every pod, which modern Xcode rejects (minimum 12.0). With SPM the deployment target comes from the Runner project itself (12.0+).
- **Gotcha (resolved)**: The `FlutterFire: flutterfire upload-crashlytics-symbols` build phase derived its SPM checkout path from an Xcode `DerivedData` regex that never matches Flutter's build layout. The phase now walks up from `BUILT_PRODUCTS_DIR` to find `SourcePackages/checkouts/firebase-ios-sdk/Crashlytics/run` and skips gracefully (with a log line) when it is absent, instead of failing the build.

### Disk Pressure From Build Caches (2026-10)

- **Behavior**: Flutter iOS/macOS build trees plus SwiftPM checkouts (Firebase/gRPC) can reach 40GB+ per platform; when the data volume nears 0 free space, builds fail with `No space left on device` (`errno=28`) in unrelated-looking steps (manifest compilation, linking).
- **Recovery**: Run `task clean:all` — one shot `flutter clean`, then clears the Nx cache, Go build/test caches (`.gotmp`, `.gocache`), Next.js build output, and the level-builder binary. It prints free-space before/after. Never trust a weird build failure on a nearly-full disk: check `df -h /System/Volumes/Data` first.

### Headless Test Execution

- **Behavior**: In headless CI environments, Flutter widget tests and Flame component tests operate via automated test bindings without requiring physical GPU context.
- **Validation**: Execute `task validate` or `task flutter:test` to run the complete automated test suite.

### Android Release Build: R8 Play Core Missing Classes

- **Behavior**: `flutter build appbundle --release` runs `:app:minifyReleaseWithR8`, which fails under AGP 8.x strict mode with `Missing class com.google.android.play.core.*` referenced from the Flutter engine (`FlutterPlayStoreSplitApplication`, `PlayStoreDeferredComponentManager`). The app does not use deferred components.
- **Configuration**: `android/app/proguard-rules.pro` includes `-dontwarn com.google.android.play.core.**` to suppress these engine-only references while keeping R8 shrinking enabled. Do not add a `play:core` dependency to fix this.

### Android Release: AD_ID Permission vs Play Console Declaration

- **Behavior**: `firebase_analytics` transitively contributes `com.google.android.gms.permission.AD_ID` to the merged manifest. Google Play rejects uploads when the AAB contains this permission but the Play Console advertising-ID declaration says "No".
- **Configuration**: `android/app/src/main/AndroidManifest.xml` strips it via `tools:node="remove"` (the app serves no ads). If ad-ID usage is ever needed, update the Play Console declaration instead of removing the rule silently.

---

## 📬 Reporting Issues

If you discover a bug, UI defect, or functional anomaly during development:

1. Check existing open issues on [GitHub Issues](https://github.com/eng618/parable-bloom/issues).
2. For security considerations or sensitive findings, refer to the private project security guidelines or contact the maintainers directly.
3. Open a detailed GitHub issue with reproduction steps, platform, and log outputs.
