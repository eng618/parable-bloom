---
title: "Parable Bloom - Level Design Requirements"
version: "1.0"
last_updated: "2026-01-01"
status: "Active Development"
type: "Level Design Documentation"
---

# Parable Bloom - Level Design Requirements

This document outlines the formal requirements for designing levels in Parable Bloom, including module structure, level validation rules, difficulty scaling, and content organization.

## 🏗️ Module Structure

### Module Organization

Levels are organized into modules for content management and parable unlocks. Modules are **internal concepts only** — users see continuous level numbering.

Levels are stored as a single flat sequence of JSON files under `assets/levels/`:

```
assets/levels/
  level_1.json
  level_2.json
  ...
  level_100.json
  modules.json        # defines module level ranges + parables
```

Module membership is defined in `assets/levels/modules.json` via `level_range: [start, end]`.

### Module JSON Schema

Modules live in `assets/levels/modules.json`:

```json
{
  "version": "1.0",
  "modules": [
    {
      "id": 1,
      "name": "Tutorial",
      "level_range": [1, 5],
      "parable": {
        "title": "Welcome to Parable Bloom",
        "scripture": "Psalm 1:3",
        "content": "They are like a tree planted by streams of water...",
        "reflection": "Just as a tree grows strong by the water...",
        "background_image": "tutorial_welcome.jpg"
      },
      "unlock_message": "Tutorial complete! Now let's begin your parable journey."
    }
  ]
}
```

### Visual Masking (for shaped grids)

Designers may want certain grid points to be visually hidden to create shapes (smileys, silhouettes) while keeping the underlying grid rectangular for movement and solver logic. To support this, levels may include an optional `mask` object with a `mode` and `points`:

- `mode`: `hide` (list points to hide), `show` (list points to render), or `show-all` (no mask). Default: `show-all`.
- `points`: array of either two-element arrays `[x,y]` or objects `{x: <int>, y: <int>}`.

Guidelines:

- Use `hide` when most points are visible and only a few are disguised (e.g., small eyes/mouth for a smiley).
- Use `show` when most points are hidden (sparse islands).
- Keep mask visual-only unless intentionally changing gameplay semantics; modifying solver/collision to exclude masked points requires explicit implementation work.

Example:

```json
"mask": { "mode": "hide", "points": [[2,2],[6,2],{"x":3,"y":4}] }
```

## � Module Progression Pattern

### Within-Module Difficulty Curve

Each module (except Tutorial) follows a consistent difficulty progression to create narrative peaks:

```text
Module Structure (15 levels):
├─ Levels 1-5 (33%):   Seedling     ─ Gentle introduction
├─ Levels 6-10 (33%):  Nurturing    ─ Building complexity  
├─ Levels 11-14 (27%): Flourishing  ─ Advanced challenges
└─ Level 15 (7%):      Transcendent ─ Climactic finale
```

**Tutorial Module (5 levels):** All Seedling difficulty for onboarding.

**Standard Modules (15 levels):** Progressive curve ending in one Transcendent level.

**Short Modules (10 levels):** Compressed progression:

- Levels 1-3: Seedling
- Levels 4-6: Nurturing
- Levels 7-9: Flourishing
- Level 10: Transcendent

### Example: Module 2 (The Mustard Seed)

| Level | Global # | Difficulty | Grid Size | Purpose |
|-------|----------|------------|-----------|----------|
| 1-5 | 6-10 | Seedling | 6×8 to 9×16 | Introduce module theme |
| 6-10 | 11-15 | Nurturing | 9×16 to 12×20 | Build strategic thinking |
| 11-14 | 16-19 | Flourishing | 12×20 to 16×28 | Challenge mastery |
| 15 | 20 | **Transcendent** | 16×28 to 24×40 | **Module finale** |

### Design Philosophy

