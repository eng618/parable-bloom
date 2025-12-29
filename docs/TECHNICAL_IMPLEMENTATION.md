---
title: "Parable Bloom - Technical Implementation Guide"
version: "3.4"
last_updated: "2025-12-24"
status: "Snake Mechanics & Module System Implementation Complete"
type: "Technical Documentation"
---

# Parable Bloom - Technical Implementation Guide

## Complete Development Roadmap for Solo Developer

---

## 🎯 Development Overview

**Timeline**: 4 weeks MVP, expandable to 12 weeks full launch
**Budget**: $0 (free tools: Flutter/Flame, Unity AI sprites, freesound audio)
**Team**: Solo developer
**Platforms**: iOS + Android

**Target Milestones**:

- **Week 1**: Grid/tap system ready (from existing code)
- **Week 2**: Vine slide/wilt loop implemented
- **Week 3**: 10 levels + coins/lives UI
- **Week 4**: Builds/TestFlight APK ready for feedback

---

## 📋 Development Checklist

### MVP Core Loop (Weeks 1-4)

- [ ] **Week 1**: Grid/tap system ready
  - Extend existing grid component for vine rendering
  - Add VineComponent class with head/body sprites
  - Implement basic tap detection on vines
  - Hive setup for coins/lives persistence
- [x] **Week 2**: Vine slide/wilt mechanics **COMPLETED**
  - History-based snake animation: head moves first, body follows previous segment's old position
  - Forward movement: tap triggers snake-like sliding in head direction
  - Blocked vines: animate backwards through position history to return to start
  - Clearing: continue snake movement until all segments exit grid
  - Win condition: all vines cleared
- [ ] **Week 3**: 10 levels + UI polish
  - JSON level loader for simple vine definitions
  - Coins/lives UI (HUD counters, fail overlay)
  - Auto-progression, restart/buy mercy flows
  - Stuck detection (30s hint glow)
- [ ] **Week 4**: Builds + testing
  - APK/TestFlight builds (<20MB)
  - 5-friend beta testing
  - Performance optimization (60FPS mid-range)
  - Onboarding tutorials

### Post-MVP Expansion (Optional)

- [ ] **Weeks 5-6**: Parables integration
  - JSON parable reveals on win
  - Voice/text narration
  - Scripture journal feature
- [ ] **Weeks 7-8**: PCG levels
  - Python script for 100+ procedural levels
  - Difficulty scaling, variety testing
- [ ] **Weeks 9-12**: Store launch
  - IAP for mercy packs
  - App store assets/screenshots
  - Firebase optional (progress backup)

---

## 🏗️ Technical Architecture

### Core Technologies

- **Framework**: Flutter 3.24+ with Flame game engine.
- **State Management**: **Riverpod** (centralized, reactive, and decoupled).
- **Data Storage**: **Hive** (local, high-performance persistence).
- **Backend (Roadmap)**: **Firebase** integration planned via Repository Pattern.
- **Validation**: Built-in **LevelSolver** (BFS) and automated tests.

### State Management (Riverpod)

The application follows a reactive data flow where the UI and Game Engine are consumers of centralized providers:

- `gameProgressProvider`: Persists level progression and completed levels.
- `vineStatesProvider`: Calculates real-time blocking status for all arrows using the `LevelSolver`.
- `livesProvider`: Tracks remaining lives (3 per level) and triggers Game Over state.
- `gameInstanceProvider`: Bridges the Flutter widget tree with the Flame `GardenGame` instance.

### Data Persistence (Hive)

We use Hive for immediate, local-first persistence:

- **Progress Box**: Stores current level and a set of completed level IDs.
- **Settings Box**: (Planned) for audio and visual preferences.

### Firebase Integration Roadmap

The current architecture is **Firebase Ready**. We will transition by:

1. **Repository Pattern**: Abstracting data access into a `ProgressRepository`.
2. **Offline Sync**: Using Hive as a local cache that synchronizes with Firestore in the background.
3. **Cross-Device Auth**: Implementing Firebase Auth for progress recovery across platforms.

