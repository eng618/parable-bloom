---
title: "Parable Bloom - Level System Reference"
version: "3.0"
last_updated: "2026-01-11"
status: "Active"
type: "Technical Reference"
---

# Parable Bloom - Level System Reference

## 1. Introduction

Parable Bloom uses a strictly typed, data-driven level system. The system distinguishes between **Tutorials** (hand-crafted instructional content) and **Standard Levels** (procedurally generated or hand-tuned puzzles grouped into Modules).

Key concepts:

- **Strict Schema**: All levels must strictly adhere to the JSON schema.
- **Modules**: Levels are grouped into modules. Each module consists of a sequence of "Lesson" levels, culminating in a "Challenge" level that unlocks a Parable.
- **Separation of Concerns**: Visuals (Colors) are deterministically seeded per module but baked into level files for runtime performance.

## 2. File Structure

```text
assets/
├── data/
│   └── modules.json        # Registry of modules, progression, and parables
├── tutorials/              # Separate tutorial component
│   ├── tutorial_1.json
│   └── ...
└── levels/                 # Standard gameplay levels
    ├── level_11.json       # Start at 11 (1-10 reserved/skipped for clarity)
    ├── level_12.json
    ├── ...
    └── level_100.json
```

## 3. JSON Schemas

### 3.1 Level JSON Schema (`level_N.json`)

Applies to both `assets/levels/` and `assets/tutorials/`.

```json
{
  "$schema": "https://json-schema.org/draft/2020-12/schema",
  "title": "Parable Bloom Level",
  "type": "object",
  "properties": {
    // --- Tier A: Runtime-Critical ---
    "id": {
      "type": "integer",
      "description": "Unique Level ID. Tutorials: 1-10, Levels: 11+",
      "minimum": 1
    },
    "grid_size": {
      "type": "array",
      "description": "[width, height]",
      "items": { "type": "integer", "minimum": 2 },
      "minItems": 2,
      "maxItems": 2
    },
    "vines": {
      "type": "array",
      "items": { "$ref": "#/$defs/vine" },
      "minItems": 1
    },
    "max_moves": {
      "type": "integer",
      "description": "Strict upper bound for solution",
      "minimum": 1
    },
    "grace": {
      "type": "integer",
      "description": "Allowed mistakes",
      "enum": [3, 4, 999] 
    },
    "color_scheme": {
      "type": "array",
      "items": { "type": "string" },
      "minItems": 1,
      "description": "Hex codes for vine colors. Index corresponds to vine_index if implicit, or by key."
    },

    // --- Tier B: Design Metadata ---
    "name": {
      "type": "string"
    },
    "difficulty": {
      "type": "string",
      "enum": ["Tutorial", "Seedling", "Sprout", "Nurturing", "Flourishing", "Transcendent"]
    },
    "complexity": {
      "type": "string",
      "enum": ["tutorial", "low", "medium", "high", "extreme"]
    },
    "min_moves": {
      "type": "integer",
      "description": "Optimal solution length (verified by solver)"
    },
    "mask": {
      "type": "object",
      "description": "Optional mask for non-rectangular grids",
      "properties": {
        "mode": { "enum": ["hide", "show", "show-all"] },
        "points": {
          "type": "array",
          "items": {
            "type": "object", 
            "properties": { "x": { "type": "integer" }, "y": { "type": "integer" } }, 
            "required": ["x", "y"] 
          }
        }
      }
    }
  },
  "required": ["id", "grid_size", "vines", "max_moves", "grace", "color_scheme"],

  "$defs": {
    "vine": {
      "type": "object",
      "properties": {
        "id": { "type": "string" },
        "head_direction": {
          "type": "string",
          "enum": ["up", "down", "left", "right"]
        },
        "ordered_path": {
          "type": "array",
          "items": {
            "type": "object",
            "properties": { "x": { "type": "integer" }, "y": { "type": "integer" } },
            "required": ["x", "y"]
          },
          "minItems": 2
        },
        "color_index": {
            "type": "integer", 
            "description": "Index into color_scheme array. Defaults to 0."
        }
      },
      "required": ["id", "head_direction", "ordered_path"]
    }
  }
}
```

### 3.2 Module Registry Schema (`modules.json`)

Modules dictate the player's journey. Use a `theme_seed` to generate consistent aesthetics.

```json
{
  "type": "object",
  "properties": {
    "version": { "type": "string" },
    "tutorials": {
        "type": "array",
        "description": "List of tutorial level IDs",
        "items": { "type": "integer" }
    },
    "modules": {
      "type": "array",
      "items": {
        "type": "object",
        "properties": {
          "id": { "type": "integer" },
          "name": { "type": "string" },
          "theme_seed": { "type": "string", "description": "e.g., 'forest', 'sunset'" },
          "levels": {
            "type": "array",
            "description": "Sequence of standard 'Lesson' levels",
            "items": { "type": "integer" }
          },
          "challenge_level": {
            "type": "integer",
            "description": "The final level of the module. Tougher difficulty."
          },
          "parable": {
            "type": "object",
            "properties": {
              "title": { "type": "string" },
              "scripture": { "type": "string" },
              "content": { "type": "string" },
              "reflection": { "type": "string" },
              "background_image": { "type": "string" }
            },
            "required": ["title", "scripture"]
          },
          "unlock_message": { "type": "string" }
        },
        "required": ["id", "name", "levels", "challenge_level", "parable", "theme_seed"]
      }
    }
  },
  "required": ["version", "tutorials", "modules"]
}
```

