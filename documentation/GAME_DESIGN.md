---
title: "Parable Bloom – Game Design Document"
version: "4.0"
last_updated: "2026-01-03"
status: "Active"
type: "Game Design Document"
---

# Parable Bloom – Game Design Document

## 1. Executive Summary

**Parable Bloom** is a **zen hyper-casual puzzle game** that blends snake-like movement mechanics with faith-based themes. Players tap directional vines to slide them off a grid, clearing paths for others to follow. The experience is designed to be meditative yet strategically deep, rewarding patience and foresight.

**Core Pitch**: "Unblock the garden, reveal the parable."
**Theme**: A watercolor zen garden where clearing vines symbolizes removing obstacles from one's spiritual path.
**Platform**: iOS/Android (Flutter + Flame).

## 2. Core Mechanics

### Vine Behavior (Snake Movement)

- **Movement**: Vines are directional arrows with a "head" and a trailing "body". When tapped, a vine attempts to move in the direction of its head (Up, Down, Left, Right).
- **Snake Physics**: Movement is segment-based. The head moves into a new cell, and each subsequent body segment moves into the cell previously occupied by the segment ahead of it.
- **Clearing**: A vine is "cleared" when its head and all body segments successfully exit the grid boundaries.
- **Blocking**: If a vine's path is obstructed by another vine, it cannot move. Tapping a blocked vine triggers a "struggle" animation (moves forward slightly, then reverses) and costs **Grace**.

### The Grace System

- **Concept**: Instead of "lives" or "health," the game uses **Grace**, symbolizing forgiveness and second chances.
- **Mechanic**:
  - Players start each level with **3 Grace** (4 in Transcendent difficulty).
  - Tapping a blocked vine consumes 1 Grace.
  - **Fail State**: If Grace reaches 0, the level ends with a gentle message: *"God's grace is endless—try again!"*
  - **Tutorials**: Levels 1-5 have infinite Grace (999) to allow risk-free learning.

## 3. Progression System

### Difficulty Tiers

The game scales difficulty through grid size, vine count, and blocking complexity.

| Tier | Grid Size | Vine Count | Avg Length | Complexity | Blocking Depth |
|------|-----------|------------|------------|------------|----------------|
| **Seedling** | 6×8 to 8×10 | 6-8 | 6-8 | Linear, no loops | 0-1 |
| **Sprout** | 8×10 to 10×12 | 10-14 | 5-7 | Simple chains | 1-2 |
| **Nurturing** | 10×14 to 12×16 | 18-28 | 4-6 | Multi-chains | 2-3 |
| **Flourishing** | 12×16 to 16×20 | 36-50 | 3-5 | Deep blocking | 3-4 |
| **Transcendent** | 16×24+ | 60+ | 2-4 | Cascading locks | 4+ |

### Tutorial Strategy (Pre-Level)

Tutorials run once at game start, separate from main levels. They introduce progressive blocking mechanics with in-game guidance.

1. **Tutorial 1 (Basic Movement)**: 3×9 grid with 3 vertical arrows covering the entire grid. Shows easy clicking to clear vines.
2. **Tutorial 2 (Single Blocking)**: Demonstrates one level of blocking.
3. **Tutorial 3 (Multiple Blocking)**: Demonstrates multiple levels of blocking.
4. **Tutorial 4**: Further progression.
5. **Tutorial 5**: Capstone tutorial.

Tutorials include animated arrows and text hints guiding the player through correct taps.

### Modules & Narrative

- **Structure**: Levels are grouped into **Modules** (typically 15 levels).
- **Reward**: Completing a module unlocks a **Parable** in the player's Journal.
- **Content**: Parables are presented as text with watercolor illustrations, offering spiritual reflection.

## 4. Visual & Audio Design

### Aesthetics

- **Style**: Minimalist, organic, watercolor.
- **Atmosphere**: Calming, serene, "Zen Garden."
- **Modes**: Adaptive Light (warm earth tones) and Dark (cool night shades) themes.

### Color Palette & Meaning

Colors are used functionally to indicate vine roles and difficulty.

| Color | Role | Visual Meaning |
|-------|------|----------------|
| **Moss Green** | Foundation | The "standard" vine. Calming, usually the first to move or the base blocker. |
| **Sunset Orange** | Intermediate | Indicates progress or a secondary layer of blocking. |
| **Golden Yellow** | Quick-Clear | "Free" vines that can often be cleared immediately to open space. |
| **Royal Purple** | Complex | Used for deep blocking chains or "boss" vines in harder levels. |
| **Sky Blue** | Alternative | Suggests alternative paths or strategic options. |

### Audio

- **Music**: Ambient wind loops, soft nature sounds.
- **SFX**:
  - **Slide**: Gentle rustle (leaves moving).
  - **Bloom**: Soft chime or bell when a vine exits.
  - **Blocked**: Dull thud or "wilt" sound.

## 5. Level Design Principles

### Full Coverage Rule (Occupancy)

- **Principle**: Levels should be fully tiled by vines — no empty coordinates in the visible grid.
- **Rule**: **100%** of visible grid cells should be occupied by vines. If a `mask` hides cells, allow **≥99%** coverage of visible cells to permit a reserved visual cell.
- **Reasoning**: Full coverage (or 99–100% when masked) maintains consistent visual density and simplifies generation by making the problem a complete-tiling task for the generator.

### Flow & Blocking

- **Blocking Depth**: The number of vines that must move before a specific vine is free.
  - *Seedling*: Depth 0-1 (Immediate or 1 step).
  - *Transcendent*: Depth 4+ (Requires unraveling a knot).
- **Circular Dependencies**: **Strictly Forbidden**. A vine cannot block another vine that eventually blocks the first vine (A blocks B, B blocks A). This creates unsolvable deadlocks.
- **Directional Balance**: Grids should utilize all four directions (Up, Down, Left, Right) to prevent visual monotony and repetitive gameplay.