## 🏭 Implementation Details

We have moved beyond the initial "Weeks" roadmap into a mature implementation of the core loops:

- **Infinite Level Flow**: Dynamic loading of JSON levels from `assets/levels`.
- **Bullet-Proof Logic**: Every level is automatically validated for solvability before launch.
- **History-Based Animation**: Snake-like movement where head moves first, body follows previous segment's old position. Blocked vines animate backwards through position history.
- **Bloom Effect**: Beautiful particle animation (expanding rings, central glow, sparkle particles) triggered when vines fully clear off-screen, positioned at exit location.
- **Clean Animation State Management**: Four distinct vine animation states (normal, animatingClear, animatingBlocked, cleared) ensure proper separation between blocking logic and visual animation.
- **Fluid Gameplay Optimization**: Clearable vines are immediately removed from blocking calculations when tapped, allowing other vines to be tapped without incorrect blocking during animation.
- **Minimalist UX**: Reactive visuals that provide instant feedback without noise.

#### Core Domain Entities

**`lib/domain/entities/grid_position.dart`**

```dart
class GridPosition {
  final int row;
  final int col;

  const GridPosition(this.row, this.col);

  bool isAdjacentOrthogonal(GridPosition other) {
    if (row == other.row && (col - other.col).abs() == 1) return true;
    if (col == other.col && (row - other.row).abs() == 1) return true;
    return false;
  }

  @override
  bool operator ==(Object other) =>
    identical(this, other) ||
    other is GridPosition &&
    runtimeType == other.runtimeType &&
    row == other.row &&
    col == other.col;

  @override
  int get hashCode => row.hashCode ^ col.hashCode;

  @override
  String toString() => '[$row,$col]';
}
```

**`lib/domain/entities/vine.dart`**

```dart
import 'grid_position.dart';

class Vine {
  final String id;
  final List<GridPosition> path;
  final String color;
  final List<String> blockingVines;
  final String description;

  const Vine({
    required this.id,
    required this.path,
    required this.color,
    required this.blockingVines,
    required this.description,
  });

  bool isBlocked(List<Vine> allVines) {
    for (String blockerId in blockingVines) {
      bool blockerStillExists = allVines.any((v) => v.id == blockerId);
      if (blockerStillExists) return true;
    }
    return false;
  }

  bool isTappable(List<Vine> allVines) => !isBlocked(allVines);

  @override
  String toString() => 'Vine($id, ${path.length} cells, blocked=$blockingVines)';
}
```

**`lib/domain/entities/game_board.dart`**

```dart
import 'vine.dart';
import 'grid_position.dart';

class GameBoard {
  final int rows;
  final int cols;
  final List<Vine> vines;

  const GameBoard({
    required this.rows,
    required this.cols,
    required this.vines,
  });

  List<Vine> getTappableVines() {
    return vines.where((vine) => vine.isTappable(vines)).toList();
  }

  Map<GridPosition, String> getCellOccupancy() {
    final occupancy = <GridPosition, String>{};
    for (Vine vine in vines) {
      for (GridPosition pos in vine.path) {
        if (occupancy.containsKey(pos)) {
          throw Exception('OVERLAP: Two vines at $pos');
        }
        occupancy[pos] = vine.id;
      }
    }
    return occupancy;
  }

  GameBoard clearVine(String vineId) {
    final updated = vines.where((v) => v.id != vineId).toList();
    return GameBoard(
      rows: rows,
      cols: cols,
      vines: updated,
    );
  }

  bool isComplete() => vines.isEmpty;

  Vine? getVineById(String id) {
    try {
      return vines.firstWhere((v) => v.id == id);
    } catch (e) {
      return null;
    }
  }

  Vine? getVineAtCell(GridPosition pos) {
    try {
      return vines.firstWhere((vine) => vine.path.contains(pos));
    } catch (e) {
      return null;
    }
  }
}
```

#### JSON Models & Validation

