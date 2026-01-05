# 🌿 Parable Bloom

[![Flutter](https://img.shields.io/badge/Flutter-3.24+-02569B?style=for-the-badge&logo=flutter)](https://flutter.dev)
[![Dart](https://img.shields.io/badge/Dart-3.0+-0175C2?style=for-the-badge&logo=dart)](https://dart.dev)
[![License](https://img.shields.io/badge/License-MIT-green.svg?style=for-the-badge)](LICENSE)

[![CI](https://github.com/eng618/parable-bloom/actions/workflows/ci.yml/badge.svg)](https://github.com/eng618/parable-bloom/actions/workflows/ci.yml)

**A zen hyper-casual arrow puzzle game** with faith-based themes, where players tap directional vines to slide them off a grid in Snake-like movement. Body segments follow as a queue, and blocked vines animate back with spiritual messaging.

> *"God's grace is endless—try again!"*

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
   flutter run
   ```

### Platform-Specific Setup

**iOS Development:**

```bash
# Install iOS dependencies
flutter precache --ios
cd ios && pod install && cd ..
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

```
parable-bloom/
├── lib/                    # Flutter source code
│   ├── core/              # App-wide utilities & themes
│   ├── features/          # Feature modules
│   │   ├── game/          # Game logic & UI
│   │   └── settings/      # Settings & preferences
│   ├── providers/         # Riverpod state management
│   └── shared/            # Shared utilities
├── assets/                # Game assets & levels
│   ├── levels/            # Module-structured level JSONs
│   └── art/               # Sprites & textures
├── docs/                  # Documentation
│   ├── GAME_DESIGN.md     # Complete GDD
│   ├── ARCHITECTURE.md    # Technical architecture
│   └── TECHNICAL_IMPLEMENTATION.md
├── test/                  # Unit & integration tests
└── android/ios/           # Platform-specific code
```

### Testing

```bash
# Run all tests
flutter test

# Run specific test file
flutter test test/level_validation_test.dart

# Run integration tests
flutter test integration_test/
```

### Building for Release

**Android APK:**

```bash
flutter build apk --release
```

**iOS (requires macOS + Xcode):**

```bash
flutter build ios --release
```

## 📚 Documentation

- **[🎮 Game Design Document](docs/GAME_DESIGN.md)** - Complete mechanics, features, and design philosophy
- **[🏗️ Architecture Guide](docs/ARCHITECTURE.md)** - State management, persistence, and Firebase roadmap
- **[💻 Technical Implementation](docs/TECHNICAL_IMPLEMENTATION.md)** - Code structure, testing, and deployment
- **[📖 API Reference](https://pub.dev/documentation)** - Generated API docs
- **[🚀 Release Process](docs/RELEASE_PROCESS.md)** - Automated release and deployment guide

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
# Format code
flutter format lib/

# Analyze code
flutter analyze
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

*Made with ❤️ and Flutter*
