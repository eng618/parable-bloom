# Architecture & Technical Reference

## 1. Technology Stack

- **Framework**: Flutter 3.24+
- **Game Engine**: Flame (Rendering, Input)
- **State Management**: Riverpod (Reactive, Decoupled)
- **Local Persistence**: Hive (Key-Value Store)
- **Cloud Backend**: Firebase (Firestore, Auth) - _Planned/In-Progress_
- **Languages**: Dart (App), Go 1.25+ (Level Builder CLI)
- **Minimum OS Targets**:
  - **iOS**: 16.0+
  - **macOS**: 11.0+
  - **Android**: API 21+
- **Development Tools**:
  - Level Builder CLI (`tools/level-builder/`) - Level generation, validation, debugging
  - Hugo Static Site Generator (`tools/hugo-site/`) - Documentation hosting

---

## 2. Lessons & Game Flow

### 2.1 Progressive Lessons System (NEW)

The game now features a **separate, immersive lessons system** that teaches core mechanics before players access the main game.

#### Lessons (1-5)

- **Lesson 1**: Single vine (learn selection mechanics)
- **Lesson 2**: Multiple independent vines (learn clearing multiple, any order)
- **Lesson 3**: Blocking mechanics (one vine blocks another)
- **Lesson 4**: Complex blocking chains (solve multi-vine blocking relationships)
- **Lesson 5**: Comprehensive puzzle (integrate all mechanics)

#### Features

- **Auto-progression**: Completing a lesson auto-advances to the next
- **Instructional Dialogs**: Each lesson shows objective, instructions, and learning points before gameplay
- **Separate Tracking**: Lessons tracked independently from main game levels
- **Replayable**: Players can replay lessons from Settings without losing main game progress
- **No Menu Breaks**: Seamless flow from lesson to lesson without returning to menu

#### Data Structure

```text
apps/parable-bloom/assets/lessons/
├── lesson_1.json
├── lesson_2.json
├── lesson_3.json
├── lesson_4.json
└── lesson_5.json
```

#### State Management

- **`lessonProvider`**: Loads lesson JSON by ID
- **`tutorialProgressProvider`**: Manages lesson completion state
- Persisted in `GameProgress`: `currentLesson`, `completedLessons`, `lessonCompleted`

---

## 3. State Management (Riverpod)

The application uses a reactive architecture where the UI and Game Engine observe centralized providers.

### 3.1 Core Providers

- **`gameProgressProvider`**: Tracks player progress (main game level, completed levels, lesson tracking)
- **`tutorialProgressProvider`**: Manages lesson progression and completion state
- **`moduleProgressProvider`**: Tracks the player's progress across modules. Persisted via Hive.
- **`vineStatesProvider`**: Manages the dynamic state of the board. It uses the `LevelSolver` to calculate which vines are blocked or free to move.
- **`graceProvider`**: Manages the "Grace" (lives) system.
- **`currentLevelProvider`**: Holds the canonical data for the active level (grid size, vine positions).
- **`gameInstanceProvider`**: Bridges the Flutter widget tree with the Flame `GardenGame` instance.

### 3.2 Logic & Solvers

- **`LevelSolver`**: A Breadth-First Search (BFS) solver that validates level solvability and determines blocking relationships.
- **Blocking Logic**: A vine is "blocked" if its path is obstructed by another vine. This is recalculated dynamically after every move.

---

## 4. Persistence Layer

### 4.1 Local-First (Hive)

We use **Hive** for immediate, offline-capable storage.

- **Boxes**: `game_progress`, `settings`.
- **Sync**: `GameProgressNotifier` writes to Hive synchronously to ensure no data loss.

### 4.2 Cloud Sync (Firebase)

We implement the **Repository Pattern** to support cloud synchronization without coupling the UI to Firebase.

**Interface**:

```dart
abstract class ProgressRepository {
  Future<GameProgress> loadProgress();
  Future<void> saveProgress(GameProgress progress);
}
```

**Implementations**:

- `HiveProgressRepository`: Local storage (Default).
- `FirebaseProgressRepository`: Cloud storage (Syncs when online).

---

## 4. Environment Strategy

We use a **Single Firebase Project** strategy with **Collection-Based Isolation** to manage environments without complex build flavors.

### 4.1 Collections

- **Development**: `game_progress_dev/{userId}/...`
- **Preview/Staging**: `game_progress_preview/{userId}/...`
- **Production**: `game_progress_prod/{userId}/...`

### 4.2 Configuration

The environment is determined at runtime via `EnvironmentConfig` (e.g., using `String.fromEnvironment` or `.env` files), which selects the appropriate Firestore collection suffix.

**Benefits**:

- Simplifies CI/CD (one set of credentials).
- Isolates test data from production.
- Allows easy promotion of features.

---

## 5. Directory Structure

