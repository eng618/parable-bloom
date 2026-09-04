# Screenshot Planning Template

_Use this template to storyboard the screenshots before handing off to a designer or generating the final assets._

**Overall Theme/Style**: Light + dark pairs, unframed gameplay captures at 1080x2424. Captured via `task release:android:screenshots` (Flutter drive + `integration_test/app_screenshots_test.dart`). Current set: 8 files in `apps/parable-bloom/android/fastlane/screenshots/en-US/`.

---

### Screenshot 1 (Search Result / Core Value)

_The most important image, often the only one a user sees._

- **Visual Focus**: Home garden screen (`emulator_5554_01_home_light/dark.png`)
- **Top/Bottom Caption**: "Find peace in puzzles."
- **Notes**: Lead with light variant; logo visible in header

### Screenshot 2

- **Visual Focus**: Core gameplay with vines on grid (`emulator_5554_02_gameplay_light/dark.png`)
- **Top/Bottom Caption**: "Guide vines through gardens of grace."
- **Notes**: Shows Snake-like movement mid-puzzle

### Screenshot 3

- **Visual Focus**: Level-complete bloom moment (`emulator_5554_03_win_light/dark.png`)
- **Top/Bottom Caption**: "Clear every vine to bloom the level."
- **Notes**: Celebration state converts best

### Screenshot 4

- **Visual Focus**: Scripture journal (`emulator_5554_04_journal_light/dark.png`)
- **Top/Bottom Caption**: "Unlock the parables of Jesus."
- **Notes**: Differentiator vs secular puzzlers; include in first 4 (visible without scrolling)

### Screenshot 5

- **Visual Focus**: [Framed/marketing version for featuring — future]
- **Top/Bottom Caption**: [e.g., "105 levels. Offline. No ads."]
- **Notes**: [Optional `frameit` pass before production featuring]