**`lib/data/models/level_model.dart`**

```dart
import 'package:parablebloom/domain/entities/vine.dart';
import 'package:parablebloom/domain/entities/grid_position.dart';

class VineModel {
  final String id;
  final String color;
  final String description;
  final List<List<int>> path;
  final List<String> blockingVines;

  const VineModel({
    required this.id,
    required this.color,
    required this.description,
    required this.path,
    required this.blockingVines,
  });

  factory VineModel.fromJson(Map<String, dynamic> json) {
    return VineModel(
      id: json['id'],
      color: json['color'],
      description: json['description'],
      path: (json['path'] as List)
          .map((p) => [p['row'] as int, p['col'] as int])
          .toList(),
      blockingVines: List<String>.from(json['blockingVines'] ?? []),
    );
  }

  Vine toDomain() {
    return Vine(
      id: id,
      path: path.map((p) => GridPosition(p[0], p[1])).toList(),
      color: color,
      blockingVines: blockingVines,
      description: description,
    );
  }
}

class ParableModel {
  final String title;
  final String scripture;
  final String content;
  final String reflection;
  final String backgroundImage;

  const ParableModel({
    required this.title,
    required this.scripture,
    required this.content,
    required this.reflection,
    required this.backgroundImage,
  });

  factory ParableModel.fromJson(Map<String, dynamic> json) {
    return ParableModel(
      title: json['title'],
      scripture: json['scripture'],
      content: json['content'],
      reflection: json['reflection'],
      backgroundImage: json['backgroundImage'],
    );
  }
}

class LevelModel {
  final String levelId;
  final int levelNumber;
  final String title;
  final int difficulty;
  final int rows;
  final int cols;
  final List<VineModel> vines;
  final ParableModel parable;
  final List<String> hints;
  final List<String> optimalSequence;
  final int optimalMoves;

  const LevelModel({
    required this.levelId,
    required this.levelNumber,
    required this.title,
    required this.difficulty,
    required this.rows,
    required this.cols,
    required this.vines,
    required this.parable,
    required this.hints,
    required this.optimalSequence,
    required this.optimalMoves,
  });

  factory LevelModel.fromJson(Map<String, dynamic> json) {
    return LevelModel(
      levelId: json['levelId'],
      levelNumber: json['levelNumber'],
      title: json['title'],
      difficulty: json['difficulty'],
      rows: json['grid']['rows'],
      cols: json['grid']['columns'],
      vines: (json['vines'] as List)
          .map((v) => VineModel.fromJson(v))
          .toList(),
      parable: ParableModel.fromJson(json['parable']),
      hints: List<String>.from(json['hints'] ?? []),
      optimalSequence: List<String>.from(json['optimalSequence'] ?? []),
      optimalMoves: json['optimalMoves'] ?? 0,
    );
  }
}
```

**`lib/data/datasources/level_validator.dart`**