```text
apps/
├── parable-bloom/       # Flutter Application
│   ├── lib/            # source code (core, features, providers, services, shared)
│   ├── assets/         # game assets (levels, lessons, art, data)
│   ├── test/           # platform tests
│   └── android/ios/... # platform-specific code
└── hugo-site/         # Documentation Site Source

tools/
└── level-builder/     # Go CLI tool for level generation & validation
    ├── cmd/           # Command implementations
    ├── pkg/           # Core libraries
    └── doc.go         # Tool documentation

scripts/               # Workspace-wide utility scripts
├── bump_version.dart  # Versioning logic (synced with Nx Release)
└── ...

documentation/         # Design & architecture docs
nx.json                # Nx workspace configuration
Taskfile.yml           # Root orchestration
```

### 5.1 Monorepo Path Resolution

Tools within the workspace (like the Level Builder) use a smart path resolution strategy to support both standalone and monorepo layouts. They identify the repository root by searching for marker files (`nx.json`, `bun.lock`, `pubspec.yaml`) and then resolve assets relative to the identified root, prioritizing the `apps/parable-bloom/assets` directory in monorepo structures.

---

## 6. Level Builder Tool (Go CLI)

### 6.1 Overview

The **level-builder** is a Go-based CLI tool that serves as the single source of truth for level generation, validation, and debugging. It replaces the deprecated `eng parable-bloom` CLI commands and complements the Flutter app's runtime validation.

**Purpose**: Provide fast, deterministic, and comprehensive tooling for level management without Flutter runtime overhead.

**Location**: `tools/level-builder/`

**Documentation**: See `tools/level-builder/doc.go` for comprehensive usage, examples, and architecture details.

### 6.2 Key Commands

#### Validate

```bash
# Structural + solvability checks (recommended for CI/CD)
./level-builder validate --check-solvable

# Produces validation_stats.json with detailed metrics
```

**Performance**: Validates all 44 levels in ~29ms using exact A\* solver (14-22 states per level).

**Use Cases**:

- CI/CD integration (replaces Flutter test suite for level validation)
- Pre-commit hooks for level changes
- Quality assurance before production deployment

#### Render

```bash
# Unicode visualization (arrows + box drawing)
./level-builder render --id 1 --style unicode

# ASCII visualization with coordinate labels
./level-builder render --id 1 --style ascii --coords

# Render from file path
./level-builder render --file assets/levels/level_42.json
```

**Use Cases**:

- Debugging level structure visually
- Documentation screenshots
- Quick level inspection without launching Flutter app

#### Repair

```bash
# Detect corrupted levels (dry-run)
./level-builder repair --dry-run

# Regenerate corrupted levels deterministically
./level-builder repair
```

**Determinism**: Uses seed = `level_id * 31337` to ensure reproducible repairs.

**Use Cases**:

- Recover from accidental level file corruption
- Regenerate specific levels with known seeds

#### Tutorials Validate

```bash
# Validate tutorial lesson files (alias for validate-tutorials)
./level-builder tutorials

# Validate with solvability checks
./level-builder tutorials --check-solvable
```

**Note**: Advanced solver flags like `--use-astar` and `--astar-weight` are currently only supported for main level validation. Tutorials use a standard BFS solver.

**Use Cases**:

- CI/CD integration for tutorial quality
- Pre-deployment validation of lesson changes

#### Gen2 (Transcendent Levels)

```bash
# Generate transcendent difficulty levels with circuit-board aesthetics
./level-builder gen2 --level-id 999 --grid-width 20 --grid-height 30 --vine-count 20 --max-moves 100

# Generate with specific seed for reproducibility
./level-builder gen2 --level-id 1000 --seed 12345 --overwrite

# Generate with randomized seed
./level-builder gen2 --level-id 1001 --randomize
```

**Features**:

- **Circuit-Board Aesthetics**: Vines grow from edges with winding orthogonal patterns
- **Deep Blocking Chains**: Creates complex blocking relationships (max depth 8+)
- **Configurable Coverage**: Relaxed coverage requirements (55% vs 90% for regular levels)
- **Reproducible Generation**: Seed-based generation for consistent results
- **Performance Monitoring**: Reports generation time, blocking depth, coverage metrics

**Use Cases**:

- Generate challenging transcendent difficulty levels
- Create levels with complex blocking relationships
- Prototype new level aesthetics and mechanics
- Batch generation for transcendent modules

#### Generate (⚠️ Known Issue)

```bash
# Generate levels for a specific module
./level-builder generate --module 1 --verbose

# Generate single levels with specific parameters
./level-builder generate --count 1 --difficulty Seedling --seed 42
```

**⚠️ Status**: Currently blocked by infinite loop bug in tiling algorithm. Generator repeatedly fails solvability checks. Investigation needed before production use.

**Expected Behavior (Once Fixed)**:

- Batch generation for modules (10 regular + 1 challenge level)
- Difficulty-aware parameter scaling
- Deterministic seeding for reproducibility
- Metadata tracking (complexity, min/max moves)