- **Consistent Experience:** Fixed difficulty ranges across all modules ensure predictable challenge
- **Narrative Peaks:** Each module ends with a climactic Transcendent level
- **Progressive Mastery:** Players encounter all four tiers multiple times through the game
- **Casual-Friendly:** Grid sizes remain within manageable ranges even at highest difficulty

## �📏 Grid & Coverage Requirements

### Grid Size Progression

Grid sizes must scale progressively within each module to provide a smooth difficulty curve.

### Coverage & Density

To ensure levels feel "full" and puzzle-like rather than sparse:

- **95% Visible Coverage**: Levels must occupy at least **95% of all visible (unmasked) grid cells** with vines.
- **Empty Space**: Empty cells should be rare and intentional, typically resulting from the packing algorithm rather than design choice.

### Vine Length Distribution

Vine lengths should follow a **Bell Curve distribution**:

- **Minimum Length**: 2 cells (Head + Neck).
- **Maximum Length**: Derived from grid size (approx. `(width + height) / 1.5`).
- **Distribution**: Most vines should fall in the middle of this range, creating a balanced mix of short, medium, and long vines.

## 🎯 Level Structure

### Level JSON Schema

Each level file must include:

```json
{
  "id": 1,
  "name": "First Steps",
  "grid_size": [6, 8],
  "difficulty": "Seedling",
  "vines": [
    {
      "id": "vine_1",
      "head_direction": "right",
      "ordered_path": [
        {"x": 0, "y": 0},
        {"x": 1, "y": 0},
        {"x": 2, "y": 0}
      ],
      "vine_color": "default"
    }
  ],
  "max_moves": 5,
  "min_moves": 3,
  "complexity": "low",
  "grace": 3
}
```

### Grid Aspect Ratio (Portrait-first)

To fit portrait mobile screens, keep levels on a consistent **3:4 width:height** aspect ratio.

- Recommended sizes: `6×8`, `9×12`, `12×16`, `15×20`, ...
- Larger, more difficult levels should scale **up** while keeping the same aspect ratio.
- Pinch-to-zoom support is planned for large boards so players can comfortably view dense late-game layouts.

### Global Level Numbering

- Level files use a single global `id` (1, 2, 3...).
- Module membership is defined in `assets/levels/modules.json` via `level_range`.

## 📏 Difficulty Tiers & Validation Rules

### Difficulty Parameters

| Difficulty Tier | Module Position | Grid Size | Total Cells | Vine Length (Avg) | Max Moves | Complexity | Grace |
|-----------------|-----------------|-----------|-------------|-------------------|-----------|------------|-------|
| **Seedling** | First 33% | 6×8 to 9×16 | 48-144 | 6-8 | 5-8 | Low: Linear, no interlocks | 3 |
| **Nurturing** | Next 33% | 9×16 to 12×20 | 144-240 | 4-6 | 8-12 | Medium: 1-2 interlocks | 3 |
| **Flourishing** | Next 27% | 12×20 to 16×28 | 240-448 | 3-5 | 12-18 | High: Multi-interlocks | 3 |
| **Transcendent** | Final level | 16×28 to 24×40 | 448-960 | 2-4 | 18+ | Extreme: Deep cycles | 4 |

### Validation Rules

#### 1. Grid Occupancy (MANDATORY)

- **Minimum 95% of grid cells must be occupied by vines** at level start
- Calculation: `(total_vine_cells / total_grid_cells) ≥ 0.95`
- Ensures dense, strategic gameplay without empty space

#### 2. Vine Path Validation

- All vine paths must be contiguous (no gaps between segments)
- Only 90-degree turns allowed (up, down, left, right movement only)
- `ordered_path` is head (index 0) to tail (last)
- `head_direction` indicates where the head will move next
- Therefore, the first body segment (index 1) must be exactly one cell **opposite** `head_direction`
  - Equivalent check: `(head.x - neck.x, head.y - neck.y)` must equal the unit vector for `head_direction`
- Minimum vine length: 2 segments (head + 1 body)

#### 3. Blocking Logic Validation