```dart
import 'package:parablebloom/data/models/level_model.dart';

class LevelValidator {
  static List<String> validate(LevelModel model) {
    final errors = <String>[];

    if (!_checkNoCellOverlap(model)) {
      errors.add('ERROR: Two vines occupy same cell');
    }

    if (!_checkPathsContinuous(model)) {
      errors.add('ERROR: Path has gaps or non-orthogonal movement');
    }

    if (!_checkMinPathLength(model)) {
      errors.add('ERROR: Vine path too short (min 3 cells)');
    }

    if (!_checkNoCircularDependencies(model)) {
      errors.add('ERROR: Circular blocking dependency detected');
    }

    if (!_checkBlockingReferencesValid(model)) {
      errors.add('ERROR: Invalid vine ID in blockingVines');
    }

    if (!_checkSolvable(model)) {
      errors.add('ERROR: No vine available to clear first (unsolvable)');
    }

    return errors;
  }

  static bool _checkNoCellOverlap(LevelModel model) {
    final occupied = <String>{};
    for (VineModel vine in model.vines) {
      for (List<int> cell in vine.path) {
        final key = '${cell[0]},${cell[1]}';
        if (occupied.contains(key)) return false;
        occupied.add(key);
      }
    }
    return true;
  }

  static bool _checkPathsContinuous(LevelModel model) {
    for (VineModel vine in model.vines) {
      for (int i = 0; i < vine.path.length - 1; i++) {
        final current = vine.path[i];
        final next = vine.path[i + 1];
        final rowDiff = (current[0] - next[0]).abs();
        final colDiff = (current[1] - next[1]).abs();

        if ((rowDiff + colDiff) != 1) return false;
      }
    }
    return true;
  }

  static bool _checkMinPathLength(LevelModel model) {
    return model.vines.every((vine) => vine.path.length >= 3);
  }

  static bool _checkNoCircularDependencies(LevelModel model) {
    final blocking = <String, Set<String>>{};

    for (VineModel vine in model.vines) {
      blocking[vine.id] = Set.from(vine.blockingVines);
    }

    for (String vineId in blocking.keys) {
      if (_hasCycle(vineId, blocking, <String>{})) {
        return false;
      }
    }
    return true;
  }

  static bool _hasCycle(
    String current,
    Map<String, Set<String>> graph,
    Set<String> visited,
  ) {
    if (visited.contains(current)) return true;
    visited.add(current);

    for (String blocker in graph[current] ?? {}) {
      if (_hasCycle(blocker, graph, visited)) return true;
    }

    visited.remove(current);
    return false;
  }

  static bool _checkBlockingReferencesValid(LevelModel model) {
    final vineIds = model.vines.map((v) => v.id).toSet();
    for (VineModel vine in model.vines) {
      for (String blockerId in vine.blockingVines) {
        if (!vineIds.contains(blockerId)) return false;
      }
    }
    return true;
  }

  static bool _checkSolvable(LevelModel model) {
    return model.vines.any((vine) => vine.blockingVines.isEmpty);
  }
}
```

#### Sample Level JSON

**`assets/levels/level_001_vine_branches.json`**

```json
{
  "levelId": "level_001_vine_branches",
  "levelNumber": 1,
  "title": "The Vine & Branches",
  "difficulty": 1,
  "grid": {
    "rows": 6,
    "columns": 6
  },
  "vines": [
    {
      "id": "vine_main",
      "color": "#8B4513",
      "description": "Main vine trunk",
      "path": [
        {"row": 2, "col": 0},
        {"row": 2, "col": 1},
        {"row": 2, "col": 2}
      ],
      "blockingVines": []
    },
    {
      "id": "vine_branch_north",
      "color": "#6B8E23",
      "description": "Northern branch",
      "path": [
        {"row": 0, "col": 2},
        {"row": 1, "col": 2},
        {"row": 2, "col": 2}
      ],
      "blockingVines": ["vine_main"]
    },
    {
      "id": "vine_branch_south",
      "color": "#6B8E23",
      "description": "Southern branch",
      "path": [
        {"row": 2, "col": 2},
        {"row": 3, "col": 2},
        {"row": 4, "col": 2}
      ],
      "blockingVines": ["vine_main"]
    }
  ],
  "parable": {
    "title": "The Vine & Branches",
    "scripture": "John 15:1-5",
    "content": "I am the true vine, and my Father is the gardener. He cuts off every branch in me that bears no fruit, while every branch that does bear fruit he trims clean so that it will be even more fruitful.",
    "reflection": "How does remaining connected to Christ (the vine) produce fruit in your life?",
    "backgroundImage": "assets/parables/vine_branches.jpg"
  },
  "hints": [
    "Look for vines with no blockers—tap those first",
    "The branches are attached to the main vine",
    "Remove all branches before removing the trunk"
  ],
  "optimalSequence": ["vine_branch_north", "vine_branch_south", "vine_main"],
  "optimalMoves": 3
}
```

---

## 🎮 Game Engine Implementation (Flame)

### Basic Game Structure

**`lib/game/garden_game.dart`**

