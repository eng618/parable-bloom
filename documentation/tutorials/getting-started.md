# Developer Getting Started Tutorial

Welcome to **Parable Bloom**! In this tutorial, you will set up your local development environment from scratch, launch the game, play through the progressive lessons, and run the test and validation suite.

---

## 1. Prerequisites

Before starting, ensure you have the following installed on your workstation:

- **Flutter SDK**: 3.24+ ([Flutter Installation Guide](https://flutter.dev/docs/get-started/install))
- **Dart SDK**: 3.0+ (Included with Flutter)
- **Go**: 1.25+ (Required for the `level-builder` tool)
- **Task**: Task runner for executing workspace commands ([Taskfile Installation](https://taskfile.dev/installation/))

  ```bash
  # macOS with Homebrew
  brew install go-task
  ```

- **Platform Toolchains**:
  - **iOS/macOS**: Xcode with Command Line Tools (`xcode-select --install`)
  - **Android**: Android Studio with Android SDK and licenses accepted (`flutter doctor --android-licenses`)

Verify your environment by running:

```bash
flutter doctor
```

---

## 2. Clone and Setup

1. Clone the repository:

   ```bash
   git clone https://github.com/eng618/parable-bloom.git
   cd parable-bloom
   ```

2. Run the automated workspace setup:

   ```bash
   task setup
   ```

   This will install Flutter dependencies, CocoaPods dependencies (on macOS), and prepare workspace tooling.

---

## 3. Running the Game

### Web / Desktop / Mobile

To launch the game on your preferred connected device or Chrome:

```bash
# Launch on default device (e.g. Chrome for web preview)
task run

# Or run directly via Flutter targeting a specific device
flutter run -d chrome
flutter run -d macos
flutter run -d ios
flutter run -d android
```

Once launched, you will see the welcome screen with garden aesthetics and background ambiance.

---

## 4. Playing Through the Progressive Lessons

Parable Bloom includes 5 introductory lessons that teach players the core arrow puzzle mechanics before they enter the main campaign:

1. **Lesson 1: Single Vine** — Tap a vine to slide it off the grid in the direction of its head.
2. **Lesson 2: Multiple Independent Vines** — Clear multiple free vines in any order.
3. **Lesson 3: Blocking Mechanics** — Learn how one vine can block another and how clearing one unblocks others.
4. **Lesson 4: Blocking Chains** — Trace multi-vine dependencies to find the correct clearing sequence.
5. **Lesson 5: Comprehensive Puzzle** — Put all mechanics together to achieve a full bloom.

> **Tip**: You can replay lessons anytime from the in-game Settings menu.

---

## 5. Running Tests and Level Validation

Parable Bloom has two layers of testing: Flutter widget/unit tests and the Go `level-builder` CLI solver.

1. **Run Flutter and CLI Tests**:

   ```bash
   task test:all
   ```

2. **Validate Level Files**:

   ```bash
   task levels:validate
   ```

3. **Run Full Workspace Health Check**:

   ```bash
   task validate
   ```

---

## 6. Next Steps

Now that your development environment is running, explore the rest of the documentation:

- **Need to perform a specific task?** Check the **[How-To Guides](../how-to/README.md)** (e.g. [Release Process](../how-to/release-process.md), [Level Generation](../how-to/level-generation.md)).
- **Need technical details or schemas?** Check the **[Reference Documentation](../reference/README.md)** (e.g. [Level System Reference](../reference/level-system.md), [Color Usage](../reference/color-usage.md)).
- **Want to understand architectural decisions?** Check the **[Explanations](../explanation/README.md)** (e.g. [System Architecture](../explanation/architecture.md), [Game Design Philosophy](../explanation/game-design.md)).
