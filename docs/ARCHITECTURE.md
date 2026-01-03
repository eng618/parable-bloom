---
title: "Parable Bloom - Architecture & Technical Reference"
version: "4.0"
last_updated: "2026-01-03"
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

## 2. State Management (Riverpod)

The application uses a reactive architecture where the UI and Game Engine observe centralized providers.

### 2.1 Core Providers

- **`moduleProgressProvider`**: Tracks the player's progress (current module, current level, unlocked parables). Persisted via Hive.
- **`vineStatesProvider`**: Manages the dynamic state of the board. It uses the `LevelSolver` to calculate which vines are blocked or free to move.
- **`graceProvider`**: Manages the "Grace" (lives) system.
- **`currentLevelProvider`**: Holds the canonical data for the active level (grid size, vine positions).
- **`gameInstanceProvider`**: Bridges the Flutter widget tree with the Flame `GardenGame` instance.

### 2.2 Logic & Solvers

- **`LevelSolver`**: A Breadth-First Search (BFS) solver that validates level solvability and determines blocking relationships.
- **Blocking Logic**: A vine is "blocked" if its path is obstructed by another vine. This is recalculated dynamically after every move.

---

## 3. Persistence Layer

### 3.1 Local-First (Hive)

We use **Hive** for immediate, offline-capable storage.

- **Boxes**: `game_progress`, `settings`.
- **Sync**: `GameProgressNotifier` writes to Hive synchronously to ensure no data loss.

### 3.2 Cloud Sync (Firebase)

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
├── features/
│   ├── game/           # Flame components, Logic, UI
│   ├── journal/        # Parable reader
│   └── menu/           # Main menu, Level selector
├── providers/          # Riverpod providers (State)
├── services/           # Audio, Haptics, Analytics
└── shared/             # Common widgets, Themes
```
