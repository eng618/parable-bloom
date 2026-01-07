---
title: "Parable Bloom - Level System Reference"
version: "1.0"
last_updated: "2026-01-03"
status: "Active"
type: "Technical Reference"
---

# Parable Bloom - Level System Reference

## 1. Introduction

Parable Bloom uses a data-driven level system where each puzzle is defined by a JSON file. The game operates on a 2D grid coordinate system where vines (the primary game entities) occupy specific cells. The system is designed to be robust, supporting both hand-crafted levels and script-generated content.

Key concepts:

- **JSON-based**: All level data, including grid size, vine paths, and metadata, is stored in standard JSON format.
- **Grid Coordinates**: A Cartesian coordinate system (0,0 at bottom-left) defines all positions.
- **Modules**: Levels are grouped into "modules" for narrative progression, though they appear as a continuous sequence to the player.

## 2. File Structure

The level system relies on a specific directory structure within the `assets/` folder:

```text
assets/
├── data/
│   └── modules.json        # Registry of modules, level ranges, and parables
└── levels/
    ├── level_1.json        # Individual level files
    ├── level_2.json
    ├── ...
    └── level_100.json
```

- **`assets/levels/level_N.json`**: Contains the definition for a single level. Files are named sequentially.
- **`assets/data/modules.json`**: Defines the grouping of levels into modules and their associated narrative content (parables).

## 3. JSON Schemas

The schemas are divided into **Tier A (Runtime-Critical)** fields, which are required for the game to function, and **Tier B (Design Metadata)** fields, which are used for design and tooling but ignored by the runtime.

### 3.1 Level JSON Schema (`level_N.json`)

```json
{
  "$schema": "https://json-schema.org/draft/2020-12/schema",
  "title": "Parable Bloom Level",
  "type": "object",
  "properties": {
    // --- Tier A: Runtime-Critical ---
    "id": {
      "type": "integer",
      "description": "Global level ID (must match filename number)",
      "minimum": 1
    },
    "grid_size": {
      "type": "array",
      "description": "[width, height] of the grid",
      "items": { "type": "integer", "minimum": 2 },
      "minItems": 2,
      "maxItems": 2
    },
    "vines": {
      "type": "array",
      "description": "List of vine objects in the level",
      "items": { "$ref": "#/$defs/vine" },
      "minItems": 1
    },
    "max_moves": {
      "type": "integer",
      "description": "Maximum moves allowed (upper bound for solution)",
      "minimum": 1
    },
    "grace": {
      "type": "integer",
      "description": "Lives/mistakes allowed per level",
      "enum": [3, 4, 999] 
    },

    // --- Tier B: Design Metadata ---
    "name": {
      "type": "string",
      "description": "Display name of the level"
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
      "description": "Minimum moves required (optimal solution length)"
    },
    "color_scheme": {
      "type": "array",
      "items": { "type": "string" },
      "description": "List of color keys used in this level"
    },
    "mask": {
      "type": "object",
      "description": "Optional visual mask for non-rectangular shapes",
      "properties": {
        "mode": { "enum": ["hide", "show", "show-all"] },
        "points": {
          "type": "array",
          "items": {
            "oneOf": [
              { "type": "array", "items": { "type": "integer" }, "minItems": 2, "maxItems": 2 },
              { "type": "object", "properties": { "x": { "type": "integer" }, "y": { "type": "integer" } }, "required": ["x", "y"] }
            ]
          }
        }
      }
    }
  },
  "required": ["id", "grid_size", "vines", "max_moves", "grace"],

  "$defs": {
    "vine": {
      "type": "object",
      "properties": {
        "id": {
          "type": "string",
          "pattern": "^[a-zA-Z_][a-zA-Z0-9_]*$",
          "description": "Unique identifier for the vine"
        },
        "head_direction": {
          "type": "string",
          "enum": ["up", "down", "left", "right"],
          "description": "Direction the vine will move/grow"
        },
        "ordered_path": {
          "type": "array",
          "description": "Coordinates from Head (index 0) to Tail",
          "items": {
            "type": "object",
            "properties": {
              "x": { "type": "integer" },
              "y": { "type": "integer" }
            },
            "required": ["x", "y"]
          },
          "minItems": 2
        },
        "vine_color": {
          "type": "string",
          "description": "Color key (e.g., 'moss_green'). Defaults if omitted."
        }
      },
      "required": ["id", "head_direction", "ordered_path"]
    }
  }
}
```

### 3.2 Module Registry Schema (`modules.json`)

```json
{
  "type": "object",
  "properties": {
    "version": { "type": "string" },
    "modules": {
      "type": "array",
      "items": {
        "type": "object",
        "properties": {
          "id": { "type": "integer" },
          "name": { "type": "string" },
          "level_range": {
            "type": "array",
            "items": { "type": "integer" },
            "minItems": 2,
            "maxItems": 2,
            "description": "[start_level, end_level] inclusive"
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
            "required": ["title", "scripture", "content"]
          },
          "unlock_message": { "type": "string" }
        },
        "required": ["id", "name", "level_range", "parable", "unlock_message"]
      }
    }
  },
  "required": ["version", "modules"]
}
```

