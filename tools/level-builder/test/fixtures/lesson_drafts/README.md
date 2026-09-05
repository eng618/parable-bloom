# Lesson Drafts 6–10 (mechanics gap-fill)

Status: PROMOTED — copies live in `apps/parable-bloom/assets/lessons/lesson_6..10.json`,
registered in `modules.json` (tutorials + level_mappings), and the app's lesson
count (`LessonData.totalLessons = 10`) covers them. These fixtures remain as the
tested source of truth (`pkg/validator/lesson_drafts_test.go`).

Promotion checklist (done):

1. [x] Copy to `apps/parable-bloom/assets/lessons/lesson_N.json`.
2. [x] Append `"lesson_N"` to `tutorials` in `assets/data/modules.json`.
3. [x] Widen Dart lesson-count guards (now `LessonData.totalLessons`).
4. [x] Starter scripture trigger moved to the capstone (`lesson_10`).
5. [x] Run `task levels:tutorials:validate` and
   `task levels:tutorials:validate-solvable`.

## Grid-size convention (unified)

`LessonData.fromJson` (Dart) and Go levels now agree on `grid_size` as
`[width, height]` (x-extent first). Drafts use square grids regardless, so
they are robust under either reading.
