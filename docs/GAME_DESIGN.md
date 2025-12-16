# ParableWeave - Complete Game Design Document

## Welcome to ParableWeave

**ParableWeave** is a faith-based mobile puzzle game that combines engaging vine-untangling mechanics with Christian biblical parables. Players strategically tap interwoven vines in the correct sequence to clear a grid-based board, gradually revealing scripture-based stories and teachings.

---

## 🎯 Executive Summary

### Core Concept

The game presents players with a grid filled with tangled vines that never overlap but block each other's paths—similar to a circuit board or interlaced snakes. Players must identify and tap vines in the proper order to untangle them without being blocked. As vines clear, biblical parables are progressively revealed, creating a meaningful connection between puzzle-solving and spiritual learning.

### Target Audience

- Christian mobile gamers seeking faith-enriching entertainment
- Casual puzzle enthusiasts aged 13-65
- Faith communities and church groups
- Parents seeking wholesome gaming content for families

### Unique Value Propositions

**Spiritual Engagement**: Unlike traditional puzzle games, ParableWeave integrates biblical teachings organically into gameplay, making scripture discovery the reward for puzzle completion.

**Simple Yet Deep**: Minimalist mechanics that are easy to learn but require strategic thinking to master, with complexity scaling through level design rather than feature bloat.

**Scalable Content**: JSON-driven level architecture allows for rapid expansion of content, seasonal updates, and community-created puzzles without code changes.

---

## 🎮 Core Game Mechanics

### Non-Overlapping Path-Based Design

**Previous Model**: Vines could overlap; blocking occurred through layering (top vine blocks bottom vine)

**NEW Model**: Vines **NEVER overlap or occupy the same cell**. Blocking occurs through **path dependency**—vines touch each other and must be cleared in specific sequences to untangle the entire grid.

**Visual Reference**: Circuit board routing puzzle (like your attached image) where each wire/path is independent but interconnected.

### The Blocking System

Vines block through **adjacency relationships + explicit dependencies**, not layering:

**Type 1: Head-to-Body Blocking**

- Vine A's endpoint touches Vine B's body (middle segment)
- Result: Vine A cannot be tapped until Vine B is cleared
- Reason: Physically tangled—A's endpoint is caught in B

**Type 2: Path Dependency (The Key)**

- Vine A and Vine B are adjacent but DON'T occupy the same cells
- Explicit JSON relationship: "Vine A blockingVines: [Vine B]"
- Physical metaphor: Two vines intertwined alongside each other
- Must clear one before untangling the other

**Type 3: End-to-End at Junction**

- Vine A's endpoint meets Vine B's endpoint at same cell
- They connect but don't overlap (they end there)
- Explicit blocking relationship determines which must clear first

### Physical Metaphor

Imagine actual vines on a trellis:

- Two vines can grow intertwined side-by-side (adjacent cells)
- One vine's root/endpoint might be wrapped around another's stalk
- To untangle, you must remove the outer vine first
- Once removed, the inner vine can be lifted away

---

## 📋 Fundamental Gameplay Rules

### Rule 1: Grid Occupancy (CRITICAL)

**Each cell can only contain ONE vine segment. No overlapping, no stacking.**

```
✅ VALID Grid (3×3)
[Vine A] [Vine A] [Vine B]
[Vine C] [empty] [Vine B]
[empty] [Vine C] [Vine B]

❌ INVALID Grid (violates non-overlap rule)
[Vine A + Vine B] ← Both vines in same cell = NOT ALLOWED
```

### Rule 2: Vine Paths

Each vine is a **continuous orthogonal path**:

- Moves only up, down, left, right (no diagonals)
- No gaps in the path
- Must be connected; can't have disconnected segments
- Minimum length: 3 cells
- Maximum length: Can span entire grid (limited by puzzle clarity)

### Rule 3: Blocking Relationships

A vine is **blocked** if:

1. Other vine(s) are explicitly listed in its `blockingVines` array, AND
2. Those blocking vines haven't been cleared yet

**CRITICAL**: Blocking is **explicit in JSON**, not inferred from geometry.

Why? Two vines can be adjacent without blocking—the designer specifies which adjacencies represent blocking tangles.

### Rule 4: Tappable Vines

A vine is **tappable** if:

- Its `blockingVines` array is empty (no other vine blocks it), OR
- All vines in its `blockingVines` array have already been cleared

**Interaction**: When player taps a cell with a tappable vine:

1. Vine animates off the board (fade + dissolve + particles)
2. Grid cells occupied by that vine become empty
3. System re-evaluates all remaining vines for tappability
4. Update visual highlights (glow on newly tappable vines)