```dart
import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';

import 'components/grid_component.dart';

class GardenGame extends FlameGame
    with HasTappables, HasDraggables, HasCollisionDetection {

  static const int gridSize = 6; // 6x6 for Week 1
  static const double cellSize = 80.0; // Pixels per cell

  late GridComponent grid;

  @override
  Future<void> onLoad() async {
    await super.onLoad();

    // Load placeholder background
    final background = await loadSprite('art/grid_bg.png');
    add(SpriteComponent(
      sprite: background,
      size: size,
      position: Vector2.zero(),
    )..priority = -1);

    // Add the interactive grid
    grid = GridComponent(gridSize: gridSize, cellSize: cellSize);
    add(grid);

    // Center camera
    camera.viewport.size = size;
    camera.worldBounds = Rect.fromLTWH(0, 0, grid.width, grid.height);
  }

  @override
  Color backgroundColor() => const Color(0xFF1E3528); // Dark forest base
}
```

**`lib/game/components/grid_component.dart`**

```dart
import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flame/geometry.dart';
import 'package:flutter/material.dart';

class GridComponent extends PositionComponent
    with TapCallbacks, ParentIsA<GardenGame> {

  final int gridSize;
  final double cellSize;

  late List<List<CellComponent>> cells;

  GridComponent({required this.gridSize, required this.cellSize})
      : super(position: Vector2.zero());

  GridComponent() {
    size = Vector2(gridSize * cellSize, gridSize * cellSize);

    // Center the grid on screen
    position = Vector2(
      (game.size.x - width) / 2,
      (game.size.y - height) / 2,
    );
  }

  @override
  Future<void> onLoad() async {
    cells = [];

    for (int row = 0; row < gridSize; row++) {
      cells.add([]);
      for (int col = 0; col < gridSize; col++) {
        final cell = CellComponent(
          row: row,
          col: col,
          size: Vector2(cellSize, cellSize),
          position: Vector2(col * cellSize, row * cellSize),
        );
        add(cell);
        cells[row].add(cell);
      }
    }
  }
}

class CellComponent extends RectangleComponent
    with TapCallbacks, HasGameRef<GardenGame> {

  final int row;
  final int col;

  CellComponent({
    required this.row,
    required this.col,
    required super.size,
    required super.position,
  }) : super(
          paint: Paint()..color = Colors.transparent,
          anchor: Anchor.topLeft,
        );

  @override
  void render(Canvas canvas) {
    super.render(canvas);

    // Draw soft border
    final borderPaint = Paint()
      ..color = Colors.white24
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawRect(size.toRect(), borderPaint);

    // Optional: Debug label
    final textPainter = TextPainter(textDirection: TextDirection.ltr);
    textPainter.text = TextSpan(
      text: '$row,$col',
      style: const TextStyle(color: Colors.white38, fontSize: 14),
    );
    textPainter.layout();
    textPainter.paint(canvas, const Offset(4, 4));
  }

  @override
  bool onTapUp(TapUpInfo info) {
    // Flash feedback
    paint.color = Colors.white.withOpacity(0.3);
    Future.delayed(const Duration(milliseconds: 200), () {
      paint.color = Colors.transparent;
      update(0); // Force redraw
    });

    debugPrint('Tapped cell: ($row, $col)');
    return true;
  }
}
```

---

## 🎨 Asset Creation Guide

### Vine Sprites (Individual Segments)

**Prompt Template:**

```
PROMPT: "Mobile game asset, single vine segment for puzzle grid,
[COLOR] organic vine with subtle texture, clean vector style,
soft shadows, warm lighting, 256x256px, transparent background,
centered, minimalist design, faith-themed mobile game aesthetic,
slightly curved natural growth pattern, smooth edges, high contrast,
suitable for tile-based grid system"

VARIATIONS:
- Straight vine segment
- 90-degree corner vine segment
- T-junction vine segment
- Cross-junction vine segment

COLORS TO GENERATE:
- Rich brown (#8B4513)
- Olive green (#6B8E23)
- Deep purple (#6A5ACD)
- Burgundy red (#800020)
```