- No circular blocking dependencies between vines
- At least one vine must be clearable at level start (no deadlocks)
- Blocking relationships must reference valid vine IDs

#### 4. Difficulty-Specific Validation

- Vine count must be within the range for the difficulty tier
- Average vine length must match difficulty requirements
- Complexity level must match blocking depth requirements

#### 5. Solvability

- Level must be solvable using the LevelSolver BFS algorithm
- `min_moves` must be ≤ `max_moves`
- All vines must be clearable in sequence

## 🛠️ Content Creation Pipeline

### Adding a New Module

1. **Create Module Directory**: `assets/levels/module_X/`
2. **Create module.json**: Define parable content and metadata
3. **Create Level Files**: 15 level JSON files (level_1.json through level_15.json)
4. **Update pubspec.yaml**: Add new level assets
5. **Update Providers**: Adjust total level calculations if needed

### Level Design Process

1. **Choose Difficulty**: Select appropriate tier based on player progression
2. **Grid Setup**: Use specified grid size for the difficulty
3. **Vine Placement**: Place vines to achieve ≥95% occupancy
4. **Validation**: Run automated validation checks
5. **Testing**: Manual playtesting and solver verification
6. **Balance**: Adjust complexity to match difficulty parameters

### Automated Validation

Run validation on all levels:

```bash
flutter test test/level_validation_test.dart
```

Validation includes:

- JSON schema compliance
- Grid occupancy requirements
- Path continuity and blocking logic
- Difficulty parameter adherence
- Solvability verification

## 🎨 Visual & Audio Guidelines

### Vine Colors

- `moss_green`: Primary green for most vines
- `emerald`: Deeper green for contrast
- `olive`: Muted green for variety
- `sage`: Light green for accessibility

### Grid Aesthetics

- Subtle dot-based grid lines
- Adaptive colors for light/dark themes
- Smooth animations for vine movement and blocking

### Audio Cues

- Calm ambient wind sounds
- Soft chime for successful moves
- Gentle wilt sound for blocked attempts
- Celebratory bloom effect sounds

## 📊 Analytics & Balancing

### Key Metrics to Track

- Average moves per level vs. max_moves
- Level completion rates by difficulty
- Vine clearing success rates
- Player frustration points (blocked attempts)

### Balancing Guidelines

- **Seedling**: Tutorial-focused, forgiving difficulty
- **Nurturing**: Introduction of basic strategy
- **Flourishing**: Complex multi-step puzzles
- **Transcendent**: Expert-level challenges requiring deep planning

## 🔄 Future Expansion

### Planned Features

- **Shaped Grids**: Non-rectangular playing fields
- **Dynamic Elements**: Moving obstacles or changing vines
- **Time Pressure**: Optional timed challenges
- **Co-op Mode**: Multiplayer level variants

### Module Expansion

- Additional parable themes
- Seasonal content rotations
- Community-created level packs
- Progressive difficulty scaling beyond current tiers

## 🧪 Testing Requirements

### Unit Tests

- Vine blocking logic accuracy
- Level solver correctness
- JSON parsing validation
- Provider state management

### Integration Tests

- Complete level playthroughs
- Module progression logic
- Parable unlock mechanics
- UI state synchronization

### Performance Benchmarks

- Level loading times (<500ms)
- Animation smoothness (60 FPS)
- Memory usage for large grids
- Battery impact during extended play

---

## 📝 Quick Reference

### Grid Occupancy Formula

```
occupancy = (sum of all vine segment counts) / (grid_width × grid_height)
Required: occupancy ≥ 0.95
```

### Global Level Number

```
global_level = (module_id - 1) × 15 + level_id
```

### Vine Count Ranges

- **Seedling**: 18-24 vines
- **Nurturing**: 34-48 vines
- **Flourishing**: 75-112 vines
- **Transcendent**: 192-320 vines

For questions or clarifications, refer to the main documentation in `docs/README.md` or create an issue in the project repository.
