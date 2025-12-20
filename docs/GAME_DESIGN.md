# Parable Bloom – Updated Game Design Document (GDD)

**Version 2.0 – December 17, 2025**

## Executive Summary

**Parable Bloom** is a **zen hyper-casual arrow puzzle** where players clear a path for "blooms" by untangling a garden of arrows. The game uses a minimalist aesthetic with a focus on serene feedback and clarity.

**Core Loop**: Tap an arrow -> it moves in its fixed direction -> exit the grid to clear -> all vines cleared = level complete.

**Key Design Principles**:

- **Clarity first**: Minimalist dots for the grid and line-segment arrows ensure the player can always see the state of the game.
- **Reactive World**: Tapping a blocked arrow provides instant visual feedback (red flash), and clearing an arrow immediately unblocks others.
- **Progressive Challenge**: 5 tutorial levels introduce interlocks, chain blocking, and dense grids.

## Core Mechanics

| Mechanic | Description | Visual Feedback |
|----------|-------------|-----------------------|
| **Arrow Vines** | Minimalist line segments with clean directional heads. Standardized "Vine Green" color. | Head points in movement direction. |
| **Tap Action** | Tap any part of the arrow. If path is clear, it exits the grid. | Flash of white on tap. |
| **Blocking** | Paths blocked by other active arrows. Dimmed colors signify blockage. | Tap blocked -> Red flash + Heart loss (lives). |
| **Grid Dots** | The "garden" is a grid of subtle dots instead of blocks, feeling light and zen. | Highlights on valid moves. |
| **Lives System** | 3 Hearts per level. Each tap on a blocked vine costs one heart. | Hearts in AppBar update instantly. |
| **Win State** | All arrows cleared. Triggers parable reveal. | "Level Complete" dialog with scripture. |

## Art & Assets Pipeline

**Style**: Watercolor zen garden (muted greens/browns, soft glows). 16 PNGs total (<1MB). Generate via **Unity AI (Flux.1 Dev)** → Export → GIMP resize (64x64/128x128, transparent).

| Category | Sprites (Prompt Tweaks) |
|----------|------------------------|
| **Core Puzzle (10)** | Grid BG (seamless grass), Empty Cell (dew soil), Vine H/V Body, 4x Vine Heads (L/R/U/D arrows), Bloom Burst, Thorn Wilt. |
| **UI (4)** | Play Btn (leaf arrow), Pause Overlay (dusk fade), Complete Icon (gold flower), Sun/Moon Toggle. |
| **Misc (2)** | Shekel Coin, Fail Overlay BG. |

**Parable Placeholder**: Pond lilies (512x512, post-MVP).

**Audio (3 files, freesound.org)**: Slide whoosh, Wilt crunch, Bloom chime (loop wind BG).

## Level Design

**JSON Schema** (assets/levels/level_001.json; auto-sort numeric):

```json
{
  "id": 1, "name": "Tender Shoot", "grid_size": [4,4],
  "vines": [
    {"id":1, "horizontal":true, "row":1, "col_start":1, "length":2, "dir":"right"},
    {"id":2, "vertical":true, "col":3, "row_start":0, "length":3, "dir":"down"}
  ],
  "min_taps": 3, "coins_reward": 30
}
```

- **Vertical vines**: Use `"col"`, `"row_start"`.
- **Validation**: All hand-verified (BFS sim for solvability <10 taps).
- **Variety**:

  | Pack | Grids | Vines | Density |
  |------|-------|-------|---------|
  | Tutorial (1-3) | 4x4 | 3-4 | Low (50% empty) |
  | Easy (4-7) | 5x5 | 5-7 | Med |
  | Medium (8-10) | 6x6 | 8-10 | High |

**Sample Levels** (ASCII: H> = horiz right head, |v = vert down, .=empty):

- **Lv1 (4x4)**:

  ```
  . . . .
  . H> . .
  . . . .
  . . |v .
  ```

- **Lv5 (5x5, Interlock)**: Dense cross; tap order key.

**PCG Post-MVP**: Python script (random place non-blocked vines, A* solve).

## UI/UX Flow

1. **Splash** → "Tap vines to clear paths" → Lv1.
2. **HUD**: Coins (top-right), Wrong Counter (3 hearts), Pause Btn.
3. **Pause**: Resume/Undo/Restart/Settings/Mute.
4. **Fail/Win**: Overlay w/ btns (Buy/Restart/Next).
5. **Hub** (post-Lv10): Level select (unlocked flowers grow).

**Onboarding**: 3 auto-hint tutorials.

## Monetization & Progression (MVP Stub)

- **Coins**: Local only; earn 20-50/level.
- **Shop**: Mercy Pack (25 coins = +3 lives). Post-MVP: IAP $0.99 packs.
- **Lives**: Infinite free restarts? No—3 cap drives buys.

**Options**:

| Model | Benefits | MVP Fit |
|-------|----------|---------|
| **Coins + IAP** (Selected) | Gentle, thematic (parable "seeds"). | Easy Hive impl. |
| **Ad Watches** | Free rev early. | Post-MVP (RewardedVideo). |

## Technology Stack

- **Flutter 3.24+ + Flame 1.9+** (grid/tap/tweens/collisions).
- **Packages**: hive_flutter (saves/coins), flame_audio (SFX), json_annotation (levels).
- **Local Save**: Hive boxes: `progress` (level/unlocks), `coins`, `state` (grid snapshot).
- **Builds**: APK/TestFlight (<20MB).
- **No Firebase** (MVP).

**Week 1 Code**: Grid/tap ready (from prior).

## Implementation Milestones & Timeline

| Week | Goals | Tasks | Hours |
|------|-------|-------|-------|
| **1** | Setup + Grid | Flutter create, tappable grid, Hive init. **Done?** | 5 |
| **2** | Vines + Loop | VineComponent (slide/wilt), test Lv1-3, audio. | 8-10 |
| **3** | 10 Levels + Polish | JSON loader, coins/UI, fail/win, auto-save. | 10 |
| **4** | Builds + Test | APK/IPA, 5-friend playtest, onboarding. | 6-8 |

**Post-MVP**:

- Wk5-6: Parables (JSON triggers, voice).
- Wk7-8: PCG 100 levels.
- Wk12: Store launch.

## Risks & Mitigations

| Risk | Mitigation |
|------|------------|
| **Slide Bugs** | Prototype heavy Week 2; Flame collision examples. |
| **Level Balance** | Playtest daily; min_taps validator. |
| **Art Variance** | Unity AI variants → GIMP unify palette. |
| **Scope Creep** | Lock 10 levels; bending post-MVP. |

## Next Immediate Steps

1. **Today**: Gen 4 vine heads (Unity AI), drop in assets/art/. Test Week 1 grid.
2. **Tomorrow**: Paste Week 2 VineComponent code → `flutter run` → Play Lv1 mock.
3. **Friday**: 10 JSON levels → Share APK for feedback.

This GDD evolves your vision into a **market-proven winner**—serene theme + arrow puzzle addiction. Options like full-exit were tempting for purity, but partial slides teach better retention. Ready to code Week 2, tweak levels, or iterate GDD? 🌿