### Background Parable Illustrations

**Prompt Template:**

```
PROMPT: "Biblical parable illustration for mobile game background,
[PARABLE THEME], watercolor style with soft edges, warm color palette,
peaceful composition, suitable for text overlay, subtle depth,
spiritual atmosphere, 1080x1920px portrait orientation,
gentle lighting suggesting divine presence, culturally sensitive,
traditional biblical setting, high detail but not busy,
inspirational and contemplative mood"

EXAMPLE THEMES:
- "farmer sowing seeds in fertile field at golden hour"
- "good shepherd with sheep in rolling green hills"
- "ancient lamp glowing on wooden table in stone room"
- "vineyard with healthy grape vines and workers"
```

### Asset Specifications

| Asset Type | Dimensions | Format | Quantity Needed |
|------------|------------|--------|-----------------|
| Vine segments | 256x256px | PNG (transparent) | 16 (4 types × 4 colors) |
| Parable backgrounds | 1080x1920px | WebP/JPG | 50+ (one per level) |
| UI buttons | 128x128px | PNG (transparent) | 12 |
| Grid texture | 512x512px | PNG (tileable) | 3 variations |
| Particle effects | 32x32px × 8 frames | PNG sprite sheet | 4 effect types |
| App icon | 1024x1024px | PNG | 1 + variations |

---

## 📱 App Architecture & State Management

### Clean Architecture Overview

```
lib/
├── core/           # App-wide constants, themes, utilities
├── data/           # External data sources, models, repositories
├── domain/         # Business logic, entities, use cases
└── presentation/   # UI layer, screens, widgets, state management
```

### State Management with Provider

**Recommended Pattern**: Provider + ChangeNotifier

**Key State Classes**:

- `GameBoardState`: Manages current level, grid, vines, progress
- `ProgressionState`: Tracks completed levels, unlocked parables
- `SettingsState`: Audio, theme, accessibility preferences

### Firebase Integration (Optional)

**Services Required**:

- **Authentication**: Anonymous auth with optional email sign-in
- **Firestore**: User progress, completed levels, statistics
- **Cloud Storage**: Dynamic parable images, seasonal content
- **Analytics**: Level completion rates, difficulty balancing data

---

## 🧪 Testing Strategy

### Unit Tests

**Domain Layer**:

- Vine blocking logic validation
- Grid position adjacency checking
- Game board state transitions

**Data Layer**:

- JSON parsing accuracy
- Level validation algorithms
- Model serialization

### Widget Tests

- Grid interaction responsiveness
- Animation smoothness
- UI state updates

### Integration Tests

- Complete level playthrough
- State persistence
- Firebase sync operations

### Performance Benchmarks

- **Target**: 60 FPS gameplay (16ms frame budget)
- **Metrics**: Grid rendering, vine animations, asset loading
- **Optimization**: CustomPaint for efficient drawing, asset preloading

---

## 🚀 Deployment & Launch

### Platform Setup

**iOS Deployment**:

- Apple Developer Program ($99/year)
- Xcode setup and provisioning
- TestFlight for beta testing
- App Store Connect submission

**Android Deployment**:

- Google Play Console (one-time $25)
- APK/AAB build configuration
- Internal/Closed testing tracks
- Play Store submission

### Pre-Launch Checklist

- [ ] Performance testing on target devices
- [ ] Battery drain testing (<5%/hr)
- [ ] Accessibility compliance (WCAG 2.1 AA)
- [ ] Content review and biblical accuracy
- [ ] Privacy policy and terms of service
- [ ] App store screenshots and descriptions
- [ ] Beta testing with target audience

### Success Metrics

- **Technical**: 60 FPS, <20MB download, <5% crash rate
- **User**: 4.5+ star rating, 30% 7-day retention
- **Business**: Positive reviews, user engagement

---

## 🎬 Vine Click Animation & Grace System

