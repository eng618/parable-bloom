---
title: "ParableWeave – Master Documentation Index"
version: "3.4"
last_updated: "2025-12-24"
status: "Snake Mechanics & Module System Implementation Complete"
type: "Master Index"
---

# ParableWeave – Master Documentation Index

## 🌿 Welcome to ParableWeave

**ParableWeave** is a **zen hyper-casual arrow puzzle game** with faith-based themes, where players tap directional vines to slide them off a grid in the direction of their head, mimicking Snake's movement. Body segments follow as a queue, and blocked vines animate back with spiritual messaging.

---

## 🎮 Core Gameplay

- **Snake-Like Movement**: Vines slide in head direction with body segments following as queue.
- **Grace System**: 3 Grace per level (4 for Transcendent), "God's grace is endless—try again!" messaging.
- **Module Structure**: 5 modules with 15 levels each, unlocking parables in the Journal.
- **Strategic Depth**: Blocking is dynamic—clearing one vine unblocks others.
- **Faith Integration**: Parables reveal spiritual reflections and scripture.

## 🛠️ Technical Architecture

- **Riverpod**: Reactive state management with providers for module progress, grace, vine states, and level data.
- **Hive**: Local persistence for module progression, grace system, and settings.
- **Flame**: 2D game engine with custom vine components and snake-like animations.
- **LevelSolver**: BFS-based solver ensuring all levels are solvable with directional path mechanics.

---

## 📚 Documentation Index

- **[GAME_DESIGN.md](GAME_DESIGN.md)** - Detailed mechanics, visual style, and design philosophy.
- **[TECHNICAL_IMPLEMENTATION.md](TECHNICAL_IMPLEMENTATION.md)** - Technical details on the Riverpod/Hive setup and level validation logic.
- **[ARCHITECTURE.md](ARCHITECTURE.md)** - High-level overview of state management, persistence, and the Cloud-ready Firebase roadmap.

---

## 🚀 Success Metrics

- **Performance**: Constant 60 FPS on mid-range mobile devices.
- **Quality**: 100% solvable levels verified by automated BFS validation.
- **Scalability**: JSON-based level loading system allowing for infinite content expansion.

---
