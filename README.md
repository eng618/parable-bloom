# 🌿 Parable Bloom

[![Flutter](https://img.shields.io/badge/Flutter-3.24+-02569B?style=for-the-badge&logo=flutter)](https://flutter.dev)
[![Dart](https://img.shields.io/badge/Dart-3.0+-0175C2?style=for-the-badge&logo=dart)](https://dart.dev)
[![License](https://img.shields.io/badge/License-MIT-green.svg?style=for-the-badge)](LICENSE)

[![CI](https://github.com/eng618/parable-bloom/actions/workflows/ci.yml/badge.svg)](https://github.com/eng618/parable-bloom/actions/workflows/ci.yml)

**A zen hyper-casual arrow puzzle game** with faith-based themes, where players tap directional vines to slide them off a grid in Snake-like movement. Body segments follow as a queue, and blocked vines animate back with spiritual messaging.

> _"God's grace is endless—try again!"_

## ✨ Features

- **🐍 Snake-Like Movement**: Vines slide in head direction with body segments following as queue
- **🙏 Grace System**: 3 Grace per level (4 for Transcendent) with faith-based messaging
- **📚 Module Structure**: 5 modules with 15 levels each, unlocking spiritual parables
- **🎨 Adaptive Themes**: Light/dark mode with watercolor zen garden aesthetics
- **🎯 Strategic Depth**: Dynamic blocking where clearing one vine unblocks others
- **📱 Cross-Platform**: iOS & Android support with 60 FPS performance

## 🚀 Quick Start

### Prerequisites

- **Flutter**: 3.24+ ([Installation Guide](https://flutter.dev/docs/get-started/install))
- **Dart**: 3.0+
- **Platform Tools**: Xcode (iOS) or Android SDK (Android)

### Installation

1. **Clone the repository**

   ```bash
   git clone https://github.com/eng618/parable-bloom.git
   cd parable-bloom
   ```

2. **Install dependencies**

   ```bash
   flutter pub get
   ```

3. **Run the app**

   ```bash
   task run
   ```

### 🛠️ Development with Task

This project uses [Taskfile](https://taskfile.dev) to manage development workflows. It is highly recommended to install it:

```bash
brew install go-task
```

Common commands:

- `task setup`: Initial project setup (dependencies, etc.)
- `task run`: Run the web application
- `task test:all`: Run all tests across all modules (via `nx`)
- `task validate`: Full project health check (lint, test, build via `nx`)
- `nx run parable-bloom:build`: Build specific project
- `nx run-many -t test`: Run tests across all projects

### Platform-Specific Setup

**iOS Development:**

```bash
# Install iOS dependencies (precache + pod install)
task setup
```

**Android Development:**

```bash
# Accept Android licenses
flutter doctor --android-licenses
```

## 🎮 Gameplay

**Core Loop:**

1. **Tap** directional vines on the grid
2. **Slide** in head direction with body following as queue
3. **Clear** all vines to "bloom" the level
4. **Progress** through modules unlocking spiritual parables

**Difficulty Tiers:**

- 🌱 **Seedling**: Gentle introduction (9x9 grids)
- 🌿 **Nurturing**: Growing complexity (9x12 grids)
- 🌳 **Flourishing**: Full bloom challenges (12x16 grids)
- ✨ **Transcendent**: Eternal harmony (16x20 grids, 4 Grace)

## 🛠️ Development

### Project Structure

```text
parable-bloom/
├── apps/
│   ├── parable-bloom/       # Flutter application
│   │   ├── lib/            # Flutter source code
│   │   ├── assets/         # Game assets & levels
│   │   ├── test/           # Platform tests
│   │   └── android/ios/... # Platform-specific code
│   └── hugo-site/         # Documentation site source
├── tools/
│   └── level-builder/     # Go-based level generation tools
├── scripts/               # Workspace-wide utility scripts
├── documentation/
│   ├── GAME_DESIGN.md     # Game design document
│   └── ARCHITECTURE.md    # Technical architecture
└── nx.json                # Nx workspace configuration
```

### Testing

```bash
# Run all tests (Flutter + Tools)
task test:all
```

### Building for Release

**Multi-platform Release:**

```bash
task release:web
task release:android
task release:ios
```

**Single Component Builds (with caching):**

```bash
task build:all   # Builds Flutter web, Level Builder, and Hugo
```

## 📚 Documentation

- **[🎮 Game Design Document](documentation/GAME_DESIGN.md)** - Complete mechanics, features, and design philosophy
- **[🏗️ Architecture Guide](documentation/ARCHITECTURE.md)** - State management, persistence, and Firebase roadmap
- **[📖 API Reference](https://pub.dev/documentation)** - Generated API docs
- **[🚀 Release Process](documentation/RELEASE_PROCESS.md)** - Automated release and deployment guide

## 🤝 Contributing

We welcome contributions! Please see our [Contributing Guide](CONTRIBUTING.md) for details.

### Development Workflow

1. **Fork** the repository
2. **Create** a feature branch (`git checkout -b feature/amazing-feature`)
3. **Commit** your changes (`git commit -m 'Add amazing feature'`)
4. **Push** to the branch (`git push origin feature/amazing-feature`)
5. **Open** a Pull Request

### Code Style

This project follows the [Flutter Style Guide](https://flutter.dev/docs/development/tools/formatting). Run:

```bash
# Format and fix issues across all modules
task validate:fix

# Check for issues without fixing
task validate
```

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🙏 Acknowledgments

- **Flutter & Flame**: Amazing open-source frameworks powering this game
- **Faith Community**: For inspiration and spiritual guidance
- **Game Dev Community**: For sharing knowledge and best practices

## 📞 Support

- **Issues**: [GitHub Issues](https://github.com/eng618/parable-bloom/issues)
- **Discussions**: [GitHub Discussions](https://github.com/eng618/parable-bloom/discussions)
- **Email**: <ParableBloom@garciaericn.com>

---

_Made with ❤️ and Flutter_