### Rule 5: Invalid Tap Feedback

When player taps a **blocked vine**:

- Soft shake animation or subtle error tone
- Optional tooltip: "Blocked by [Vine Name]"
- **No penalty, no move count increment**—maintaining peaceful tone

---

## 🏆 Win Conditions & Progression

### Primary Win Condition

**All vines successfully cleared from the board** = Level complete.

### Parable Reveal System

The parable is revealed progressively as vines are cleared, creating narrative momentum:

1. **Initial state**: Background shows blurred/darkened parable illustration
2. **Per-vine reveal**: Each cleared vine reveals a portion of the image and text
   - 5 vines = 20% reveal per vine
   - 8 vines = 12.5% reveal per vine
3. **Final state**: Last vine cleared triggers full reveal animation + complete parable text display

**Visual metaphor**: Clearing vines is like removing obstacles that obscure spiritual truth—the more you solve, the clearer God's word becomes.

### Secondary Success Metrics (Optional Stars)

**3-Star Rating System** (for replayability):

- ⭐ **1 Star**: Complete the level (all vines cleared)
- ⭐⭐ **2 Stars**: Complete without using hints
- ⭐⭐⭐ **3 Stars**: Complete in optimal move count (fewest possible taps)

**Alternative**: Perfect clarity bonus—reveal the parable without any incorrect tap attempts (tapping a blocked vine).

### Failure Conditions

ParableWeave doesn't have a failure state that forces restart, maintaining a peaceful, contemplative tone. However:

**Stuck State Detection**:

- If player makes 15+ consecutive invalid tap attempts (blocked vines), offer hint system
- After 3 minutes on same level without progress, gentle nudge: "Need guidance? Try a hint."

