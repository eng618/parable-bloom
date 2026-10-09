# Parable Bloom — Agent Instructions

Be concise. Prioritize solver/provider integrity, Hive-backed persistence, and level data fidelity.

## Big picture

- Flutter + Flame arrow-puzzle game. UI (Flutter widgets) is separated from game logic (Flame + `LevelSolverService`).
- Riverpod providers drive all state; Hive is the on-device source of truth; Firebase is an additional sync layer, never a replacement for Hive reads/writes.
- `LevelSolverService` (BFS, canonical) powers blocking/unblocking logic: `apps/parable-bloom/lib/features/game/domain/services/level_solver_service.dart`.

## Repository layout

- Flutter app: `apps/parable-bloom/` (lib, test, assets, pubspec.yaml).
- Web/policy site (static Next.js export): `apps/parable-bloom-site/`.
- Level builder (Go): `tools/level-builder/`.
- Docs (Diataxis): `documentation/` (`tutorials/`, `how-to/`, `reference/`, `explanation/`).
- Task entry points: `Taskfile.yml`, `Taskfile.Levels.yml`, `Taskfile.Release.yml`, `.taskfiles/`.

## Key files

- Solver: `apps/parable-bloom/lib/features/game/domain/services/level_solver_service.dart`
- Providers (feature-scoped, no single `game_providers.dart`): `apps/parable-bloom/lib/features/game/application/providers/` (`progress_providers.dart`, `solver_providers.dart`, `gameplay_state_providers.dart`, `module_providers.dart`, `camera_providers.dart`, `counter_providers.dart`); shared: `apps/parable-bloom/lib/core/providers/`
- Repo contracts: `apps/parable-bloom/lib/features/game/domain/repositories/game_progress_repository.dart`
- App init (Hive boxes + `ProviderScope`, await before `runApp`): `apps/parable-bloom/lib/main.dart`
- Flame bridge (Riverpod <-> Flame lifecycle): `apps/parable-bloom/lib/features/game/presentation/widgets/garden_game.dart`
- Architecture rationale: `documentation/explanation/architecture.md`; level system: `documentation/reference/level-system.md`

## State and persistence rules

- Authoritative flows: module progress, vine states, grace, current level, game instance — extend/override via providers, not ad-hoc globals.
- `GameProgressNotifier` / `ModuleProgressNotifier` write directly to Hive. For cloud sync, introduce `ProgressRepository` adapters (Hive + Firebase) and swap via provider override; do not delete Hive paths.
- Keep UI thin; complex logic belongs in Riverpod notifiers and `LevelSolverService`. Use the coordinate-based solver; avoid deprecated stubs.

## Level format

- Flat JSON files: `apps/parable-bloom/assets/levels/level_N.json` (plus `assets/lessons/`); pubspec assets: `assets/art/`, `assets/audio/`, `assets/data/`, `assets/levels/`, `assets/lessons/`.
- Schema: `grid_size` `[rows, cols]`, coordinate `ordered_path` with origin `(0,0)` lower-left, optional `mask` (`hide`/`show`/`show-all`, visuals only). Rectangular grids assumed; non-square allowed.
- When adding asset folders, update `apps/parable-bloom/pubspec.yaml`. Before shipping new level JSON, run `task flutter:test:levels`, `task levels:validate`, and `task levels:tutorials:validate`.

## Workflows

Prefer root Task/Nx commands over ad-hoc commands:

- `task flutter:get`, `task flutter:dev` (or `task flutter:serve:web`), `task flutter:test`, `task flutter:test:levels`, `task flutter:format`, `task flutter:analyze`
- `task validate` for cross-project checks; `bunx nx run-many -t lint test build` for all projects.

## Testing focus

- Level/solver: `apps/parable-bloom/test/level_validation_test.dart`; animation: `apps/parable-bloom/test/vine_animation_test.dart`.
- Persistence: `apps/parable-bloom/test/hive_repository_test.dart`, `apps/parable-bloom/test/mock_repository_example_test.dart`, `apps/parable-bloom/test/firebase_repository_test.dart`.
- Use provider overrides for deterministic tests. When changing persistence, add/update repository tests. Prefer provider/pure-class tests over UI-heavy tests for core logic.

## Code style

- Double quotes for strings; `const` constructors where possible; `copyWith` + `==`/`hashCode` for data classes.
- camelCase variables/methods, PascalCase classes, UPPER_SNAKE_CASE constants; snake_case files.
- Providers live in dedicated provider files; `///` docs on public APIs; brief comments on non-obvious logic.
- Clean architecture with feature-based data/domain/presentation layers; Material 3 theming centralized in `app_theme.dart`.
- Async: initialize Firebase/Hive before `runApp()`; use `async`/`await` consistently with graceful error handling.

## Documentation maintenance

- Update `documentation/` + `CHANGELOG.md` in the same commit as code changes that affect architecture, game logic, or user-facing features.
- Docs use Diataxis layout — update the matching file (`explanation/architecture.md` for state/persistence, `reference/level-system.md` for mechanics/schema) rather than stale flat paths.
- Keep code examples functional and matching the current codebase; fix cross-references; bump version/date metadata.
- Treat docs with the same rigor as code: review in PRs, verify instructions by following them.

## Quality gates

- After edits: `task flutter:test`, `task flutter:analyze`, `task flutter:format`. Keep changes small.
- New dependencies require a security scan (Trivy via Codacy).
- Codacy MCP rules (analyze after every edit, Trivy on dep changes) live in `.github/instructions/codacy.instructions.md` and are not duplicated here.
