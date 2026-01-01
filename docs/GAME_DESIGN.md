---
title: "Parable Bloom – Final Game Design Document (GDD)"
version: "3.4"
last_updated: "2025-12-24"
status: "Implementation Complete"
type: "Game Design Document"
---

# Parable Bloom – Final Game Design Document (GDD)

## Executive Summary

**Parable Bloom** is a **zen hyper-casual arrow puzzle game** with faith-based themes, where players tap directional vines (arrows) to slide them off a grid in the direction of their head, mimicking the classic Snake game's movement. Body segments follow as a queue, and blocked vines animate back to their original position. The game emphasizes serene gameplay, strategic depth, and spiritual reflections through parable rewards.

**Core Loop**: Tap a vine → it slides in its head's direction (Up, Down, Left, Right) → exits the grid to "bloom" if clear, or animates back if blocked → clear all vines to win.

**Key Features**:

- **Snake-Like Movement**: Vines move only in the head's direction, with body segments following. Paths can include 90-degree turns, but movement follows the head.
- **Grace System**: Replaces "hearts" with **Grace** (3 per level, 4 for Transcendent difficulty), symbolizing forgiveness. If Grace runs out, a message appears: "God's grace is endless—try again!" with a restart option.
- **Module Structure**: 5 modules for MVP, each with 15 levels (10 core, 4 progressive, 1 Transcendent capstone), unlocking a parable in the Journal.
- **Grid Sizes**: Rectangular grids from 5×8 (tutorial) to 24×40 (capstone), with future potential for shaped grids (e.g., cross, smiley face). GridComponent now properly supports rectangular dimensions instead of assuming square grids.
- **Hints**: One hint per level (glows tappable vines after 30s inactivity).
- **No Undo**: Encourages thoughtful play.
- **Themed Difficulty**: Faith-inspired tiers (Seedling, Nurturing, Flourishing, Transcendent) with parameters for moves, complexity, and turns.
- **Visual Theme**: Watercolor zen garden with adaptive light/dark mode colors (blocked vines: black in light, white in dark).
- **PCG in Go**: Procedural level generation for post-MVP scalability.
- **Sharing (Post-MVP)**: Parable sharing to social platforms for promotion.

**Target Audience**: Casual players (12+) seeking relaxing, strategic puzzles with spiritual depth on iOS/Android.

**Technology Stack**: Flutter + Flame (rendering), Riverpod (state management), Hive (local saves), Firebase-ready for cloud sync.

**Monetization Stub**: Free with optional IAP for hint packs/module unlocks (post-MVP).

## Core Mechanics

### Vine (Arrow) Behavior

- **Definition**: A vine is a directional arrow with a "head" (movement direction: Up, Down, Left, Right) and "body" segments (minimum 2 units total length). The vine occupies contiguous cells, potentially with 90-degree turns (e.g., L-shape, zigzag), like a snake's trail.
- **Path & Movement**:
  - **Initial Path**: Defined by a sequence of grid positions with directions (e.g., [(5,5,Up), (5,6,Up), (4,6,Left)]). Turns are fixed at creation.
  - **Movement**: Tap triggers the vine to slide in the **head's direction** (e.g., Up from (5,5) to (5,6), (5,7), etc.).
    - **Body Queue**: Each segment follows the one ahead (like Snake). If the head moves to (5,6), the segment at (5,5) moves to (5,6), (5,6) to (5,7), etc.
    - **Clearing**: The vine exits if the head reaches the grid edge and all segments can follow without obstruction (e.g., head at (5,10) for Up, vine shifts off).
    - **Blocked**: If any segment's next cell is occupied, the vine animates forward to the obstruction, pauses (200ms), then reverses to its original position. Costs 1 **Grace**.
