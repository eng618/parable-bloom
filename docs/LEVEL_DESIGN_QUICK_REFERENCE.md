# 🎨 Parable Bloom Level Design - Quick Reference

## Color Palette

```
🟢 Moss Green    #7CB342  → Primary blocking vines (foundational)
🟠 Sunset Orange #FF9800  → Intermediate paths (energy)
🟡 Golden Yellow #FFC107  → Quick-clear vines (optimism)
🟣 Royal Purple  #7C4DFF  → Complex blockers (strategy)
🔵 Sky Blue      #29B6F6  → Alternative strategy (options)
🔴 Coral Red     #FF6E40  → Challenging blockers (intensity)
💚 Lime Green    #CDDC39  → Quick wins (relief)
```

## Grid Sizes by Difficulty

| Difficulty | Grid Size | Vines | Occupancy | Colors | Blocking Depth |
|------------|-----------|-------|-----------|--------|---|
| Seedling | 6×8 | 6-8 | ≥95% | 2-3 | 0-1 |
| Sprout | 8×10 | 10-14 | ≥95% | 3-4 | 1-2 |
| Nurturing | 10×14 | 18-28 | ≥95% | 3-5 | 2-3 |
| Flourishing | 12×16-16×20 | 36-50 | ≥95% | 4-5 | 3-4 |
| Transcendent | 16×24+ | 60+ | ≥95% | 4-5 | 4+ |

## Level JSON Template Fields

```json
{
  "id": 1,                           // Position within module (1-15)
  "module_id": 1,                    // Which module this belongs to
  "global_level_number": 1,          // What player sees (continuous)
  "name": "Level Name",              // Display name
  "parable_reference": "Matthew X",  // Biblical reference
  "grid_size": [10, 14],            // [width, height]
  "difficulty": "Nurturing",         // One of the tiers
  "vines": [...],                    // Array of vine objects
  "blocking_graph": {...},           // Maps vine IDs to blocked vines
  "blocking_depth": 2,               // Max depth of blocking chains
  "color_distribution": {...},       // Percentage of each color
  "complexity": "medium",            // low/medium/high
  "max_moves": 12,                   // Upper bound for solution
  "min_moves": 6,                    // Lower bound for solution
  "grace": 3,                        // Lives per level
  "designer_notes": "..."            // Strategy explanation
}
```

## Vine Object Template

```json
{
  "id": "vine_1",                    // Unique ID string
  "color": "moss_green",             // From color palette
  "head_direction": "right",         // up/down/left/right
  "ordered_path": [                  // Head first, tail last
    {"x": 0, "y": 0},
    {"x": 1, "y": 0},
    {"x": 2, "y": 0}
  ],
  "role": "blocker",                 // blocker/intermediate/quick_clear
  "blocks": ["vine_2", "vine_3"]     // IDs this vine blocks
}
```

## Validation Checklist

Before finalizing a level, verify:

- [ ] **Occupancy**: Grid ≥95% filled
- [ ] **Colors**: 3-5 distinct colors, none >35%
- [ ] **Vine Count**: Within difficulty range
- [ ] **Path Validity**: All contiguous, 90° turns only
- [ ] **Head Direction**: Matches first path segment
- [ ] **Blocking**: No circular dependencies
- [ ] **Solvability**: At least 1 clearable vine at start
- [ ] **Direction Balance**: No direction <20% or >30%
- [ ] **Length**: Matches difficulty tier averages
- [ ] **Complexity**: Matches difficulty tier
- [ ] **Solution**: Non-trivial and findable

## Quick Design Process

1. **Pick difficulty** → Choose grid size
2. **Calculate occupancy** → Total cells × 0.95 = minimum vines needed
3. **Place vines** → Aim for 95%+ occupancy
4. **Add colors** → 3-5 colors, balanced distribution
5. **Create blocking** → 2-4 chains of appropriate depth
6. **Verify solver** → Must find solution in <1 second
7. **Test balance** → Ensure fun difficulty for tier
8. **Document** → Add designer notes

## Example Level Occupancy Calculation

For a 10×14 grid:

- Total cells: 140
- Minimum occupied: 140 × 0.95 = 133 cells
- With avg vine length 5: need 133 ÷ 5 = ~27 vines
- Recommended range: 18-28 vines (Nurturing tier)

## Common Blocking Patterns

**Simple Chain** (Depth 1):

```
Vine A → blocks → Vine B
Clear A, then B
```

**Two-Branch** (Depth 2):

```
     ↓
Vine A → Vine B
     ↓
  Vine C
Clear A, then both B and C
```

**Deep Chain** (Depth 3):

```
Vine A → Vine B → Vine C → Vine D
Clear A, then B, then C, then D
```

## Tips for Visual Appeal

✨ **DO:**

- Alternate colors to create flow
- Use contrasts to highlight blockers
- Create color clusters for cohesion
- Mix long and short vines
- Vary head directions evenly

🚫 **DON'T:**

- Leave empty regions
- Group all vines of one color
- Make blocking too obvious or too hidden
- Use more than 5 colors per level
- Create symmetric grids

## Testing Your Level

```bash
# Validate single file
python scripts/validate_levels_enhanced.py

# Run solver test
flutter test test/level_validation_test.dart

# Check occupancy percentage
# (Automatically calculated and stored in level JSON)
```

## Resources

- **Full Guide**: `docs/ENHANCED_LEVEL_DESIGN.md`
- **Example Level**: `assets/levels/level_example_colorful.json`
- **Validator Script**: `scripts/validate_levels_enhanced.py`
- **Test Suite**: `test/level_validation_test.dart`

---

Happy level designing! 🌿
