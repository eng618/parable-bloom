---
title: "ParableWeave - Level Design Requirements"
version: "1.0"
last_updated: "2025-12-27"
status: "Active Development"
type: "Level Design Documentation"
---

# ParableWeave - Level Design Requirements

This document outlines the formal requirements for designing levels in ParableWeave, including module structure, level validation rules, difficulty scaling, and content organization.

## 🏗️ Module Structure

### Module Organization

Levels are organized into modules for content management and parable unlocks. Modules are **internal concepts only** - users see continuous level numbering.

```
assets/levels/
├── module_1/                # Tutorial Module (5 levels)
│   ├── module.json          # Tutorial metadata and welcome content
│   ├── level_1.json         # Global level 1 - Single vine, no blocking
│   ├── level_2.json         # Global level 2 - Two vines, no blocking
│   ├── level_3.json         # Global level 3 - Two vines with blocking
│   ├── level_4.json         # Global level 4 - Three vines with blocking
│   └── level_5.json         # Global level 5 - Simple puzzle
├── module_2/                # Mustard Seed Module (15 levels)
│   ├── module.json          # Parable content for reflection
│   ├── level_1.json         # Global level 6
│   ├── level_2.json         # Global level 7
│   └── ...                  # Up to level_15.json (global levels 8-20)
├── module_3/                # Sower Module (15 levels)
│   └── ...                  # Global levels 21-35
└── ...
```

### Module JSON Schema

Each module must have a `module.json` file:

```json
{
  "id": 1,
  "name": "The Mustard Seed",
  "level_count": 15,
  "parable": {
    "title": "The Parable of the Mustard Seed",
    "scripture": "Matthew 13:31-32",
    "content": "He told them another parable: 'The kingdom of heaven is like a mustard seed, which a man took and planted in his field. Though it is the smallest of all seeds, yet when it grows, it is the largest of garden plants and becomes a tree, so that the birds come and perch in its branches.'",
    "reflection": "How does God use small beginnings to create great things in your life?",
    "background_image": "parable_mustard_seed.jpg"
  },
  "unlock_message": "Module complete! Take time to reflect on the parable."
}
```

## 🎯 Level Structure

### Level JSON Schema

Each level file must include:

```json
{
  "id": 1,
  "module_id": 1,
  "global_level_number": 1,
  "name": "First Steps",
  "grid_size": [9, 16],
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
      "color": "moss_green"
    }
  ],
  "max_moves": 5,
  "min_moves": 3,
  "complexity": "low",
  "grace": 3
}
```

### Global Level Numbering

- `global_level_number` is what users see (continuous 1, 2, 3...)
- Computed as: `(module_id - 1) * levels_per_module + id`
- Internal `id` remains 1-15 within each module
- `module_id` identifies which module the level belongs to

## 📏 Difficulty Tiers & Validation Rules

### Difficulty Parameters

| Difficulty Tier | Grid Size | Total Cells | Vine Length (Avg) | Vine Count | Max Moves | Complexity | Grace |
|-----------------|-----------|-------------|-------------------|------------|-----------|------------|-------|
| **Seedling** | 9×16 | 144 | 6-8 | 18-24 | 5-8 | Low: Linear, no interlocks | 3 |
| **Nurturing** | 12×20 | 240 | 5-7 | 34-48 | 8-12 | Medium: 1-2 interlocks | 3 |
| **Flourishing** | 16×28 | 448 | 4-6 | 75-112 | 12-18 | High: Multi-interlocks | 3 |
| **Transcendent** | 24×40 | 960 | 3-5 | 192-320 | 18+ | Extreme: Deep cycles | 4 |

### Validation Rules

#### 1. Grid Occupancy (MANDATORY)

- **Minimum 95% of grid cells must be occupied by vines** at level start
- Calculation: `(total_vine_cells / total_grid_cells) ≥ 0.95`
- Ensures dense, strategic gameplay without empty space

#### 2. Vine Path Validation

- All vine paths must be contiguous (no gaps between segments)
- Only 90-degree turns allowed (up, down, left, right movement only)
- Head direction must match the first movement direction
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