- **Blocking Rules**: A vine is blocked if any cell in its forward path (head's direction) is occupied by another vine. Blocking is dynamic—clearing one vine unblocks others.
- **Animation**:
  - **Slide**: Snake-like movement where head moves first, each body segment follows the previous segment's old position (classic Snake game mechanics).
  - **Blocked**: Forward snake animation to obstacle, then reverse animation through position history to return to start.
  - **Clear**: Continue snake movement until all segments exit the grid and are fully off-screen, then show bloom/sparkle effect at exit location.
- **History-Based Movement**: Maintains a history of all vine positions, allowing smooth forward and backward animations.
- **Bloom Effect**: Beautiful particle effect (expanding rings, central glow, sparkle particles) appears when vine fully clears off-screen.
- **Fluid Gameplay Optimization**: Clearable vines are immediately removed from blocking calculations when tapped, allowing other vines to be tapped without incorrect blocking during animation. Visual animation continues smoothly until off-screen.
- **Example**: On a 10x10 grid, vine at [(5,5,Up), (5,6,Up), (4,6,Left)]:
  - Tap → Head moves to (5,7), middle segment takes old head position (5,6), tail takes old middle position (5,6).
  - If blocked, animate backwards through history to original positions.

### Grid & Win Conditions

- **Grid**: Subtle dot-based for zen aesthetic. Sizes: 9x9 (tutorial) to 20x20 (capstone). Future: Shaped grids (e.g., cross, smiley face).
- **Win**: All vines cleared (bloomed off-grid). Triggers level complete with glow and transition to next level.
- **Grace System**: 3 Grace per level (4 for Transcendent). Lose all → restart prompt: "God's grace is endless—try again!" with restart or hint option.
- **Hints**: One hint per level, auto-triggered after 30s inactivity (glows tappable vines). No additional hints to maintain challenge.
- **No Undo**: Encourages strategic planning.

### JSON Schema for Levels

Hardened for procedural content generation (PCG) in Golang and snake-like movement:

```json
{
  "id": 1,
  "module_id": 1,
  "name": "First Sprout",
  "grid_size": [9, 9],
  "difficulty": "Seedling",
  "vines": [
    {
      "id": 1,
      "head_direction": "right",
      "ordered_path": [
        {"x": 2, "y": 3},  // HEAD (index 0) - moving RIGHT
        {"x": 3, "y": 3},  // First segment LEFT of head (opposite direction)
        {"x": 4, "y": 3}   // TAIL (last) - continues rightward
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

- **Validation Rules (for PCG)**:
  - No initial overlaps between vines.
  - Paths contiguous with 90-degree turns only.
  - Solvable (BFS/DFS confirms no deadlocks).
  - Minimum 50% empty cells at start.
  - Head direction matches first segment's direction.
  - PCG (Golang): Generate vines (length 2-80% grid, 0-3 turns), simulate solvability, adjust for difficulty.

## Progression & Module Structure

- **Modules**: 5 for MVP, each with 15 levels themed around a parable (Mustard Seed, Sower, Wheat & Weeds, Vine & Branches, Growing Seed):
  - Levels 1-5: Seedling (9x9).
  - Levels 6-10: Nurturing (9x9 to 12x12).
  - Levels 11-14: Flourishing (12x12 to 16x16).
  - Level 15: Transcendent (16x16 to 20x20, 4 Grace).
- **Pacing**: ~30-60 minutes per module (~2-5 minutes per level).
- **Reward**: Module completion unlocks a parable (text, watercolor illustration, optional voice narration) in the Journal.
- **Home Screen**: Garden hub with flowers representing completed modules. Tabs: Play (module/level select), Journal (parable collection).
- **Game Flow**:
  1. Splash → Tutorial Module (5 levels, 9x9, no parable).
  2. Hub → Select Module → Play levels sequentially (unlocks next on completion).
  3. Module End → Parable Reveal → Journal Add → Return to Hub.

## Themed Difficulty System

Faith-inspired tiers with parameters for PCG and gameplay:

| Difficulty Tier | Description | Grid Size | Vine Count/Length | Max Moves | Complexity | Grace | Example Use |
|-----------------|-------------|-----------|-------------------|-----------|------------|-------|-------------|
| **Seedling** | Gentle roots taking hold. | 9x9 | 3-5 vines, lengths 2-4, 0-1 turns | 5-8 | Low: Linear paths, no interlocks. | 3 | Tutorial, early module. |
| **Nurturing** | Sprouts growing stronger. | 9x9 to 12x12 | 5-8 vines, lengths 2-6, 1-2 turns | 8-12 | Medium: 1-2 interlocks, limited traversal. | 3 | Mid-module. |
| **Flourishing** | Plants in full bloom. | 12x12 to 16x16 | 8-12 vines, lengths 3-8, 1-3 turns | 12-18 | High: Multi-interlocks, 2-3 grid passes. | 3 | Late-module. |
| **Transcendent** | Eternal harmony achieved. | 16x16 to 20x20 | 12+ vines, lengths 4-12, 2-4 turns | 18+ | Extreme: Deep cycles, hidden dependencies. | 4 | Capstone only. |

- **Parameters**:
  - **Max Moves**: Soft limit (warning: "Take a moment?" if exceeded). PCG ensures min_moves <= max.
  - **Complexity**: Dependency graph depth (low = no cycles, high = 3+ layers). Limit traversals to 2-3 to avoid frustration.
  - **Turns**: Increase with difficulty for intricate paths.
- **Theming Tie-In**: Each tier unlocks a mini-reflection (e.g., Seedling: "Small steps plant great seeds.").

## UI/UX Flow

1. **Splash** → "Tap vines to clear paths" → Tutorial Module.
2. **HUD**: Grace counter (top-left), Current level info (top-center), Hint button (top-right).
3. **Pause**: Resume/Restart/Settings/Mute (post-MVP).
4. **Fail/Win**: Overlay with appropriate messaging and action buttons.
5. **Hub**: Garden view with completed modules as flowers, Journal tab for parables.

**Onboarding**: Auto-hints for first few levels, teaching snake movement and blocking.

## Visual & Audio Theme

- **Aesthetic**: Watercolor zen garden. Light mode: Warm earth tones (beige BG, #F5F5DC). Dark mode: Cool night shades (deep blue BG, #1E3528).
- **Colors**:
  - **Normal Vines**: Light: Vibrant green (#4CAF50). Dark: Soft teal (#009688).
  - **Blocked Vines**: Light: Black (#000000) with red flash (#FF0000). Dark: White (#FFFFFF) with purple flash (#9C27B0).
  - **Grid Dots**: Light: Subtle brown (#8B4513). Dark: Gentle white (#E0E0E0).
  - **UI Elements**: Leaf-shaped buttons, adaptive ThemeData.
- **Vine Turns**: Smooth 90-degree curves via corner sprites (e.g., "vine_corner_up_right.png").
- **Audio**: Calm wind loop, bloom chime, wilt rustle. Volume toggle in settings.

## Art & Assets Pipeline

**Style**: Watercolor zen garden (muted greens/browns, soft glows). ~24 PNGs total (<2MB). Generate via **Unity AI (Flux.1 Dev)** → Export → GIMP resize (64x64/128x128, transparent).

| Category | Sprites (Prompt Tweaks) |
|----------|------------------------|
| **Vine Segments (16)** | Straight (horizontal/vertical), corner (Up-Left, Up-Right, Down-Left, Down-Right), head (4 directions), across 4 colors (moss green, emerald, olive, sage). |
| **Core Puzzle (4)** | Grid BG (seamless grass/dirt), Empty Cell (dew soil), Bloom Burst (32x32, 8-frame), Wilt Effect. |
| **UI (4)** | Play button (leaf), pause overlay, complete icon (gold flower), settings toggle (sun/moon). |
| **Parable Backgrounds** | Reuse 50+ WebP/JPG (1080x1920, ~50KB each) for parable reveals. |

**Prompt Example**: "Watercolor vine corner, 90-degree up-to-right, moss green, 64x64, transparent."

## Sample Level (9x9, Seedling)

```json
{
  "id": 1,
  "module_id": 1,
  "name": "First Sprout",
  "grid_size": [9, 9],
  "difficulty": "Seedling",
  "vines": [
    {
      "id": 1,
      "head_direction": "up",
      "path": [
        {"row": 5, "col": 5, "direction": "up"},
        {"row": 5, "col": 6, "direction": "up"},
        {"row": 4, "col": 6, "direction": "left"}
      ],
      "color": "moss_green"
    },
    {
      "id": 2,
      "head_direction": "right",
      "path": [
        {"row": 3, "col": 3, "direction": "right"},
        {"row": 3, "col": 4, "direction": "right"}
      ],
      "color": "emerald"
    }
  ],
  "max_moves": 5,
  "min_moves": 3,
  "complexity": "low",
  "grace": 3
}
```

**ASCII** (H=Horiz head, V=Vert head, |=vert body, -=horiz body, <=left, ^=up):

```
. . . . . . . . .

. . . . . . . . .
. . . H- . . . . .
. . . . . . . . .
. . . . . ^ . . .
. . . . . V-<= . .
. . . . . . . . .
. . . . . . . . .
. . . . . . . . .

```

**Solution**: Tap vine 2 (clears right), tap vine 1 (clears up).

## Technology Stack & Implementation

- **Flutter 3.24+ + Flame 1.9+** (grid/tap/tweens/collisions).
- **Packages**: riverpod (state management), hive_flutter (local saves), flame_audio (SFX).
- **Local Save**: Hive boxes: `progress` (module/level), `journal` (parables), `settings` (audio, theme).
- **Builds**: APK/TestFlight (<25MB).
- **Firebase Ready**: Cloud sync for progress (post-MVP).

## Implementation Milestones & Timeline

| Week | Goals | Tasks | Hours |
|------|-------|-------|-------|
| **1** | Schema Migration | Update VineData/LevelData, providers, tests. **Done** | 5 |
| **2** | Snake Movement | Implement queue-based sliding, blocking animations. | 8-10 |
| **3** | Module System | Level loading from modules, progression tracking, hub UI. | 10 |
| **4** | Polish & Test | Grace system, hints, adaptive colors, playtesting. | 6-8 |

**Post-MVP**:

- Wk5-6: Go PCG script, parable voice narration.
- Wk7-8: 100+ levels, shaped grids.
- Wk12: Store launch with parable sharing.

## Risks & Mitigations

| Risk | Mitigation |
|------|------------|
| **Snake-Like Movement Complexity** | Prototype early; Flame PositionComponent and collision detection. |
| **PCG in Go** | Start with hand-crafted levels; implement Go script in Week 7. Use JSON I/O for compatibility. |
| **Large Grids (20x20)** | Optimize rendering with Flame's sprite batching and preloaded assets. |
| **Level Balance** | Playtest daily; adjust max_moves and complexity via BFS validation. |
| **Intuitiveness** | Add onboarding popups for each module to teach turns and blocking. |

## Monetization & Progression (MVP Stub)

- **Grace**: Free restarts with thematic messaging.
- **Hints**: One per level, auto-triggered after 30s inactivity.
- **Post-MVP**: IAP for hint packs/module unlocks, parable sharing.

## Next Steps

- **Immediate**: Test snake movement with sample levels.
- **Week 2**: Implement proper queue animation for vine segments.
- **Post-MVP**: Go PCG script, explore shaped grids, add parable sharing.

Ready to continue implementation or need clarification on any mechanics? 🌿