**Soft Failures** (don't end level):

- Tapping blocked vines (visual shake + subtle sound feedback)
- Running out of hints (can continue without hints)

---

## 🎨 Visual Examples & Level Walkthroughs

### Example 1: Linear Chain (Level 1 - Tutorial)

#### Grid Layout (6×6)

```
   0   1   2   3   4   5
0  .   .   .   .   .   .
1  .   .   .   .   .   .
2  [A] [A] [A] [B] [B] [B]
3  .   .   .   .   .   .
4  .   .   .   .   .   .
5  .   .   .   .   .   .

Legend:
[A] = Vine A segment (brown)
[B] = Vine B segment (green)
. = empty cell
```

#### Vine Definitions

```
Vine A (Main):
- Path: [2,0] → [2,1] → [2,2]
- Color: Brown (#8B4513)
- blockingVines: [] (empty - nothing blocks this vine)
- Status: TAPPABLE immediately

Vine B (Branch):
- Path: [2,3] → [2,4] → [2,5]
- Color: Green (#6B8E23)
- blockingVines: ["vine_main"] (Vine A must clear first)
- Status: BLOCKED until A is cleared
```

#### Solution

- **Only valid sequence**: A → B
- **Optimal moves**: 2
- **Parable**: "Branches depend on the vine"

### Example 2: T-Junction (Level 2)

#### Grid Layout (7×7)

```
   0   1   2   3   4   5   6
0  .   .   .   B   .   .   .
1  .   .   .   B   .   .   .
2  .   .   .   B   .   .   .
3  A   A   A   J   C   C   A
4  .   .   .   B   .   .   .
5  .   .   .   B   .   .   .
6  .   .   .   .   .   .   .

Legend:
[A] = Vine A segment (brown - horizontal)
[B] = Vine B segment (green - vertical)
[C] = Vine C segment (gold - branch)
[J] = Junction point [3,3]
```

#### Solution Paths

**Path 1**: B → A → C (3 moves)
**Path 2**: A → C → B (3 moves)

**Key Learning**: Multiple valid solutions exist; order doesn't always matter for efficiency.

### Example 3: Complex Branching (Level 3+)

**Optimal Solution (5 moves)**:

1. Clear A (TAPPABLE)
   - D becomes TAPPABLE

2. Clear B (TAPPABLE)
   - C becomes TAPPABLE

3. Clear D (TAPPABLE)
   - E becomes TAPPABLE

4. Clear C (TAPPABLE)

5. Clear E (TAPPABLE)

---

## 🎯 Strategic Depth Analysis

### Why This Mechanic Creates Strategic Play

**1. Intuitive Physics**

- Players immediately understand physical metaphor
- Blocking makes sense without explanation
- "These vines are tangled together"

**2. Visual Clarity**

- No overlapping means every vine is visible
- Grid-based layout is clear and scannable
- High contrast with parable backgrounds

**3. Emergent Complexity**

- Tutorial: Linear chains (teach blocking)
- Beginner: Simple branching (teach discovery)
- Intermediate: Complex networks (teach efficiency)
- Advanced: Optimized solutions (teach elegance)

**4. Multiple Solutions**

- Most levels have 2-3 valid sequences
- Same number of moves but different paths
- Star system rewards finding optimal order
- Encourages replaying to "beat" previous attempt

**5. Parable Alignment**

- "Vine & Branches" → Hierarchical dependency (spiritual authority)
- "Entangled Roots" → Complex interdependence (community)
- "Harvest Time" → Sequential action toward freedom (redemption)
- Mechanics literally embody spiritual concepts

---

## 📚 Tutorial Progression (Levels 1-5)

### Level 1: The Vine & Branches (John 15)

- **Vines**: 3 in linear chain
- **Goal**: Teach blocking concept
- **Sequence**: Only 1 valid order (A→B→C)
- **Mechanics**: Simple sequential dependency
- **Parable**: Branches depend on vine for nourishment

### Level 2: Good Soil (Matthew 13:8)

- **Vines**: 3 with T-junction
- **Goal**: Teach spatial reasoning
- **Sequence**: 2 valid orders (both 3 moves)
- **Mechanics**: Choice between equally good options
- **Parable**: Good soil receives and produces fruit

### Level 3: The Sower (Matthew 13:1-9)

- **Vines**: 5 radiating from center
- **Goal**: Teach discovery (which vine blocks what?)
- **Sequence**: Multiple paths (5+ valid orders)
- **Mechanics**: Analysis required to understand blocking
- **Parable**: Word sown in different soil conditions

### Level 4: The Mustard Seed (Matthew 13:31-32)

- **Vines**: 6 with core-and-branches pattern
- **Goal**: Introduce efficiency optimization
- **Sequence**: 6-7 moves optimal, but many inefficient paths exist
- **Mechanics**: First hint at "star rating" concept
- **Parable**: Smallest seed grows into largest plant

### Level 5: The Leaven (Matthew 13:33)

- **Vines**: 7 with hidden dependencies
- **Goal**: Challenge and introduce hints
- **Sequence**: 7 moves optimal, hidden blocking discovered through play
- **Mechanics**: Can only find optimal by exploring or using hints
- **Parable**: Hidden action produces visible transformation

---

## 🎨 Visual Design & Art Direction

### Visual Style Guide

**Art Direction**: Minimalist, clean design with warm, inviting colors that evoke natural growth and spiritual themes. The aesthetic should feel hand-crafted but modern, accessible to all age groups.

### Color Palette

- Primary vines: Earthy browns (#8B4513, #A0522D), olive greens (#6B8E23, #808000)
- Accent vines: Deep purples (#6A5ACD), burgundy (#800020)
- Background: Soft cream (#FFF8DC), light beige (#F5F5DC)
- Grid lines: Subtle gray (#E0E0E0)

### Visual Feedback System

#### TAPPABLE Vine (Green State)

- Full bright color (#8B4513 for brown vines)
- Subtle glow/shadow around segments
- Cursor changes on hover
- Slight scale animation (breathing effect)

#### BLOCKED Vine (Gray State)

- Color faded to 40% opacity
- Semi-transparent overlay across segments
- Optional: Small lock icon in center
- Optional: Tooltip on hover: "Blocked by Vine B"

#### CLEARED Cell (Revealed State)

- Cell shows parable background gradually
- Fade in effect (200ms)
- Particle effect with spiritual sparkles
- Sound effect: chime or clear tone

---

## 🛠️ Level Design System

### JSON Level Configuration Format

```json
{
  "levelId": "level_001_vine_branches",
  "levelNumber": 1,
  "title": "The Vine & Branches",
  "difficulty": 1,
  "grid": {
    "rows": 6,
    "columns": 6
  },
  "vines": [
    {
      "id": "vine_main",
      "color": "#8B4513",
      "description": "Main vine trunk",
      "path": [
        {"row": 2, "col": 0},
        {"row": 2, "col": 1},
        {"row": 2, "col": 2}
      ],
      "blockingVines": []
    },
    {
      "id": "vine_branch_north",
      "color": "#6B8E23",
      "description": "Northern branch",
      "path": [
        {"row": 0, "col": 2},
        {"row": 1, "col": 2},
        {"row": 2, "col": 2}
      ],
      "blockingVines": ["vine_main"]
    },
    {
      "id": "vine_branch_south",
      "color": "#6B8E23",
      "description": "Southern branch",
      "path": [
        {"row": 2, "col": 2},
        {"row": 3, "col": 2},
        {"row": 4, "col": 2}
      ],
      "blockingVines": ["vine_main"]
    }
  ],
  "parable": {
    "title": "The Vine & Branches",
    "scripture": "John 15:1-5",
    "content": "I am the true vine, and my Father is the gardener. He cuts off every branch in me that bears no fruit, while every branch that does bear fruit he trims clean so that it will be even more fruitful.",
    "reflection": "How does remaining connected to Christ (the vine) produce fruit in your life?",
    "backgroundImage": "assets/parables/vine_branches.jpg"
  },
  "hints": [
    "Look for vines with no blockers—tap those first",
    "The branches are attached to the main vine",
    "Remove all branches before removing the trunk"
  ],
  "optimalSequence": ["vine_branch_north", "vine_branch_south", "vine_main"],
  "optimalMoves": 3
}
```

### Level Design Template

```json
{
  "levelId": "level_XXX_[name]",
  "levelNumber": XXX,
  "title": "[Parable Name]",
  "difficulty": X,  // 1-5 scale
  "grid": {
    "rows": R,      // Usually 6-10
    "columns": C    // Usually 6-10
  },

  "vines": [
    // Primary vine (trunk/main)
    {
      "id": "vine_main",
      "color": "#8B4513",
      "description": "[Role in parable]",
      "path": [[r,c], [r,c], ...],
      "blockingVines": []
    },

    // Secondary vines (branches/dependent)
    {
      "id": "vine_branch_1",
      "color": "#6B8E23",
      "description": "[Role]",
      "path": [[r,c], ...],
      "blockingVines": ["vine_main"]
    }
    // ... more vines
  ],

  "parable": {
    "title": "[Title]",
    "scripture": "[Book chapter:verse]",
    "content": "[Full parable text]",
    "reflection": "[Meditation question]",
    "backgroundImage": "assets/parables/[level].jpg"
  },

  "hints": [
    "[First hint - broadest]",
    "[Second hint - medium detail]",
    "[Third hint - specific direction]"
  ],

  "optimalSequence": ["vine_1", "vine_2", ...],
  "optimalMoves": N
}
```

---

## 🎵 Accessibility & Additional Features

### Accessibility Options

- **Colorblind Mode**: Replace colors with patterns (stripes, dots, solids)
- **High Contrast**: Thicker vine outlines, stronger cell borders
- **Simplified View**: Show only tappable vines in full color; blocked vines appear grayed out

### Hint System Rules

**Hint Types**:

**Level 1 Hint - Next Vine**:

- Highlights the next vine that should be cleared (green glow)
- Costs 1 hint token

**Level 2 Hint - Sequence Preview**:

- Shows the next 3 vines in order (numbered 1-2-3)
- Costs 3 hint tokens

**Level 3 Hint - Full Solution**:

- Animates the entire solution sequence slowly
- Costs 5 hint tokens
- Only available after 2 failed attempts at the level

### Hint Token Economy

- Start with 5 free hints
- Earn 1 hint per level completed with 3 stars
- Watch ad = 3 hints (optional monetization)
- Daily devotional completion = 5 hints (encourages engagement with parable content)

---

## 🏗️ Level Progression & Unlocking

### Level Unlock Structure

- **Linear progression**: Must complete Level N to unlock Level N+1
- **Chapter system**: Every 10 levels = one parable theme chapter
- **Replayability**: Can replay any completed level to improve star rating

### Parable Collection

- Completed parables saved to "Scripture Journal"
- Each parable includes:
  - Full biblical text
  - Background illustration
  - Reflection question
  - Share button (social media integration)

---

## 🎮 Advanced Mechanics (Progressive Introduction)

### Phase 1 Mechanics (Levels 1-15): Core Blocking

Just basic vine blocking—learn the fundamental rule set.

### Phase 2 Mechanics (Levels 16-30): Color Coding

Introduce vine colors that correspond to parable themes:

- **Brown vines**: Represent earth/foundation (Parable of the Sower)
- **Green vines**: Represent growth/life (Mustard Seed)
- **Purple vines**: Represent royalty/kingdom (Kingdom Parables)

### Phase 3 Mechanics (Levels 31-50): Locked Vines

Some vines have **locks** that require clearing specific other vines first:

- Lock symbol appears on vine
- Tooltip shows: "Clear the brown vine to unlock"
- Adds explicit dependency beyond spatial blocking

### Phase 4 Mechanics (Levels 51+): Special Grid Cells

**Blessed Cells** (golden glow):

- Any vine passing through a blessed cell must be cleared **last**
- Represents sacred ground that should remain covered until ready

**Anchor Points** (fixed nodes):

- Certain grid intersections are immovable "knots"
- Vines passing through anchors are harder to visualize—requires spatial reasoning

---

## 🖼️ AI Asset Generation Prompts

### Vine Sprites (Individual Segments)

**Prompt Template:**

```
PROMPT: "Mobile game asset, single vine segment for puzzle grid,
[COLOR] organic vine with subtle texture, clean vector style,
soft shadows, warm lighting, 256x256px, transparent background,
centered, minimalist design, faith-themed mobile game aesthetic,
slightly curved natural growth pattern, smooth edges, high contrast,
suitable for tile-based grid system"

VARIATIONS:
- Straight vine segment
- 90-degree corner vine segment
- T-junction vine segment
- Cross-junction vine segment

COLORS TO GENERATE:
- Rich brown (#8B4513)
- Olive green (#6B8E23)
- Deep purple (#6A5ACD)
- Burgundy red (#800020)
```

### Background Parable Illustrations

**Prompt Template:**

```
PROMPT: "Biblical parable illustration for mobile game background,
[PARABLE THEME], watercolor style with soft edges, warm color palette,
peaceful composition, suitable for text overlay, subtle depth,
spiritual atmosphere, 1080x1920px portrait orientation,
gentle lighting suggesting divine presence, culturally sensitive,
traditional biblical setting, high detail but not busy,
inspirational and contemplative mood"

EXAMPLE THEMES:
- "farmer sowing seeds in fertile field at golden hour"
- "good shepherd with sheep in rolling green hills"
- "ancient lamp glowing on wooden table in stone room"
- "vineyard with healthy grape vines and workers"
```

### Asset Specifications

| Asset Type | Dimensions | Format | Quantity Needed |
|------------|------------|--------|-----------------|
| Vine segments | 256x256px | PNG (transparent) | 16 (4 types × 4 colors) |
| Parable backgrounds | 1080x1920px | WebP/JPG | 50+ (one per level) |
| UI buttons | 128x128px | PNG (transparent) | 12 |
| Grid texture | 512x512px | PNG (tileable) | 3 variations |
| Particle effects | 32x32px × 8 frames | PNG sprite sheet | 4 effect types |
| App icon | 1024x1024px | PNG | 1 + variations |

---

## 📊 Key Design Rationale

This mechanic creates a **"simple to learn, difficult to master"** curve essential for mobile puzzle success.

The blocking mechanic is intuitive (physical metaphor: tangled ropes), but solving requires genuine strategic thinking. Unlike match-3 games with significant luck elements, ParableWeave rewards pure logic and planning—aligning with the game's spiritual contemplation theme.

### Advantages Over Overlapping Model

| Aspect | Overlapping Model | Non-Overlapping Model |
|--------|------------------|----------------------|
| **Visual Clarity** | Confusing (layering hard to parse) | Crystal clear (separate paths) |
| **Blocking Logic** | Based on z-index (abstract) | Based on relationships (concrete) |
| **Complexity Scaling** | Limited by layers | Scales infinitely with path networks |
| **Art Requirements** | Complex layered rendering | Simple sprite placement |
| **Parable Fit** | Less intuitive | Physically intuitive (actual vines) |
| **Accessibility** | ColorBlind mode harder | Easier (pattern + color-independent) |
| **Strategic Depth** | Moderate | High (graph-based problem solving) |
| **Implementation** | Complex layering logic | Simpler cell-occupancy validation |
| **Mobile Performance** | Higher rendering load | Lower (simpler rendering) |

---

## ✅ Implementation Checklist

### Core Systems

- [ ] Grid cell occupancy validation
- [ ] Path continuity validation
- [ ] Circular dependency detection
- [ ] Tappability evaluation algorithm
- [ ] Clear animation with particles
- [ ] Visual state indicators
- [ ] Sound design
- [ ] Hint system integration

### Level Design

- [ ] JSON level loader with full validation
- [ ] 50+ levels with increasing complexity
- [ ] Parable content for each level
- [ ] Hint system implementation

### Polish & QA

- [ ] Accessibility features
- [ ] Performance optimization (60 FPS)
- [ ] Comprehensive testing
- [ ] User experience refinement

---

*Version 2.0 - Complete Game Design Document*
*Date: December 16, 2025*
*Status: Ready for Development Implementation*
