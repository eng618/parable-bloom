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
- **Control**: Users can manually adjust their preferred board zoom scale (0.5× to 2.0×) in the Settings menu at any time.

### 3. Offline-First Cloud Synchronization

- **Behavior**: Game progress is stored locally in `Hive` and synchronizes asynchronously with Cloud `Firestore` when network connectivity is detected.
- **Merge Strategy**: When an anonymous guest player signs in with a permanent account, local progress merges seamlessly with cloud progress records using maximum level completion timestamps.

---

## 🛠️ Developer Environment & Troubleshooting

### Go Level Builder Toolchain

- **Requirement**: Go `1.26.6` is the canonical version across the entire workspace.
- **Validation**: Run `task lb:test` or `task lb:build` to verify level generation tools.

### iOS CocoaPods Deployment Target (iOS 16.0)

- **Behavior**: Newer transitive Swift frameworks (e.g. `Promises`, `FirebaseSessions`) specify a minimum deployment target of iOS 16.0.
- **Configuration**: The `Podfile` automatically forces `IPHONEOS_DEPLOYMENT_TARGET = '16.0'` across all Pod targets in its `post_install` hook to prevent compilation mismatch errors.

### Headless Test Execution

- **Behavior**: In headless CI environments, Flutter widget tests and Flame component tests operate via automated test bindings without requiring physical GPU context.
- **Validation**: Execute `task validate` or `task flutter:test` to run the complete automated test suite.

---

## 📬 Reporting Issues

If you discover a bug, UI defect, or functional anomaly during development:

1. Check existing open issues on [GitHub Issues](https://github.com/eng618/parable-bloom/issues).
2. For security considerations or sensitive findings, refer to the private project security guidelines or contact the maintainers directly.
3. Open a detailed GitHub issue with reproduction steps, platform, and log outputs.
