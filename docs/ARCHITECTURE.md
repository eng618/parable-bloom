---
title: "Parable Bloom - Architecture & State Management"
version: "3.4"
last_updated: "2025-12-24"
status: "Implementation Complete"
type: "Architecture Documentation"
---

# Parable Bloom - Architecture & State Management

This document explains the current state management and persistence implementation using Riverpod and Hive, and outlines the strategy for integrating Firebase in the future.

## 🏗️ Current Architecture

### 1. State Management (Riverpod)

We use **Riverpod** for reactive state management. This decouples the game logic from the UI and allows for easy testing and debugging.

- **`moduleProgressProvider`**: Tracks current module, level within module, and completed modules with Hive persistence.
- **`vineStatesProvider`**: Manages the dynamic "blocking" logic for all vines in the current level. It uses the `LevelSolver` to calculate which vines are movable based on snake-like path movement.
- **`graceProvider`**: Manages Grace system (3 per level, 4 for Transcendent) with persistence.
- **`currentLevelProvider`**: Holds the current level data with updated JSON schema (id, module_id, name, grid_size, difficulty, vines with head_direction).
- **`gameInstanceProvider`**: Bridges Flutter UI with Flame game engine instance.
- **Transient State Providers**: Level completion, game over, and analytics tracking providers.

### 2. Local Persistence (Hive)

We use **Hive** for fast, local-first key-value storage.

- **Initialization**: Hive is initialized in `main.dart` and the `Box` is injected into the Riverpod `ProviderScope`.
- **Sync Logic**: The `GameProgressNotifier` and `ModuleProgressNotifier` handle the synchronization between the in-memory state and the Hive storage.

---

## 🔍 Validation & Technical Assessment

| Feature | Current Status | Assessment |
|---------|----------------|------------|
| **Decoupling** | High | UI components are fully isolated from the persistence layer. |
| **Logic Integrity** | Solid | The `LevelSolver` (BFS) ensures all levels are solvable and blocking is accurate. |
| **Persistence Coupling** | Moderate | `GameProgressNotifier` currently calls Hive directly. This is fine for MVP but needs abstraction for Firebase. |
| **Performance** | Excellent | Hive's synchronous reads/writes are perfect for game state without blocking the UI thread. |

---

## ☁️ Path to Firebase Integration

The current setup is "Firebase Ready" because of the use of Riverpod. To add Firebase, we will implement the **Repository Pattern**.

### Proposed Refactor for Firebase

1. **Define an Abstract Repository**:

```dart
abstract class ProgressRepository {
  Future<GameProgress> loadProgress();
  Future<void> saveProgress(GameProgress progress);
}
```

1. **Implement Hive & Firebase Repositories**:

- `HiveProgressRepository` (Local-first)
- `FirebaseProgressRepository` (Cloud sync)

1. **Update Provider**:
The `gameProgressProvider` will then depend on the `progressRepositoryProvider` instead of the Hive `Box` directly.

```mermaid
graph TD
    UI[Flutter UI] --> |watch| RP[Riverpod Provider]
    RP --> |use| GPN[GameProgressNotifier]
    GPN --> |interact| Repo[Progress Repository]
    Repo --> |impl| Hive[Hive - Local]
    Repo --> |impl| FB[Firebase - Cloud]
```

### Benefits of this Approach

- **Offline First**: Users can play without internet (Hive), and progress syncs to Firebase once online.
- **Lazy Cloud Integration**: We can launch with Hive and add the Firebase implementation later without changing a single line of UI code.
- **Cross-Platform Sync**: Users can pick up where they left off on different devices.

## 🏗️ Current Architecture

### 1. State Management (Riverpod)

We use **Riverpod** for reactive state management. This decouples the game logic from the UI and allows for easy testing and debugging.

- **`moduleProgressProvider`**: Tracks current module, level within module, and completed modules with Hive persistence.
- **`vineStatesProvider`**: Manages the dynamic "blocking" logic for all vines in the current level. It uses the `LevelSolver` to calculate which vines are movable based on snake-like path movement.
- **`graceProvider`**: Manages Grace system (3 per level, 4 for Transcendent) with persistence.
- **`currentLevelProvider`**: Holds the current level data with updated JSON schema (id, module_id, name, grid_size, difficulty, vines with head_direction).
- **`gameInstanceProvider`**: Bridges Flutter UI with Flame game engine instance.
- **Transient State Providers**: Level completion, game over, and analytics tracking providers.

### 2. Local Persistence (Hive)

We use **Hive** for fast, local-first key-value storage.

- **Initialization**: Hive is initialized in `main.dart` and the `Box` is injected into the Riverpod `ProviderScope`.
- **Sync Logic**: The `GameProgressNotifier` and `ModuleProgressNotifier` handle the synchronization between the in-memory state and the Hive storage.

---

## 🔍 Validation & Technical Assessment

| Feature | Current Status | Assessment |
|---------|----------------|------------|
| **Decoupling** | High | UI components are fully isolated from the persistence layer. |
| **Logic Integrity** | Solid | The `LevelSolver` (BFS) ensures all levels are solvable and blocking is accurate. |
| **Persistence Coupling** | Moderate | `GameProgressNotifier` currently calls Hive directly. This is fine for MVP but needs abstraction for Firebase. |
| **Performance** | Excellent | Hive's synchronous reads/writes are perfect for game state without blocking the UI thread. |

---

## ☁️ Path to Firebase Integration

The current setup is "Firebase Ready" because of the use of Riverpod. To add Firebase, we will implement the **Repository Pattern**.

### Proposed Refactor for Firebase

1. **Define an Abstract Repository**:

```dart
abstract class ProgressRepository {
  Future<GameProgress> loadProgress();
  Future<void> saveProgress(GameProgress progress);
}
```

1. **Implement Hive & Firebase Repositories**:

- `HiveProgressRepository` (Local-first)
- `FirebaseProgressRepository` (Cloud sync)

1. **Update Provider**:
The `gameProgressProvider` will then depend on the `progressRepositoryProvider` instead of the Hive `Box` directly.

```mermaid
graph TD
    UI[Flutter UI] --> |watch| RP[Riverpod Provider]
    RP --> |use| GPN[GameProgressNotifier]
    GPN --> |interact| Repo[Progress Repository]
    Repo --> |impl| Hive[Hive - Local]
    Repo --> |impl| FB[Firebase - Cloud]
```

### Benefits of this Approach

- **Offline First**: Users can play without internet (Hive), and progress syncs to Firebase once online.
- **Lazy Cloud Integration**: We can launch with Hive and add the Firebase implementation later without changing a single line of UI code.
- **Cross-Platform Sync**: Users can pick up where they left off on different devices.
