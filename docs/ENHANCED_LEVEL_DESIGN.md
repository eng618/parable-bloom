---
title: "Parable Bloom - Enhanced Level Design & Validation Guide"
version: "2.0"
last_updated: "2025-12-29"
status: "Active Development"
type: "Level Design Documentation"
---

# Parable Bloom - Enhanced Level Creation & Validation

This guide provides updated requirements for creating visually compelling, strategically challenging levels that match the vibrant, dense aesthetic of Parable Bloom.

## 🎨 Visual Design Principles

### Color Palette & Vine Types

Vines are categorized by color to create visual interest and help players distinguish between different puzzle elements:

| Color | Hex Code | RGB | Usage | Visual Style |
|-------|----------|-----|-------|--------------|
| **Moss Green** | `#7CB342` | (124, 179, 66) | Primary blocking vines | Calming, foundational |
| **Sunset Orange** | `#FF9800` | (255, 152, 0) | Intermediate paths | Energy, progress |
| **Golden Yellow** | `#FFC107` | (255, 193, 7) | Quick-clear vines | Optimism, movement |
| **Royal Purple** | `#7C4DFF` | (124, 77, 255) | Complex blocking chains | Mystery, strategy |
| **Sky Blue** | `#29B6F6` | (41, 182, 246) | Alternative strategy | Serenity, options |
| **Coral Red** | `#FF6E40` | (255, 110, 64) | Challenging blockers | Intensity, caution |
| **Lime Green** | `#CDDC39` | (205, 220, 57) | Quick wins | Fresh, easy relief |

### Grid Density & Visual Composition

- **95%+ Grid Occupancy**: Levels should feel full and interconnected, with minimal empty space
- **Balanced Color Distribution**: Use 3-5 colors per level to maintain visual harmony
- **Directional Arrow Variety**: Mix of all 4 directions (up, down, left, right) creates visual rhythm
- **Blocking Depth**: Create 2-4 layers of blocking relationships for strategic complexity

### Visual Layout Best Practices

✅ **DO:**

- Create connected clusters of vines by color
- Use color transitions to guide player attention
- Place longer vines around the perimeter
- Alternate colors to create a "flow" pattern
- Use contrasting colors for blocking relationships

❌ **DON'T:**

- Create isolated vines or empty regions
- Place all vines of one color together
- Use too many colors (causes visual noise)
- Create symmetric grids (feels repetitive)

## 📐 Enhanced Grid System

### Grid Size Categories

| Category | Size | Area | Vine Count | Typical Difficulty | Occupancy Target |
|----------|------|------|------------|-------------------|------------------|
| **Compact** | 6×8 | 48 | 6-8 | Seedling | 45-48 (95%+) |
| **Small** | 8×10 | 80 | 12-16 | Seedling/Nurturing | 76-80 (95%+) |
| **Medium** | 10×14 | 140 | 26-35 | Nurturing/Flourishing | 133-140 (95%+) |
| **Large** | 14×18 | 252 | 48-63 | Flourishing/Transcendent | 239-252 (95%+) |
| **Massive** | 18×24 | 432 | 82-108 | Transcendent | 410-432 (95%+) |

### Density Calculations

**Grid Occupancy Formula:**

```
occupancy = (total_vine_cells / total_grid_cells) × 100
```

**Example for 10×14 grid:**

- Total cells: 140
- Minimum occupied: 133 cells (95%)
- Available for 26-35 vines with average length 4-5

## 🎯 Enhanced Difficulty Framework

### Difficulty Tiers (Updated)

| Tier | Grid Size | Vine Count | Avg Length | Complexity | Blocking Depth | Player Intent |
|------|-----------|-----------|-----------|-----------|---|---|
| **Seedling** | 6×8 to 8×10 | 6-8 | 6-8 | Linear, no loops | 0-1 | Learn mechanics |
| **Sprout** | 8×10 to 10×12 | 10-14 | 5-7 | Simple chains | 1-2 | Practice sequences |
| **Nurturing** | 10×14 to 12×16 | 18-28 | 4-6 | Multi-chains | 2-3 | Strategy intro |
| **Flourishing** | 12×16 to 16×20 | 36-50 | 3-5 | Deep blocking | 3-4 | Complex puzzles |
| **Transcendent** | 16×24+ | 60+ | 2-4 | Cascading locks | 4+ | Mastery level |

### Blocking Depth Definition

- **Depth 0**: No vines block others (all can move immediately)
- **Depth 1**: Single blocking chains (A blocks B)
- **Depth 2**: Two-level chains (A blocks B blocks C)
- **Depth 3**: Multi-branch blocking (A blocks B and C)
- **Depth 4+**: Cascading dependencies (complex solve paths)

## ✅ Enhanced Validation Rules

### Rule 1: Grid Occupancy (MANDATORY)

```python
occupancy = (total_vine_cells / total_grid_cells)
valid = occupancy >= 0.95
```

- Level must have ≥95% of grid cells occupied
- Empty cells create visual gaps and reduce puzzle density
- Exception: Intentional shape masking requires explicit design

### Rule 2: Vine Color Distribution

```
Color count: 3-5 colors per level
Distribution: No single color >35% of vines
Visual balance: Each color appears in 1-2 clusters
```

### Rule 3: Vine Length Constraints

```
By Difficulty:
  Seedling: avg_length 6-8, min 4, max 12
  Sprout: avg_length 5-7, min 3, max 10
  Nurturing: avg_length 4-6, min 2, max 8
  Flourishing: avg_length 3-5, min 2, max 7
  Transcendent: avg_length 2-4, min 2, max 6
```

