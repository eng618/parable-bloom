# 📋 Level Creation Guide - Working with Path Format

## Understanding `ordered_path` Format

The `ordered_path` array represents the vine from **head to tail**:

- **Index 0**: Head position (the moving point)
- **Indices 1+**: Body segments in order (from neck to tail)

The `head_direction` field indicates the direction the vine POINTS (where it will move TO):

- The body segments TRAIL BEHIND in the opposite direction
- Each segment must be adjacent (distance = 1) to the previous one

## Correct Path Example

For a vine moving **RIGHT** (head_direction: "right"):

- Head moves right (positive X)
- Body trails to the LEFT

```
Path: [head at 5,0] → [body at 4,0] → [body at 3,0] → [body at 2,0]
Animation: Head slides right, body follows left
```

For a vine moving **DOWN** (head_direction: "down"):

- Head moves down (positive Y)
- Body trails UPWARD

```
Path: [head at 0,5] → [body at 0,4] → [body at 0,3] → [body at 0,2]
Animation: Head slides down, body follows up
```

## Validation Rules

When validator checks a vine:

1. Length must be ≥2 (head + at least one body segment)
2. Head direction must match first movement
   - If head_direction is "right", then: head.x - body[0].x should equal 1
   - If head_direction is "left", then: head.x - body[0].x should equal -1
   - If head_direction is "down", then: head.y - body[0].y should equal 1
   - If head_direction is "up", then: head.y - body[0].y should equal -1
3. All segments must be contiguous (no gaps)
4. Only 90-degree turns allowed

## Quick Template

```json
{
  "id": "vine_1",
  "color": "moss_green",
  "head_direction": "right",
  "ordered_path": [
    {"x": 5, "y": 0},  // Head at this position
    {"x": 4, "y": 0},  // Body segment 1
    {"x": 3, "y": 0},  // Body segment 2
    {"x": 2, "y": 0}   // Body segment 3 (tail)
  ],
  "role": "quick_clear",
  "blocks": []
}
```

## Creating Tutorial Levels

When building tutorial levels (1-5):

1. Keep vines SHORT (2-4 segments each)
2. Use LARGE grids to ensure 95%+ occupancy with few vines
3. Add PADDING vines to reach occupancy targets
4. Start simple: Tutorial 1 - all vines free to move
5. Progress: Tutorial 2-5 gradually introduce blocking

## Recommended Approach

Use this process to avoid formatting errors:

1. Sketch vine layout on grid
2. Identify head and tail for each vine
3. Write path from head (index 0) to tail
4. Choose direction that makes logical sense
5. Validate with: `python scripts/validate_levels_enhanced.py`
6. Fix any path-direction mismatches

---

*Full level creation reference in ENHANCED_LEVEL_DESIGN.md*