### 6.3 Integration with Flutter App

#### Runtime Validation (Flutter)

The Flutter app performs **lightweight runtime checks** at startup:

- Grid bounds validation
- Vine path connectivity (4-connectivity)
- No overlapping vines
- Head/neck orientation consistency

**Purpose**: Catch runtime-specific issues, ensure safe game state initialization.

**Location**: [apps/parable-bloom/test/level_validation_test.dart](../apps/parable-bloom/test/level_validation_test.dart)

#### Comprehensive Validation (Go CLI)

The level-builder performs **heavy validation** during development:

- All runtime checks from Flutter
- Circular blocking detection (DFS cycle detection)
- Exact solvability (A\* search with configurable budgets)
- Performance metrics (states explored, solve time)
- Mask validation (visible cells vs vine positions)

**Purpose**: Exhaustive quality assurance before deployment, performance benchmarking.

**Location**: `tools/level-builder/pkg/validator/`

#### Division of Responsibilities

```text
┌─────────────────────────────────────────────────────────────┐
│                    Development Time                         │
│  ┌────────────────────────────────────────────────────────┐ │
│  │ Go CLI: level-builder                                   │ │
│  │ - Generate levels (batch, module-aware)                │ │
│  │ - Comprehensive validation (structure + solvability)   │ │
│  │ - Performance benchmarking                             │ │
│  │ - CI/CD integration                                    │ │
│  │ - Debugging visualization (render)                     │ │
│  └────────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────┘
                              ↓
              (Validated JSON files committed)
                              ↓
┌─────────────────────────────────────────────────────────────┐
│                      Runtime                                │
│  ┌────────────────────────────────────────────────────────┐ │
│  │ Flutter App: Dart validation                           │ │
│  │ - Lightweight structural checks                        │ │
│  │ - Runtime safety validation                            │ │
│  │ - Smoke tests (test/level_validation_test.dart)       │ │
│  └────────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────┘
```

### 6.4 Algorithms & Performance

#### Exact A\* Solver

**Algorithm**: Breadth-First Search (BFS) with priority queue, explores vine removal sequences to find solution paths.

**Performance**:

- 44 levels validated in 29ms total
- Average: <1ms per level
- States explored: 14-22 per level
- Slowest level: Level 20 (4ms, 20 states)

**Configuration**:

- Default max states: 100,000 (configurable via `--max-states`)
- Uses exact solver for levels ≤24 vines (bit-masking)
- Falls back to heuristic for larger levels

**Comparison to Flutter Solver**:

- Go CLI: Exact A\*, exhaustive search, reports metrics
- Flutter Runtime: Greedy heuristic, fast checks, no detailed metrics

**Rationale**: Development-time validation can afford exhaustive search, runtime validation needs fast startup.

#### Structural Validation Rules

1. **Grid Bounds**: All vine cells within `[0, grid_width) x [0, grid_height)`
2. **4-Connectivity**: Each vine segment adjacent (Manhattan distance = 1) to next segment
3. **Head/Neck Orientation**: Neck must be exactly 1 cell opposite `head_direction`
4. **No Overlaps**: Each grid cell occupied by at most one vine
5. **No Self-Overlap**: No duplicate cells within a single vine's path
6. **Circular Blocking**: DFS cycle detection on blocking graph (A blocks B blocks C blocks A = invalid)
7. **Mask Consistency**: Vines only occupy visible cells (when mask mode != "show-all")

### 6.5 Migration Status

#### Deprecated (Old System)

- ❌ `eng parable-bloom generate`: Removed from eng CLI
- ❌ `eng parable-bloom validate`: Removed from eng CLI
- ⚠️ `flutter test test/level_validation_test.dart`: **Keep for runtime checks**, but heavy solvability checks moved to Go CLI

#### Active (New System)

- ✅ `level-builder validate --check-solvable`: **Production ready** (29ms for 44 levels)
- ✅ `level-builder render`: **Production ready** (unicode/ascii styles)
- ✅ `level-builder repair`: **Production ready** (0 corrupted files detected)
- ✅ `level-builder tutorials validate`: **Production ready** (all 5 lessons pass)
- ✅ `level-builder gen2`: **Production ready** (circuit-board transcendent levels)
- ❌ `level-builder generate`: **Blocked** (infinite loop bug, needs debugging)

#### CI/CD Integration Status

- ✅ **Ready**: Add `level-builder validate` to GitHub Actions, replace Dart validation
- ✅ **Ready**: Add `level-builder tutorials validate` to GitHub Actions
- ✅ **Ready**: Add `level-builder gen2` for transcendent level generation
- ✅ **Ready**: Upload `validation_stats.json` as CI artifact for performance tracking
- ❌ **Blocked**: Cannot add generation testing until generator bug fixed

**Recommended Action**: Proceed with CI/CD integration of validation/tutorials/gen2, address generator separately before full regeneration.

---

## 7. Testing & Quality Assurance