## 4. Validation Rules

All levels must pass the strict validator in `tools/level-builder`.

1. **Coverage**: Difficulty-based coverage targets (see Section 5.1). The validator applies a **40.1% tolerance** (OccupancyTolerance) to account for adaptive generator relaxation and legacy sparse levels.
2. **Solvability**: The level must be solvable within `max_moves`. The search budget is configurable, defaulting to **2,000,000 states** for robust verification of complex puzzles.
3. **Connectivity**: All vine segments must be 4-connected (Manhattan distance = 1). `head_direction` must match head-to-neck vector.
4. **No Overlaps**: No two vine segments may share a coordinate.
5. **Minimum Length**: All vines must have at least 2 cells.
6. **No Coverage Gaps**: While 100% occupancy is not required, any cells not occupied by vines must be explicitly masked out. The validator issues a **warning** for uncovered, unmasked cells.
7. **Text Lengths (Tutorials)**: For tutorial lessons, enforce short, readable text: **title ≤ 80 chars**, **objective ≤ 120 chars**, **instructions ≤ 200 chars**, **each learning_point ≤ 80 chars**, and **at least 2 learning_points**. These constraints are validated by `LessonData.fromJson` and covered by unit tests.

## 5. Level Generation (gen2)

The `gen2` command in `tools/level-builder` is the primary level generation system. It uses a **direction-first placement algorithm** with **incremental solvability checking** and **backtracking**.

### 5.1 Difficulty Specifications

| Difficulty | Grid Size Range | Vine Count | Avg Length | Coverage Target | Grace | Complexity |
|------------|-----------------|------------|------------|-----------------|-------|------------|
| Seedling | 6×8 to 9×12 | 3-6 | 3-5 | 85% | 5 | low |
| Sprout | 9×12 to 12×16 | 5-10 | 4-6 | 80% | 4 | medium |
| Nurturing | 9×16 to 12×20 | 8-15 | 5-8 | 75% | 3 | medium |
| Flourishing | 12×20 to 16×24 | 12-20 | 6-10 | 70% | 2 | high |
| Transcendent | 16×28 to 24×40 | 15-25 | 8-12 | 60% | 1 | very_high |

### 5.2 Direction-First Placement Algorithm

The algorithm prioritizes **exit path guarantee** by selecting head direction first:

1. **Choose Head Cell**: Select an empty cell, preferably near grid edges.
2. **Choose Exit Direction**: Pick direction toward the nearest grid edge (guarantees clear path to exit).
3. **Grow Backward**: Extend the vine body in the opposite direction using random orthogonal turns.
4. **Extension Pass**: After initial placement, extend existing vines into remaining empty cells to increase coverage.
5. **Filler Vines**: Create small (2-cell) vines in isolated empty regions that cannot be reached by extension.

### 5.3 Incremental Solvability with Backtracking

Instead of restarting on unsolvable placements, gen2 uses intelligent backtracking:

1. **Check After Placement**: After each vine is placed, verify solvability using the exact A* solver.
2. **Backtrack on Failure**: If unsolvable, remove the last 3 vines (configurable) and retry with different random choices.
3. **Attempt Limit**: Maximum 10 generation attempts before reporting failure.

This approach significantly improves generation success rate compared to full restarts.

### 5.4 Color Assignment

- **Color Palette**: 6 colors shared across all difficulties (gray, green, orange, yellow, purple, blue).
- **Round-Robin Assignment**: Each vine receives `color_index` based on its position: `(vine_index % 6) + 1`.
- **Vine IDs**: Format `vine_N` where N is 1-indexed (e.g., `vine_1`, `vine_2`).

### 5.5 Example Levels

Reference examples for each difficulty tier are available in `documentation/example-levels/`:

- [seedling_example.json](example-levels/seedling_example.json) - Simple 6×8 grid, 4 vines
- [sprout_example.json](example-levels/sprout_example.json) - Medium 8×10 grid, 8 vines
- [nurturing_example.json](example-levels/nurturing_example.json) - 10×18 grid, 10 vines
- [flourishing_example.json](example-levels/flourishing_example.json) - 14×22 grid, 12 vines
- [transcendent_example.json](example-levels/transcendent_example.json) - Large 18×30 grid, 15 vines

## 6. Tooling

The Go-based toolchain located in `tools/level-builder` handles all operations.

### 6.1 Commands

- **gen2**: Primary level generation with direction-first algorithm

  ```bash
  go run . gen2 --level-id 101 --difficulty Seedling
  go run . gen2 --level-id 201 --difficulty Sprout --seed 12345
  go run . gen2 --level-id 301 --difficulty Nurturing --randomize
  ```

- **validate**: Check all assets against schema and logic

  ```bash
  go run . validate --check-solvable
  ```
  *Outputs results to `logs/validation_stats.json`.*

- **render**: Visualize levels in terminal

  ```bash
  go run . render --id 1 --style unicode
  ```

- **tutorials validate**: Validate lesson files

  ```bash
  go run . tutorials validate
  ```

### 6.2 Deprecated Commands

- **generate**: Original generation command (deprecated due to infinite loop issues with 100% coverage + solvability tension). Use `gen2` instead.
