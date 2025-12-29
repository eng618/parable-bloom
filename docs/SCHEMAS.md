---
title: "Parable Bloom - JSON Schemas & Data Structures"
version: "2.0"
last_updated: "2025-12-28"
status: "Coordinate System Refactor Complete"
type: "Schema Documentation"
---

## Parable Bloom - JSON Schemas & Data Structures

This document defines the JSON schemas for Parable Bloom's data structures, updated for the pure x,y coordinate system that eliminates row/column concepts.

---

## 📋 Updated JSON Schemas

### 1. **modules.json** - Module Registry

```json
{
  "$schema": "https://json-schema.org/draft/2020-12/schema",
  "title": "Parable Bloom Module Registry",
  "description": "Registry of all game modules with their level ranges and parable content",
  "type": "object",
  "properties": {
    "version": {
      "type": "string",
      "description": "Schema version for compatibility",
      "example": "2.0"
    },
    "modules": {
      "type": "array",
      "description": "Array of module definitions",
      "items": {
        "$ref": "#/$defs/module"
      },
      "minItems": 1
    }
  },
  "required": ["version", "modules"],

  "$defs": {
    "module": {
      "type": "object",
      "properties": {
        "id": {
          "type": "integer",
          "description": "Unique module identifier",
          "minimum": 1,
          "example": 1
        },
        "name": {
          "type": "string",
          "description": "Human-readable module name",
          "example": "The Mustard Seed"
        },
        "level_range": {
          "type": "array",
          "description": "Inclusive range of global level numbers [start, end]",
          "items": { "type": "integer" },
          "minItems": 2,
          "maxItems": 2,
          "example": [6, 20]
        },
        "parable": {
          "$ref": "#/$defs/parable"
        },
        "unlock_message": {
          "type": "string",
          "description": "Message shown when module is completed",
          "example": "Module complete! Take time to reflect on the parable."
        }
      },
      "required": ["id", "name", "level_range", "parable", "unlock_message"]
    },

    "parable": {
      "type": "object",
      "properties": {
        "title": {
          "type": "string",
          "description": "Parable title",
          "example": "The Parable of the Mustard Seed"
        },
        "scripture": {
          "type": "string",
          "description": "Bible reference",
          "example": "Matthew 13:31-32"
        },
        "content": {
          "type": "string",
          "description": "Full parable text"
        },
        "reflection": {
          "type": "string",
          "description": "Reflection question"
        },
        "background_image": {
          "type": "string",
          "description": "Asset path to parable background",
          "example": "parable_mustard_seed.jpg"
        }
      },
      "required": ["title", "scripture", "content", "reflection", "background_image"]
    }
  }
}
```

### 2. **level_{N}.json** - Individual Level Files

```json
{
  "$schema": "https://json-schema.org/draft/2020-12/schema",
  "title": "Parable Bloom Level",
  "description": "Individual level definition with coordinate-based vine placement",
  "type": "object",
  "properties": {
    "id": {
      "type": "integer",
      "description": "Global level number (sequential, 1-based)",
      "minimum": 1,
      "example": 6
    },
    "name": {
      "type": "string",
      "description": "Human-readable level name",
      "example": "First Steps"
    },
    "difficulty": {
      "type": "string",
      "description": "Difficulty tier",
      "enum": ["Tutorial", "Seedling", "Nurturing", "Flourishing", "Transcendent"],
      "example": "Seedling"
    },
    "vines": {
      "type": "array",
      "description": "Array of vine definitions with coordinate-based paths",
      "items": {
        "$ref": "#/$defs/vine"
      },
      "minItems": 1
    },
    "max_moves": {
      "type": "integer",
      "description": "Maximum allowed moves (soft limit)",
      "minimum": 1,
      "example": 5
    },
    "min_moves": {
      "type": "integer",
      "description": "Minimum moves required for optimal solution",
      "minimum": 1,
      "example": 4
    },
    "complexity": {
      "type": "string",
      "description": "Blocking relationship complexity",
      "enum": ["tutorial", "low", "medium", "high", "extreme"],
      "example": "low"
    },
    "grace": {
      "type": "integer",
      "description": "Grace points available (lives)",
      "enum": [3, 4],
      "example": 3
    }
  },
  "required": ["id", "name", "difficulty", "vines", "max_moves", "min_moves", "complexity", "grace"],

  "$defs": {
    "vine": {
      "type": "object",
      "properties": {
        "id": {
          "type": "string",
          "description": "Unique vine identifier within level",
          "pattern": "^[a-zA-Z_][a-zA-Z0-9_]*$",
          "example": "vine_1"
        },
        "head_direction": {
          "type": "string",
          "description": "Initial direction of vine head",
          "enum": ["up", "down", "left", "right"],
          "example": "right"
        },
        "ordered_path": {
          "type": "array",
          "description": "Sequence of x,y coordinates from head (index 0) to tail",
          "items": {
            "$ref": "#/$defs/coordinate"
          },
          "minItems": 2,
          "uniqueItems": true
        },
        "color": {
          "type": "string",
          "description": "Vine color theme",
          "enum": ["moss_green", "emerald", "olive", "sage"],
          "example": "moss_green"
        }
      },
      "required": ["id", "head_direction", "ordered_path", "color"]
    },

    "coordinate": {
      "type": "object",
      "description": "X,Y coordinate in world space (no grid bounds)",
      "properties": {
        "x": {
          "type": "integer",
          "description": "X coordinate (can be any integer)",
          "example": 15
        },
        "y": {
          "type": "integer",
          "description": "Y coordinate (can be any integer)",
          "example": 0
        }
      },
      "required": ["x", "y"]
    }
  }
}

### 3. **Visual Masking (hide/show)**

To support shaped visual effects (for example: smiley faces, non-rectangular visible grids) levels may optionally include a `mask` object. The `mask` only affects rendering of grid points — it does not change movement, collision, or solver logic which operate on the full rectangular grid defined by `grid_size` or computed bounds.

Example `mask` formats (flexible for authoring):

1) Simple hide points (recommended for sparse hidden cells):

```json
"mask": {
  "mode": "hide",
  "points": [ [2,2], [6,2], {"x":3, "y":4} ]
}
```

1) Show-only mode (useful when most points are hidden):

```json
"mask": {
  "mode": "show",
  "points": [ [4,4], [5,4], [6,4] ]
}
```

Rules & recommendations:

- `mode` may be `hide`, `show`, or `show-all` (default). `hide` lists points to hide; `show` lists points to render; `show-all` means no mask.
- `points` supports either array pairs `[x,y]` or objects `{x: <int>, y: <int>}` for author convenience.
- Keep masks visual-only unless you intentionally want hidden cells to be non-playable; changing solver/collision semantics requires explicit schema and code updates.

This approach keeps level data compact for the common case (most points visible) while allowing expressive visual shapes without changing the core rectangular grid logic.

```

