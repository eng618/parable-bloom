# 🌿 Parable Bloom Documentation

Welcome to the **Parable Bloom** technical and design documentation. This documentation is organized according to the **[Diátaxis documentation framework](https://diataxis.fr/)**, structuring information across four distinct modes to serve different reader goals.

```
                   Practical Steps
                         ▲
                         │
        [TUTORIALS]      │      [HOW-TO GUIDES]
   Learning-oriented     │     Task-oriented
   Get started & build   │     Solve specific problems
                         │
◄────────────────────────┼────────────────────────►
  Study / Exploration    │     Work / Production
                         │
       [EXPLANATION]     │      [REFERENCE]
  Understanding-oriented │     Information-oriented
  Concepts & philosophy  │     Specs, schemas, tokens
                         │
                         ▼
                  Theoretical Knowledge
```

---

## 📚 Documentation Quadrants

### 🎓 1. [Tutorials](tutorials/README.md)

*Learning-oriented lessons that take newcomers by the hand to get up and running.*

- **[Developer Getting Started](tutorials/getting-started.md)** — Step-by-step setup, running the app, playing the 5 progressive lessons, and running tests.

---

### 🛠️ 2. [How-To Guides](how-to/README.md)

*Task-oriented recipes for accomplishing specific real-world tasks.*

- **[Automated Release Process](how-to/release-process.md)** — Conventional Commits, Nx Release, Fastlane, Bitwarden Secrets Manager (`bws`).
- **[Store Onboarding](how-to/store-onboarding.md)** — App Store Connect and Google Play Console onboarding questions & setup.
- **[Level Generation & Repair](how-to/level-generation.md)** — Generating, rendering, validating, and repairing levels with Go CLI tooling.
- **[App Store Listings & ASO](how-to/app-store-listings/README.md)** — Metadata, visual asset guides, marketing copy, and compliance checklists.

---

### 📖 3. [Reference](reference/README.md)

*Information-oriented technical descriptions, data schemas, design tokens, and compliance specifications.*

- **[Level System Specification](reference/level-system.md)** — JSON data format, coordinate system, occupancy rules, and validation checks.
- **[Color System & Token Usage](reference/color-usage.md)** — Semantic palettes, dark/light themes, hex codes, and vine color mappings.
- **[Scripture Licensing & Compliance](reference/scripture-licensing.md)** — Legal guidelines, copyright notices, and translation usage limits.
- **[Third-Party Attributions](reference/attributions.md)** — Software licenses, audio credits, and graphical asset notices.
- **[Launch Readiness Audit](reference/launch-readiness-audit.md)** — Audit findings catalog and pre-launch verification checklist.

---

### 💡 4. [Explanation](explanation/README.md)

*Understanding-oriented discussions, conceptual architecture, and design rationale.*

- **[System Architecture](explanation/architecture.md)** — Flame engine integration, Riverpod state management, Hive persistence, Firebase sync strategy, and monorepo structure.
- **[Game Design Philosophy](explanation/game-design.md)** — Arrow puzzle mechanics, grace system design, and parable progression.
- **[Scripture Library & Reward Model](explanation/scripture-library.md)** — Dynamic translation delivery, offline KJV fallback architecture, and journal flow.
- **[Level Builder Algorithms](explanation/level-builder/)** — In-depth explanations of the solver, backtracking, blocking heuristics, circuit breaker, and filler phases.

---

## 🚀 Quick Commands

| Task | Command |
| :--- | :--- |
| **Run Web Game** | `task run` |
| **Run All Tests** | `task test:all` |
| **Run Full Workspace Validation** | `task validate` |
| **Validate Levels** | `task levels:validate` |
| **Generate Module Levels** | `task levels:generate:all` |
| **Bump Version & Tag** | `task release:bump` |
