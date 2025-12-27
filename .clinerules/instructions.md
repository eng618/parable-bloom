## Copilot / AI Agent Instructions — Parable Bloom (parable-bloom)

Be concise. Focus on the game's state, persistence, and level logic when changing code. Below are the repository-specific facts, conventions, and quick actions to make you productive immediately.

1. Big picture

- Flutter + Flame game app. UI (Flutter widgets) is separated from game logic (Flame + `LevelSolver`). See [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md).
- State is managed with Riverpod providers located under [lib/providers](lib/providers) and feature modules under [lib/features/game](lib/features/game).
- Local persistence uses Hive (initialized in [lib/main.dart](lib/main.dart)). Levels are JSON under `assets/levels/module_*`.

1. Key domain objects & locations

- Level solving & blocking logic: `LevelSolver` (see [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) and code under `lib/features/game`).
- Providers to inspect: `moduleProgressProvider`, `vineStatesProvider`, `graceProvider`, `currentLevelProvider`, `gameInstanceProvider` (described in [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md)).
- Persistence notifiers: `GameProgressNotifier` / `ModuleProgressNotifier` interact directly with Hive — prefer introducing a `ProgressRepository` abstraction for cloud sync changes.

1. Project-specific patterns and conventions

- “Local-first” design: Hive is the source-of-truth on-device. Any cloud sync (Firebase) must be implemented as an additional layer; do not remove Hive reads/writes unless migrating to repository pattern.
- Levels are module-scoped JSON assets: modify or add under `assets/levels/module_N/` and update `pubspec.yaml` assets list if adding new folders.
- Keep UI logic thin — business logic lives in Riverpod notifiers and `LevelSolver` (use providers for testability).

1. Build / test / debug commands

- Install deps: `flutter pub get` (run in repo root).
- Run app: `flutter run`.
- Run unit tests: `flutter test` or `flutter test test/level_validation_test.dart` for level logic.
- Format & analyze: `flutter format lib/` and `flutter analyze`.

1. When editing persistence or providers

- Update the provider in `lib/providers` and corresponding notifier under `lib/features/game`.
- Add a new abstraction (`ProgressRepository`) when introducing Firebase sync. Keep Hive-backed implementation (`HiveProgressRepository`) and wire it behind a provider.
- Update `docs/ARCHITECTURE.md` with a short note explaining the change and any migration steps.

1. Code style & testing expectations

- Follow Flutter style and run `flutter format` before committing.
- Add unit tests for `LevelSolver` and provider behavior (see tests in `test/` for examples).
- Avoid UI-heavy tests for core logic — prefer provider and pure-class tests.

1. Integration points & external deps

- Firebase packages are present in `pubspec.yaml` (firebase_core, cloud_firestore, firebase_auth). Any addition of packages requires a security scan (see Codacy guidance below).
- Flame is used for the game engine; `gameInstanceProvider` bridges Flame and Riverpod.

1. CI / analysis / Codacy

- After making edits to source files, run `flutter test`, `flutter analyze`, and `flutter format` locally.
- The repository also uses Codacy. If you edit files, run the Codacy CLI analyze step used by the project maintainers (the repo contains codacy logs referencing `.github/copilot-instructions.md`): maintainers expect automated analysis to be run after edits.

1. Examples to consult when implementing changes

- Provider patterns and persistence hooks: [lib/providers](lib/providers) and `GameProgressNotifier` in `lib/features/game`.
- Level data shape and assets: `assets/levels/module_1/` and `pubspec.yaml` asset entries.
- Architecture rationale: [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) and [README.md](README.md).

1. What to ask the author

- Should a migration path be created for existing Hive data when adding Firebase sync?
- Are there any platform-specific runtime constraints (e.g., iOS entitlements) to be aware of when adding cloud features?

If anything below is unclear or you want examples added (e.g., a small `ProgressRepository` stub), say which area and I'll add a targeted snippet or tests.