---

## 🔄 Key Changes from Previous Schema

### Coordinate System Refactor

- **Retained**: `grid_size` field (kept for UI/grid bounds compatibility). Levels use coordinate-based paths and may include `grid_size` to help the client compute bounds; `grid_size` should be consistent with vine coordinates.
- **Added**: Pure x,y coordinates for vine paths (no row/column transformation required)
- **Changed**: Vines can exist at any coordinate position; clients compute dynamic bounds but may use `grid_size` when present.

### Module Structure Simplification

- **Removed**: Module directories with separate JSON files
- **Added**: Single `modules.json` registry with level ranges
- **Changed**: Level files use simple `level_{N}.json` naming

### Level Structure Streamlining

- **Removed**: `module_id` and `global_level_number` (redundant)
- **Simplified**: Single `id` field represents global level number
- **Changed**: Focus on game logic over organizational metadata

---

## 📁 File Organization

```

assets/levels/
├── modules.json          # Module registry
├── level_1.json         # Tutorial level 1
├── level_2.json         # Tutorial level 2
├── level_3.json         # Tutorial level 3
├── level_4.json         # Tutorial level 4
├── level_5.json         # Tutorial level 5
├── level_6.json         # Mustard Seed level 1
├── level_7.json         # Mustard Seed level 2
└── ...                  # Continues sequentially

```

---

## ✅ Validation Rules

### Coordinate Validation

- Vine paths must be contiguous (adjacent coordinates)
- Only orthogonal movement (up, down, left, right)
- No overlapping vine segments
- Head direction matches first path segment

### Dynamic Bounds

- Grid bounds calculated from vine coordinate ranges
- No fixed grid size constraints
- Levels can be any shape or size

### Module Validation

- Level ranges must not overlap between modules
- Level ranges must be contiguous
- All referenced levels must exist as files

---

## 📝 Example Files

### modules.json

```json
{
  "version": "2.0",
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
    },
    {
      "id": 2,
      "name": "The Mustard Seed",
      "level_range": [6, 10],
      "parable": {
        "title": "The Parable of the Mustard Seed",
        "scripture": "Matthew 13:31-32",
        "content": "He told them another parable...",
        "reflection": "How does God use small beginnings...",
        "background_image": "parable_mustard_seed.jpg"
      },
      "unlock_message": "Module complete! Take time to reflect on the parable."
    }
  ]
}
```

### level_6.json

```json
{
  "id": 6,
  "name": "First Steps",
  "difficulty": "Seedling",
  "vines": [
    {
      "id": "vine_1",
      "head_direction": "right",
      "ordered_path": [
        {"x": 4, "y": 2},
        {"x": 3, "y": 2},
        {"x": 2, "y": 2},
        {"x": 1, "y": 2},
        {"x": 0, "y": 2}
      ],
      "color": "moss_green"
    }
  ],
  "max_moves": 5,
  "min_moves": 4,
  "complexity": "low",
  "grace": 3
}
```

---

## 🛠️ Schema Benefits

### For Go Level Generator

- **Clean Input**: Simple coordinate-based level definitions
- **Validation Ready**: JSON schema validation ensures correctness
- **Flexible Layout**: No grid constraints for creative level design

### For Flutter App

- **Dynamic Bounds**: Grid size calculated from vine positions
- **Pure Coordinates**: Eliminates row/column transformation bugs
- **Scalable**: Easy to add new modules and levels

This schema supports the coordinate system refactor while maintaining clean separation between module organization and level content.
