# 🎮 Tutorial & Basic Level Design Guide

## Overview

This guide details how to create the first 10 levels for Parable Bloom:

- **Levels 1-5**: Tutorial levels (impossible to fail, grace=999)
- **Levels 6-10**: Basic gameplay (Seedling/Sprout, grace=3)

## Level Progression Map

### Tutorial Levels (1-5): Teaching Mechanics

| Level | Name | Focus | Vines | Occupancy | Blocking | Colors | Grace |
|-------|------|-------|-------|-----------|----------|--------|-------|
| 1 | Your First Vine | Tap mechanics | 6-8 | 95%+ | None | 1 | 999 |
| 2 | Colors of the Vineyard | Color variety | 7-9 | 95%+ | None | 3 | 999 |
| 3 | First Blocker | Simple blocking | 8-10 | 95%+ | Depth 1 | 3 | 999 |
| 4 | The Blocking Chain | Chain blocking | 10-12 | 95%+ | Depth 2 | 3 | 999 |
| 5 | Multiple Blockers | Multi-independent | 10-12 | 95%+ | 2× Depth 1 | 4 | 999 |

### Basic Gameplay Levels (6-10): Real Challenges

| Level | Name | Difficulty | Vines | Occupancy | Blocking | Colors | Grace |
|-------|------|-----------|-------|-----------|----------|--------|-------|
| 6 | First Challenge | Seedling | 8 | 95%+ | Depth 1 | 3 | 3 |
| 7 | Growing the Garden | Seedling | 8 | 95%+ | 2× Depth 1 | 4 | 3 |
| 8 | Deeper Roots | Sprout | 11 | 95%+ | Multi-block | 5 | 3 |
| 9 | Connected Growth | Sprout | 12 | 95%+ | Depth 2 | 5 | 3 |
| 10 | The Harvest | Sprout | 14 | 95%+ | 2× Depth 1 | 5 | 3 |

## Level 1: Your First Vine

**Goal**: Teach basic tap-to-move mechanic

**Structure**:

- Grid: 6×8 or similar
- Vines: 6-8 short vines (2-3 segments each)
- All vines: No blocking, can clear in any order
- All same color: moss_green (simplest)
- Padding: Fill to 95%+ occupancy

**Design Tips**:

- Space vines out so each is easily identifiable
- Use all 4 directions (up, down, left, right)
- No complex patterns - just show the mechanic
- Solution: Clear any 6-8 vines in any order

**Example vine**:

```json
{
  "id": "vine_1",
  "color": "moss_green",
  "head_direction": "right",
  "ordered_path": [
    {"x": 5, "y": 1},
    {"x": 4, "y": 1},
    {"x": 3, "y": 1}
  ],
  "blocks": []
}
```

## Level 2: Colors of the Vineyard

**Goal**: Introduce color differentiation

**Structure**:

- Grid: 7×10 or similar
- Vines: 7-9 short vines
- Colors: 3 distinct (moss_green, sunset_orange, golden_yellow)
- No blocking still
- Balanced color distribution

**Design Tips**:

- Group same-color vines loosely together
- Use contrasts to make colors distinct
- Still simple puzzle, just learning colors
- Solution: Clear all vines in any order

## Level 3: First Blocker

**Goal**: Introduce blocking mechanic

**Structure**:

- Grid: 7×11 or similar
- Vines: 8-10 short vines
- ONE blocking pair: Vine A blocks Vine B
- Other vines: Free to move
- Colors: 3 (highlight blocker with unique color)

**Design Tips**:

- Make blocker CLEARLY positioned
- Can clear other 6-8 vines first
- Then clear blocker, then blocked vine
- Solution shows: Free vines → Blocker → Blocked vine

## Level 4: The Blocking Chain

**Goal**: Teach chain blocking (Depth 2)

**Structure**:

- Grid: 8×12 or similar
- Vines: 10-12 short vines
- Blocking chain: Vine A → Vine B → Vine C
- Other vines: Free
- Colors: 3-4

**Design Tips**:

- Make the chain obvious visually
- Vine A and B should be positioned to show dependency
- Solution: Free vines → A → B → C

## Level 5: Multiple Blockers

**Goal**: Multiple independent blocking chains

**Structure**:

- Grid: 9×12 or similar
- Vines: 10-12 vines
- Blocking: TWO separate chains (A→B and C→D)
- Colors: 4-5

**Design Tips**:

- Spatial separation shows independence
- Solution: Free vines → A → B, then C → D
- Or interleave: Free → A → C → B → D

## Level 6-10: Real Gameplay

Transition to real challenges:

- Grace limited to 3
- Proper difficulty tier constraints
- Blocking depth increases with level
- More vines = more strategy
- Introduce vine "roles" (blocker, intermediate, quick_clear)

## Path Direction Reference

**Quick fix for path formatting**:

For head_direction = "right" (vine moves right):

- Head is on the RIGHT
- Body extends LEFT
- Example: head at (5,0), body at (4,0), (3,0)

For head_direction = "down" (vine moves down):

- Head is at BOTTOM
- Body extends UP
- Example: head at (0,5), body at (0,4), (0,3)

For head_direction = "left" (vine moves left):

- Head is on the LEFT
- Body extends RIGHT
- Example: head at (0,0), body at (1,0), (2,0)

For head_direction = "up" (vine moves up):

- Head is at TOP
- Body extends DOWN
- Example: head at (0,0), body at (0,1), (0,2)

## Validation Checklist

After creating each level, verify:

- [ ] All vines have 2+ segments
- [ ] Head direction matches first path movement
- [ ] No circular blocking dependencies
- [ ] Grid occupancy ≥95%
- [ ] At least 1 vine clearable at start
- [ ] Blocking graph is correct in JSON
- [ ] Color count within difficulty range
- [ ] No color exceeds 35% of vines
- [ ] Solution is non-trivial
- [ ] Solver can complete in <1 second

Run validation:

```bash
python scripts/validate_levels_enhanced.py
```

## Creating Levels: Step-by-Step

### 1. Plan the Grid

- Choose grid size based on vine count needed
- Calculate: total_cells × 0.95 = minimum occupied
- With average vine length 4: cells_needed ÷ 4 = vine_count

### 2. Sketch Layout

- Draw grid on paper or digital
- Place vines to fill 95%+
- Mark head and tail for each vine
- Note directions

### 3. Define Blocking (if any)

- Create blocking_graph object
- List vine IDs in order of dependency
- Ensure no circular references

### 4. Choose Colors

- For tutorials: use 1, 3, 3, 4 colors progressively
- For gameplay: 3-5 colors balanced
- No color >35% of total

### 5. Write JSON

- Create level_{N}.json file
- Use valid ordered_path format
- Set grace=999 for tutorials, 3 for gameplay
- Add designer_notes

### 6. Validate

- Run validator script
- Fix any path/direction mismatches
- Verify occupancy percentage
- Check solver time

### 7. Test

- Play level in game if possible
- Verify difficulty is appropriate
- Ensure fun for intended tier

## Resources

- **Path Format**: `docs/LEVEL_PATH_FORMAT_GUIDE.md`
- **Design System**: `docs/ENHANCED_LEVEL_DESIGN.md`
- **Quick Reference**: `docs/LEVEL_DESIGN_QUICK_REFERENCE.md`
- **Validator**: `scripts/validate_levels_enhanced.py`

---

*Next step: Create the 10 levels following this structure, then validate all with the automated script.*
