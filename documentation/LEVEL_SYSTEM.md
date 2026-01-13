---
title: "Parable Bloom - Level System Reference"
version: "2.0"
last_updated: "2026-01-09"
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

1. **Occupancy**: 100% of visible grid cells must be occupied by vines in their initial state. No empty spaces.
2. **Solvability**: The level must be solvable within `max_moves`.
3. **Connectivity**: All vines must be contiguous. `head_direction` must be valid.
4. **No Overlaps**: No two vine segments may share a coordinate.
5. **Text Lengths (Tutorials)**: For tutorial lessons, enforce short, readable text: **title ≤ 80 chars**, **objective ≤ 120 chars**, **instructions ≤ 200 chars**, **each learning_point ≤ 80 chars**, and **at least 2 learning_points**. These constraints are validated by `LessonData.fromJson` and covered by unit tests.

## 5. Tooling

The Go-based toolchain located in `tools/level-builder` handles all operations.

- **Clean**: `go run . clean` (Removes generated levels)
- **Generate**: `go run . generate --count 50` (Generates levels and modules.json)
- **Validate**: `go run . validate` (Checks all assets against schema and logic)
