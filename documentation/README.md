# Master Documentation Index

## 🌿 Welcome to Parable Bloom

**Parable Bloom** is a **Christ-centered arrow puzzle game** with faith-based themes, where players tap directional vines to slide them off a grid in the direction of their head, mimicking Snake's movement.

---

## 📚 Documentation Index

### 1. [Game Design (GAME_DESIGN.md)](GAME_DESIGN.md)

The creative vision, core mechanics, progression systems, and visual style.

- **Key Topics**: Snake-like movement, Grace system, Difficulty tiers, Color palettes.

### 2. [Architecture (ARCHITECTURE.md)](ARCHITECTURE.md)

The technical foundation, state management, and deployment strategy.

- **Key Topics**: Flutter/Flame, Riverpod providers, feature-first folder structure, app shell boundaries, Hive persistence, Firebase environment strategy.

### 3. [Level System (LEVEL_SYSTEM.md)](LEVEL_SYSTEM.md)

The technical specification for creating and validating levels.

- **Key Topics**: JSON schemas, Coordinate system, Validation rules, Tooling guide.

### 4. [Release Process (RELEASE_PROCESS.md)](RELEASE_PROCESS.md)

Automation for versioning, changelog, and store deployments.

- **Key Topics**: Nx Release, Fastlane, BWS secrets, store uploads.

### 5. [Store Onboarding (STORE_ONBOARDING.md)](STORE_ONBOARDING.md)

Checklist and guidelines for App Store and Google Play Console release preparation and store listing questions.

- **Key Topics**: Data safety, content rating, store assets.

### 6. [Attributions (ATTRIBUTIONS.md)](ATTRIBUTIONS.md)

Credits and licenses for third-party assets.

### 7. [Launch Readiness Audit (LAUNCH_READINESS_AUDIT.md)](LAUNCH_READINESS_AUDIT.md)

Comprehensive pre-launch audit covering 37 findings across bug review, code readiness, UI/UX, documentation, website alignment, and launch requirements.

- **Key Topics**: Critical blockers, app ID consistency, store assets, attributions, prioritized launch checklist.

### 8. [Scripture Licensing & Compliance (SCRIPTURE_LICENSING.md)](SCRIPTURE_LICENSING.md)

Licensing requirements, approved attribution framework, and technical compliance safeguards for Bible translations.

### 9. [Scripture Library Integration Roadmap (SCRIPTURE_LIBRARY_TEMP_PLAN.md)](SCRIPTURE_LIBRARY_TEMP_PLAN.md)

Temporary design and implementation roadmap for building the scripture library, featuring randomized translation unlocks, journal persistence, and KJV offline fallbacks.

---

## 🚀 Quick Start

1. **Run Application**: `task run`
2. **Validate Workspace**: `task validate`
3. **Generate Levels**: `task levels:generate:all`
