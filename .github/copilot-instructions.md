## Copilot / AI Agent Instructions — Parable Bloom (parable-bloom)

Be concise. Below are targeted, repository-specific instructions to get an AI coding agent productive quickly.

1. Big picture

- App: Flutter UI + Flame game engine. UI widgets live under `lib/` while canonical game logic (solver, providers) is implemented in `lib/providers/game_providers.dart`.
- `LevelSolver` (BFS) is the canonical solver and lives in `lib/providers/game_providers.dart` (legacy stub: `lib/features/game/domain/services/level_solver.dart`).
- State uses Riverpod providers (see `lib/providers/game_providers.dart` and `lib/providers/`); Hive is the on-device source-of-truth (initialized in `lib/main.dart`).
- Levels: JSON files in `assets/levels/` (e.g., `level_1.json`, `modules.json`) — update `pubspec.yaml` when adding assets.

2. Key files to open first

- `lib/providers/game_providers.dart` — `LevelSolver`, `gameInstanceProvider`, `GameProgressNotifier`, `moduleProgressProvider`, `vineStatesProvider`, `graceProvider`, `currentLevelProvider`.
- `lib/main.dart` — Hive initialization and app bootstrapping.
- `lib/features/game/presentation/widgets/garden_game.dart` — `GardenGame` integration with Flame and UI.
- `docs/ARCHITECTURE.md` and `docs/TECHNICAL_IMPLEMENTATION.md` — architecture rationale and sync patterns.

3. Quick commands (copyable)

```
flutter pub get
flutter run
flutter test test/level_validation_test.dart
flutter test
flutter format lib/
flutter analyze
```

Run a single failing test: `flutter test test/path/to_test.dart -r expanded`.

4. Project conventions and patterns

- Local-first: Hive is the primary store. Do not remove or bypass Hive reads/writes; add a `ProgressRepository` abstraction for any cloud sync and implement `HiveProgressRepository` as the default.
- Keep UI thin: move business logic into Riverpod notifiers and `LevelSolver` for testability.
- Solver is coordinate-based and canonical in `lib/providers/game_providers.dart`; prefer it over deprecated solver code.

5. Integration points & external deps

- Firebase libs exist in `pubspec.yaml` — adding dependencies requires a security scan (Codacy/Trivy) per repo policy.
- Flame integration point: `gameInstanceProvider` bridges Riverpod <-> `GardenGame` (Flame). Modifying this provider affects rendering and game lifecycle.

6. Tests & debugging tips

- Level logic: tests under `test/` (e.g., `level_validation_test.dart`, `vine_animation_test.dart`) exercise `LevelSolver` and provider behavior — run those first when changing solver/provider code.
- Logs: `LevelSolver` emits debug prints. Use `flutter test -r expanded` to see solver traces.

7. Minimal change checklist for PRs

- Update `docs/ARCHITECTURE.md` for any cross-cutting changes (persistence, provider topology, solver behavior).
- Run `flutter test`, `flutter analyze`, and `flutter format` locally.
- Run Codacy CLI analyze for edited files (repository uses Codacy checks).

Questions to ask the maintainers

- Do you want a migration utility for Hive data when introducing Firebase sync?
- Are there platform-specific constraints (iOS entitlements or Android permissions) to consider for cloud sync features?

---

## Example: Mock Repository for Testing

The repository pattern is already implemented at `lib/features/game/domain/repositories/game_progress_repository.dart`. To test without Hive, use the mock example in `test/mock_repository_example_test.dart`:

- **Mock Repository**: `MockGameProgressRepository` implements `GameProgressRepository` in-memory
- **Real Hive Tests**: See `test/hive_repository_test.dart` for integration tests
- **Firebase Impl**: `lib/features/game/data/repositories/firebase_game_progress_repository.dart`

Run the mock test: `flutter test test/mock_repository_example_test.dart`