### Animation Flow Overview

The vine click animation follows a **two-branch decision tree** based on whether the vine's path is clear to the edge of the grid:

#### **When Path is Clear (Vine Can Exit)**

1. **Check blocking**: Use `LevelSolver.getDistanceToBlocker()` to verify no vines block the path to grid edge
2. **Immediately clear** (technically): Remove vine from blocking calculations via `VineAnimationState.animatingClear`
   - Vine is no longer eligible to block other vines
   - Visual animation continues (vine still visible on screen)
3. **Animate off-screen**: Head-body snake animation moves vine toward grid edge, then continues beyond bounds
4. **Bloom effect**: When vine head exits visible grid (`_hasExitedVisibleGrid()`), trigger bloom animation at exit position
5. **Complete**: When last vine segment fully exits grid (`_isFullyOffScreen()`) and bloom completes, permanently remove vine

**Code Flow**:

- `handleCellTap()` → `comp.slideOut()` → Check blocking via `_calculateMovementDistance()` → Animate with `_willClearAfterAnimation=true` → `_startBloomEffect()` → `_finishAnimation()`

#### **When Path is Blocked (Vine Hits Obstacle)**

1. **Check blocking**: `LevelSolver.getDistanceToBlocker()` returns negative distance to obstacle
2. **Animate forward**: Snake animation moves head-first toward blocking vine until collision
3. **Turn red/blocked**: Vine color changes to indicate failed attempt (uses `AppTheme.vineAttemptedColor`)
4. **Mark attempted**: Call `markVineAttempted(vineId)` which:
   - Sets `hasBeenAttempted=true` flag
   - Increments `levelWrongTapsProvider` counter
   - Calls `decrementGrace()` to lose 1 heart/grace
   - Logs wrong tap analytics
5. **Reverse animation**: Play backward through position history to return to original state
6. **Complete**: Return vine to normal animation state

**Code Flow**:

- `handleCellTap()` → `comp.slideOut()` → Check blocking via `_calculateMovementDistance()` (returns negative) → Animate with `_isBlockedAnimation=true` → `markVineAttempted()` (decrments grace) → Reverse through `_positionHistory`

### Grace System (Hearts/Lives)

**Definition**: Grace is a per-level resource representing "attempts remaining". Each failed vine tap costs 1 Grace.

**Implementation**:

- **Provider**: `graceProvider` (Riverpod `NotifierProvider<GraceNotifier, int>`)
- **Initial value**: 3 per level (can be overridden in level JSON via `"grace": 4`)
- **Decrement trigger**: `GraceNotifier.decrementGrace()` called from `VineStatesNotifier.markAttempted()`
- **Visual feedback**: Grace counter displayed in UI (hearts/gems icon + number)

**Timing**:

- Grace is decremented **immediately when vine hits obstacle** (during `markVineAttempted()`)
- Happens **before** reverse animation plays (visual feedback is synchronous with game mechanic)
- If grace reaches 0, game over screen appears

**Code Locations**:

- `lib/providers/game_providers.dart`: `GraceNotifier` class (lines ~559-634)
- `lib/features/game/presentation/widgets/garden_game.dart`: `resetGrace()` called on level load
- `lib/features/game/presentation/widgets/vine_component.dart`: Animation logic (lines ~240-450)
- `lib/features/game/presentation/widgets/grid_component.dart`: Tap handler & `markVineAttempted()` call

### Vine Animation States

Four distinct animation states prevent incorrect blocking during animation:

| State | Meaning | Blocks Other Vines? | Removable? | Rendering |
|-------|---------|-------------------|-----------|-----------|
| `normal` | Default, stationary | Yes (if clear path) | No | Normal color + direction indicator |
| `animatingClear` | Sliding off-screen | **No** | Yes (immediately) | Current color, animating |
| `animatingBlocked` | Hitting obstacle, reversing | Yes | No | Red/attempted color, animating |
| `cleared` | Fully off-screen, complete | No | Yes (permanent) | Not rendered |