## 4. Coordinate System & Paths

### Grid System

- **Origin**: `(0, 0)` is the **bottom-left** corner.
- **X-axis**: Increases to the right.
- **Y-axis**: Increases upwards.
- **Bounds**: Valid coordinates are `0 <= x < width` and `0 <= y < height`.

### Path Format (`ordered_path`)

The `ordered_path` array defines the vine's geometry from **Head to Tail**.

- **Index 0**: Head position (the moving point).
- **Indices 1+**: Body segments (neck to tail).
- **Contiguity**: Each segment must be adjacent (Manhattan distance = 1) to the previous one.
- **Head Direction**: Must match the vector from `body[0]` to `head`.
  - If `head_direction` is "right", then `head.x - body[0].x == 1`.
  - If `head_direction` is "left", then `head.x - body[0].x == -1`.
  - If `head_direction` is "up", then `head.y - body[0].y == 1`.
  - If `head_direction` is "down", then `head.y - body[0].y == -1`.

**Example (Right-moving vine):**

```json
"head_direction": "right",
"ordered_path": [
  {"x": 5, "y": 0},  // Head
  {"x": 4, "y": 0},  // Body 1
  {"x": 3, "y": 0}   // Tail
]
```

*Animation logic: Head slides right (to x=6), body follows.*

## 5. Validation

Levels must pass strict validation rules to be playable. These are enforced by `scripts/validate_levels.py`.

### Tier A (Critical) Checks

1. **Structure**: All required fields (`id`, `grid_size`, `vines`, etc.) must be present and correct types.
2. **Grid Bounds**: All vine coordinates must be within `grid_size`.
3. **Path Integrity**:
    - Vines must have length >= 2.
    - Segments must be contiguous (no gaps).
    - No self-intersections.
    - `head_direction` must align with the first segment.
4. **Solvability**: The level must be solvable (no deadlocks) within the `max_moves` limit.
5. **Occupancy (Full Coverage)**:
    - **Principle**: No empty coordinates — generated levels should assign every *visible* cell to exactly one vine.
    - **Rule**: Require **100% coverage** of visible cells. If a `mask` hides cells (mode: "hide"), allow **≥99%** coverage of visible cells to permit a reserved visual cell.
    - **Rationale**: This aligns the validator and generator on a strict, unambiguous requirement: levels are full-tilings of the visible grid (no overlaps, no gaps). Validation will flag overlaps as violations and incomplete coverage as violations (or near-complete coverage as a warning when a mask is present).

### Tier B (Design) Checks

1. **Difficulty Alignment**: `complexity` and `grid_size` should match the declared `difficulty`.
2. **Solution Metrics**: `min_moves` should match the actual solver result.
3. **Color Consistency**: Used colors should be in `color_scheme`.

## 6. Tooling

- **`scripts/validate_levels.py`**: The primary validation tool. Run this to check all levels against the schema and logic rules.
  - Usage: `python scripts/validate_levels.py`
- **`tool/generate_levels.dart`**: A utility for generating batch levels (useful for testing or starting points).
  - Usage: `flutter pub run tool/generate_levels.dart --count 10`

## 7. Quick Reference

### Color Palette

| Color | Hex | Usage |
| :--- | :--- | :--- |
| **Moss Green** | `#7CB342` | Primary / Foundational |
| **Sunset Orange** | `#FF9800` | Intermediate / Energy |
| **Golden Yellow** | `#FFC107` | Quick-clear / Optimism |
| **Royal Purple** | `#7C4DFF` | Complex blockers |
| **Sky Blue** | `#29B6F6` | Alternative strategy |
| **Coral Red** | `#FF6E40` | Challenging blockers |
| **Lime Green** | `#CDDC39` | Quick wins |

### Difficulty Tiers

| Tier | Grid Size | Vines | Occupancy Target |
| :--- | :--- | :--- | :--- |
| **Seedling** | 6×8 - 8×10 | 6-8 | 100% (visible cells; mask may allow 99%) |
| **Sprout** | 8×10 - 10×12 | 10-14 | 100% (visible cells; mask may allow 99%) |
| **Nurturing** | 10×14 - 12×16 | 18-28 | 100% (visible cells; mask may allow 99%) |
| **Flourishing** | 12×16 - 16×20 | 36-50 | 100% (visible cells; mask may allow 99%) |
| **Transcendent** | 16×24+ | 60+ | 100% (visible cells; mask may allow 99%) |

### Checklist

- [ ] **Occupancy**: Is the grid fully filled (100% of visible cells)? No overlaps, no empty coordinates.
- [ ] **Colors**: Are 3-5 distinct colors used?
- [ ] **Path Validity**: Are all paths contiguous with correct head directions?
- [ ] **Solvability**: Is there at least one valid first move?
- [ ] **Validation**: Does `python scripts/validate_levels.py` pass?
