# Lesson Drafts 6–10 (mechanics gap-fill)

Drafts only — inert by design:

- The app hardcodes 5 lessons (`lessonProvider` / `completeLesson` /
  `setCurrentLesson` guard `1..5`, `allComplete = length == 5`).
- `validate-tutorials` globs `assets/lessons/lesson_*.json` (this directory
  is not scanned).
- These fixtures live under `tools/level-builder/` so they never ship in the
  Flutter asset bundle (`assets/lessons/` is bundled wholesale).

Covered by `pkg/validator/lesson_drafts_test.go`, which mirrors the Dart
`LessonData.fromJson` constraints plus structural + greedy-solvability checks.

## Promotion checklist (per lesson)

1. Copy to `apps/parable-bloom/assets/lessons/lesson_N.json`.
2. Append `"lesson_N"` to `tutorials` in `assets/data/modules.json`.
3. Widen Dart `1..5` guards to `1..N` in `tutorial_providers.dart`
   (`lessonProvider`, `completeLesson`, `setCurrentLesson`,
   `allComplete = newCompleted.length == N`).
4. Add starter/micro scripture triggers if the lesson should unlock content
   (`modules.json` scriptures + `biblical_themes.json` passages).
5. Run `task levels:tutorials:validate` and
   `task levels:tutorials:validate-solvable`.

## Grid-size convention (unified)

`LessonData.fromJson` (Dart) and Go levels now agree on `grid_size` as
`[width, height]` (x-extent first). Drafts use square grids regardless, so
they are robust under either reading.
