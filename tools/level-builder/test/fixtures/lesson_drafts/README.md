# Lesson Drafts 6–10 (mechanics gap-fill)

Status: SUPERSEDED — the 10-lesson experiment was folded back into a
redesigned 5-lesson arc (shipped `assets/lessons/lesson_1..5.json`, with
`lesson_5.json` rebuilt as the Grand Garden capstone). These fixtures remain
as tested design history: L6's projection demo and L7's blocker shape fed the
new L3; L10's key-frees-two shape fed the new L4; L8's grace text and L9's
pan/zoom text were folded into lessons 2/4/5 instructions.

Design rule learned here (applies to all lessons): a lesson's first-listed
vine must be immediately clearable — the guide overlay suggests the first
non-cleared vine, and the old Lesson 9 violated this (vine_1 blocked),
setting players up for failure.

## Grid-size convention (unified)

`LessonData.fromJson` (Dart) and Go levels now agree on `grid_size` as
`[width, height]` (x-extent first). Drafts use square grids regardless, so
they are robust under either reading.
