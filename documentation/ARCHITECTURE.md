---
title: "Parable Bloom - Architecture & Technical Reference"
version: "5.0"
last_updated: "2026-01-10"
status: "Live"
type: "Architecture Documentation"
---

# Parable Bloom - Architecture & Technical Reference

## 1. Technology Stack

- **Framework**: Flutter 3.24+
- **Game Engine**: Flame (Rendering, Input)
- **State Management**: Riverpod (Reactive, Decoupled)
- **Local Persistence**: Hive (Key-Value Store)
- **Cloud Backend**: Firebase (Firestore, Auth) - *Planned/In-Progress*
- **Language**: Dart

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
assets/lessons/
├── lesson_1.json
├── lesson_2.json
├── lesson_3.json
├── lesson_4.json
└── lesson_5.json

Each contains: id, title, objective, instructions, learning_points, grid_size, vines

**Text Guidelines**

- Keep instructions short (1–3 brief sentences).
- Recommended max lengths: **title ≤ 80 chars**, **objective ≤ 120 chars**, **instructions ≤ 200 chars**, **each learning_point ≤ 80 chars**.
- Ensure **at least 2 learning_points** per lesson (UI expects at least two).
- Text is trimmed and validated when loading via `LessonData.fromJson`; add tests to ensure compliance.
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
lib/
├── core/               # Config, Constants, Utils
│   ├── app_theme.dart  # Centralized theme system with Material 3, brand colors, and game-specific extensions
│   └── ...
├── features/
│   ├── game/           # Flame components, Logic, UI (Main game levels)
│   ├── tutorial/       # Lessons system (separate from main game)
│   │   ├── domain/
│   │   │   └── entities/
│   │   │       ├── lesson.dart        # Lesson metadata entity
│   │   │       └── lesson_data.dart   # Rendering-ready lesson data
│   │   └── presentation/
│   │       ├── screens/
│   │       │   └── tutorial_flow_screen.dart  # Lesson progression wrapper
│   │       └── widgets/
│   │           └── lesson_preview_dialog.dart # Instructional dialog
│   ├── journal/        # Parable reader
│   └── settings/       # Settings UI
├── providers/
│   ├── game_providers.dart      # GameProgress, LevelData providers
│   └── tutorial_providers.dart  # Lesson providers (NEW)
├── services/           # Audio, Haptics, Analytics
└── shared/             # Common widgets, Themes

assets/
├── levels/             # Main game levels (44 levels)
├── lessons/            # Tutorial lessons (5 lessons) (NEW)
└── data/
    └── modules.json    # Module definitions
```
