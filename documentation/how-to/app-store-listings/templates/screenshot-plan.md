# Screenshot Planning Template

_Use this template to storyboard the screenshots before handing off to a designer or generating the final assets._

**Overall Theme/Style**: Light + dark pairs, unframed gameplay captures at 1080x2424. Captured via `task release:android:screenshots` (Flutter drive + `integration_test/app_screenshots_test.dart`). Output: 12 files in `apps/parable-bloom/android/fastlane/screenshots/en-US/` (6 scenes × 2 themes).

---

### Screenshot 1 (Search Result / Core Value) — Home

_The most important image, often the only one a user sees._

- **Visual Focus**: Home garden screen (`emulator_5554_01_home_light/dark.png`)
- **Top/Bottom Caption**: "Find peace in puzzles."
- **Notes**: Lead with light variant; logo + cross visible in header

### Screenshot 2 — Gameplay (mid-puzzle)

- **Visual Focus**: Board with vines mid-level (~1/3 cleared) (`emulator_5554_02_gameplay_light/dark.png`)
- **Top/Bottom Caption**: "Guide vines through gardens of grace."
- **Notes**: Shows Snake-like vine movement mid-puzzle; not a fresh or completed board

### Screenshot 3 — Level Complete

- **Visual Focus**: Level-complete bloom moment (`emulator_5554_03_win_light/dark.png`)
- **Top/Bottom Caption**: "Clear every vine to bloom the level."
- **Notes**: Celebration state converts best

### Screenshot 4 — Scripture Journal

- **Visual Focus**: Scripture journal (`emulator_5554_04_journal_light/dark.png`)
- **Top/Bottom Caption**: "Unlock the parables of Jesus."
- **Notes**: Key differentiator vs secular puzzlers; include in first 4 (visible without scrolling)

### Screenshot 5 — Settings (Theme toggle)

- **Visual Focus**: Settings screen, Appearance section, Theme tile (`emulator_5554_05_settings_light/dark.png`)
- **Top/Bottom Caption**: "Play your way — light or dark mode."
- **Notes**: Demonstrates light/dark mode toggle as a user-facing feature

### Screenshot 6 — Tutorial

- **Visual Focus**: Tutorial walkthrough screen (`emulator_5554_06_tutorial_light/dark.png`)
- **Top/Bottom Caption**: "A gentle walkthrough for first-time gardeners."
- **Notes**: Shows onboarding / ease of entry. Optional — drop if you need to stay under 8.

### Screenshot 7 — [Framed/marketing version for featuring — future]

- **Visual Focus**: [Framed/marketing version for featuring — future]
- **Top/Bottom Caption**: [e.g., "105 levels. Offline. No ads."]
- **Notes**: [Optional `frameit` pass before production featuring]
