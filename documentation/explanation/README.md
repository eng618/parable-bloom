# 💡 Explanation & Architecture

Explanation documentation is **understanding-oriented**. It provides context, conceptual overviews, architectural rationale, and system design philosophy for Parable Bloom.

It answers "why" things are built the way they are, stepping back from individual tasks to examine the bigger picture.

---

## Available Explanations

### 1. [System Architecture](architecture.md)

In-depth technical architecture and engineering rationale:

- Flutter/Flame engine integration and rendering lifecycle.
- Riverpod state management hierarchy and unidirectional data flow.
- Local persistence via Hive and cloud sync strategy with Firebase.
- Monorepo structure, feature-first folder organization, and app shell boundaries.

### 2. [Game Design Philosophy](game-design.md)

The creative and devotional design foundations:

- Core puzzle loop and snake-like directional mechanics.
- The Grace system: encouraging perseverance over punishment.
- Module progression tied to the parables of Jesus.
- Audio-visual design for calming, reflective gameplay.

### 3. [Scripture Library & Reward Model](scripture-library.md)

Architectural design of the scripture delivery system:

- Reward progression model and journal unlock flow.
- Dynamic translation delivery with offline KJV fallback architecture.
- Schema definitions and test verification strategies.

### 4. [Level Builder Solver & Generation Algorithms](level-builder/)

Deep dive into the algorithmic mechanics of the Go level generation engine:

- **[Backtracking Algorithm](level-builder/backtracking.md)**: Local rollbacks during deadlocked vine placement.
- **[Blocking Heuristics](level-builder/blocking_heuristics.md)**: Controlled complexity and blocking chain generation.
- **[Circuit Breaker Orchestration](level-builder/circuit_breaker.md)**: Execution bounds and failure mitigation in batch generation.
- **[Filler Phase Mechanics](level-builder/filler_phase.md)**: Snake-fill tiling and non-LIFO vine packing.
- **[Incremental Solver](level-builder/incremental_solver.md)**: Sub-state solvability validation during generation.

---

## Diátaxis Navigation

- **[Tutorials](../tutorials/README.md)** — Hands-on learning
- **[How-To Guides](../how-to/README.md)** — Practical problem-solving recipes
- **[Reference](../reference/README.md)** — Technical specifications & schemas
- **[Explanation](../explanation/README.md)** (You are here) — Architecture & design discussions