**Key Insight**: `animatingClear` vines don't block others, so you can tap multiple vines in sequence without stuttering.

### Color Scheme for Vine States

- **Normal**: `AppTheme.vineGreen` (default vine color)
- **Attempted**: `AppTheme.vineAttempted` (red tint, applied during blocked animation)
- **Head Direction**: Arrow indicator (right, left, up, down) rendered on head segment

### Bloom Effect Positioning

The bloom effect (expanding circles, glow, sparkles) appears at the **grid edge where the vine exits**, not at the vine head's current position:

- **Exit calculation**: When vine head crosses grid boundary, bloom is positioned at the nearest grid boundary cell
  - Head direction determines which edge: right → maxX, left → minX, up → maxY, down → minY
  - Perpendicular axis is clamped to valid grid range (e.g., if moving right and head Y goes out of bounds, Y is clamped to minY or maxY)
- **Timing**: Starts when vine head leaves visible grid (`_hasExitedVisibleGrid()`)
- **Duration**: 1 second particle animation
- **Removal**: Vine removed only when **both** bloom completes AND all segments off-screen (`_isFullyOffScreen()`)
- **Debug logs**: `_startBloomEffect()` prints bloom position for verification

---

## 🐛 Troubleshooting Common Issues

### Development Issues

**"Hot reload not working"**

- Check for syntax errors
- Restart `flutter run`
- Clear build cache: `flutter clean`

**"Assets not loading"**

- Verify `pubspec.yaml` asset paths
- Run `flutter pub get`
- Check file extensions and case sensitivity

**"Performance issues"**

- Profile with Flutter DevTools
- Optimize CustomPaint rendering
- Reduce asset sizes

### Game Logic Issues

**"Vines not clearing properly"**

- Debug `isTappable()` method
- Check blocking relationships
- Verify JSON blocking arrays

**"Grid positioning wrong"**

- Check coordinate systems (0-based vs 1-based)
- Verify Flame anchor points
- Debug camera positioning

---

## 📚 Resources & Learning

### Flutter & Flame

- **Flutter Documentation**: [flutter.dev/docs](https://flutter.dev/docs)
- **Flame Engine**: [flame-engine.org](https://flame-engine.org)
- **Clean Architecture**: [Flutter Clean Architecture Guide](https://www.raywenderlich.com/543-clean-architecture-in-flutter)

### Game Development

- **Puzzle Game Design**: [How to Design Puzzle Games](https://machinations.io/articles/how-to-design-a-puzzle-game)
- **Mobile Game Best Practices**: [Game Design Documents](https://www.getgud.io/blog/ultimate-guide-to-game-design-documents)

### Community Support

- **Flutter Discord**: [discord.gg/flutter](https://discord.gg/flutter)
- **Game Dev Communities**: Reddit r/gamedev, r/FlutterDev
- **Solo Dev Forums**: Indie game development communities

---

## 🎯 Development Timeline

### MVP Sprint (Weeks 1-4)

- **Week 1**: Grid/vine rendering foundation
- **Week 2**: Core tap-slide mechanics
- **Week 3**: Level progression & UI
- **Week 4**: Builds & beta testing

### Post-MVP Expansion (Weeks 5-12)

- **Weeks 5-6**: Parables & narrative
- **Weeks 7-8**: PCG level generation
- **Weeks 9-12**: Store launch polish

---

## 💡 Pro Tips for Solo Development

### Daily Workflow

- **Monday**: Plan week, review documentation
- **Tuesday-Thursday**: 3-4 hours focused coding
- **Friday**: Testing, commits, documentation
- **Weekends**: Strategic planning, learning

### Code Quality

- Write tests before implementation
- Commit daily (even small changes)
- Document complex logic immediately
- Refactor regularly (don't accumulate technical debt)

### Motivation & Burnout Prevention

- Celebrate small wins weekly
- Take breaks when stuck
- Join developer communities
- Remember: shipping is the goal, perfection is the enemy

---