### Rule 4: Directional Balance

```
For grids ≥140 cells:
  Right-facing vines: 25-30%
  Left-facing vines: 20-25%
  Up-facing vines: 20-25%
  Down-facing vines: 20-30%

For smaller grids: Allow ±5% variance
```

### Rule 5: Blocking Relationship Rules

```
✅ VALID:
- Vine A can block Vine B (linear)
- Multiple vines block one vine
- Blocking chains up to depth 4
- Clearing blocker can unlock 1-3 vines

❌ INVALID:
- Circular blocking (A blocks B, B blocks A)
- All vines blocked at start (deadlock)
- Single blocker with >5 dependents
- Blocking depth >4 without strong narrative
```

### Rule 6: Solvability Verification

```
✓ At least 1 vine clearable at start
✓ Solver can find solution in <1 second
✓ min_moves ≤ max_moves ≤ grid_size
✓ No impossible configurations
```

## 📋 Enhanced Level JSON Template

```json
{
  "id": 1,
  "module_id": 1,
  "global_level_number": 1,
  "name": "First Steps",
  "parable_reference": "Matthew 13:1-9 - The Sower",
  "grid_size": [10, 14],
  "difficulty": "Nurturing",
  "occupancy_percent": 95.7,
  "vines": [
    {
      "id": "vine_1",
      "color": "moss_green",
      "head_direction": "right",
      "ordered_path": [
        {"x": 0, "y": 0},
        {"x": 1, "y": 0},
        {"x": 2, "y": 0},
        {"x": 2, "y": 1},
        {"x": 2, "y": 2},
        {"x": 1, "y": 2}
      ],
      "role": "blocker",
      "blocks": ["vine_2", "vine_3"]
    },
    {
      "id": "vine_2",
      "color": "sunset_orange",
      "head_direction": "left",
      "ordered_path": [...],
      "role": "intermediate",
      "blocks": ["vine_4"]
    },
    {
      "id": "vine_3",
      "color": "golden_yellow",
      "head_direction": "up",
      "ordered_path": [...],
      "role": "quick_clear",
      "blocks": []
    }
  ],
  "blocking_graph": {
    "vine_1": ["vine_2", "vine_3"],
    "vine_2": ["vine_4"],
    "vine_3": [],
    "vine_4": []
  },
  "blocking_depth": 2,
  "color_distribution": {
    "moss_green": 0.35,
    "sunset_orange": 0.30,
    "golden_yellow": 0.25,
    "royal_purple": 0.10
  },
  "complexity": "medium",
  "max_moves": 8,
  "min_moves": 4,
  "grace": 3,
  "designer_notes": "Focus on orange vine blocking. Color transitions create visual flow from left to right.",
  "solution_sequence": ["vine_3", "vine_2", "vine_1", "vine_4"]
}
```

## 🛠️ Level Validation Checklist

Run this checklist before finalizing a level:

- [ ] Grid occupancy ≥95%
- [ ] All vines have 2+ segments
- [ ] No circular blocking dependencies
- [ ] At least 1 vine clearable at start
- [ ] Vine count within difficulty tier
- [ ] Average vine length matches difficulty
- [ ] 3-5 distinct colors used
- [ ] No color >35% of total vines
- [ ] Directional balance within tolerances
- [ ] Solver completes in <1 second
- [ ] Blocking depth matches difficulty
- [ ] Solution is non-trivial
- [ ] Head direction matches first path segment
- [ ] Grid size appropriate for difficulty

## 🎮 Level Design Process (Revised)

### Step 1: Concept & Parable Link

- Decide which biblical parable the level represents
- Define learning objective (mechanic introduced)
- Choose difficulty tier based on progression

### Step 2: Grid & Layout

- Select grid size from tier recommendations
- Calculate occupancy target (95%+)
- Sketch vine placement considering color distribution

### Step 3: Vine Placement

- Place foundational vines (moss green) first
- Add intermediate paths (orange/blue)
- Layer quick-clear vines (yellow/lime)
- Add strategic blockers (purple/coral)

### Step 4: Color Distribution

- Ensure 3-5 colors with no color >35%
- Create color clusters for visual coherence
- Use contrasts to highlight blocking relationships

### Step 5: Validation

- Run automated checks
- Verify solver time <1 second
- Test solvability (BFS)
- Confirm occupancy ≥95%

### Step 6: Refinement

- Adjust difficulty if solver time is too fast/slow
- Rebalance colors if visual harmony is off
- Add designer notes explaining strategy

## 📊 Automated Validation Script

Enhanced validation includes:

```bash
flutter test test/level_validation_test.dart
```

Checks:

- ✓ JSON schema compliance
- ✓ Grid occupancy ≥95%
- ✓ Vine path validity
- ✓ Blocking relationship integrity
- ✓ Color distribution constraints
- ✓ Directional balance
- ✓ Solvability verification
- ✓ Difficulty tier compliance

## 🚀 Creating Your First Custom Level

1. Choose a parable message
2. Pick grid size: start with 10×14 (medium)
3. Plan 24-28 vines with 95%+ occupancy
4. Use 4 colors: moss green (35%), orange (30%), yellow (20%), purple (15%)
5. Create 2 blocking chains of depth 2-3
6. Verify solver finds solution quickly
7. Test min_moves and max_moves ranges
8. Polish and document

---

*This guide ensures consistent, visually appealing, and strategically engaging level design across Parable Bloom.*
