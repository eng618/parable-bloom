# Flutter Architecture Improvement Plan — Performance, UX, Maintainability

> Living tracker. Update checkboxes + Progress Log as work lands.
> Scope decisions (2026-09-06): bundle bug fix with improvements · general devices (no low-end-only tuning) · keep both projection modes (long-press single + Show-All FAB) behind a unified model · full upgrade scope allowed.

Related: [System Architecture](../explanation/architecture.md) · App: `apps/parable-bloom/`

## Status

- Current phase: Phase 4 (follow-up batch) complete — device-only items remain
- Last updated: 2026-09-06
- Progress: 32 / ~46 items

## Phase 0 — Projection Lines Bug Fix (P0, bundled)

Root cause: `GardenGame.updateProjectionLinesVisibility()` (`lib/features/game/presentation/widgets/garden_game.dart:225-234`) only calls `setVisible()`, never `updateVisibility()`, so `ProjectionLinesComponent` (`lib/features/game/presentation/widgets/projection_lines_component.dart:80-91,124`) keeps `_hintedVineIds={} / _showAllVines=false` and `render():124` skips all vines. Data flow upstream (FAB `lib/features/game/presentation/screens/game_screen.dart:391-399`, long-press `lib/features/game/presentation/widgets/grid_component.dart:454-469`, providers `lib/features/game/application/providers/gameplay_state_providers.dart:353-387`) is intact.

- [x] 0.1 Replace `setVisible()` call with `updateVisibility(visible:, hintedVineIds:, showAllVines:)` in `garden_game.dart:225-234`
- [x] 0.2 Unified `ProjectionMode` (`showAll` + `hintedVineIds` in one atomic object with value equality) replaces the bool+set provider pair — done
- [x] 0.3 Migrated `_updateProjectionLinesVisibility()` + FAB `toggleAll()` + `onHintVine`/`onClearHints` on both screens to `ProjectionMode`; single listen per screen (was two) — done
- [x] 0.4 Deprecate/remove `setVisible()` (`projection_lines_component.dart:45-47`) so dual-API regression can't recur
- [x] 0.5 Audit `tutorial_flow_screen.dart` for the same broken bridge pattern and fix
- [x] 0.6 Verify `_getVineAtCell(gridY, gridX)` arg order (`grid_component.dart:457` vs `:499`) with long-press log breakpoint — verified correct by inspection (map keyed `(x,y)` from `orderedPath`, lookup `(col,row)`, callers pass `(gridY,gridX)`); only naming is confusing, rename deferred to hygiene phase
- [x] 0.7 Regression test: single-hint shows one line, Show-All shows all, `isAnimating=true` hides, cleared vines skipped (`:117-121`); extend `projection_lines_providers_test.dart`
- [ ] 0.8 Manual verify on device: long-press vine → single line; FAB → all lines; next tap clears hint

## Phase 1 — Rendering Performance (P0)

- [x] 1.1 `vine_component.dart:54-124`: cache resolved color + `points` on `setLevelData`/state change; early-out `render()` when idle and clean — done via `VineAnimator.visualVersion` + cached `_calmColor`/`_cachedPoints`
- [x] 1.2 `vine/vine_path_painter.dart:52-74`: cache `ImageShader` per texture+scale; hoist `Paint`s to static/reusable, precompute leaf `Path` + blossom dots — done (`_shaderCache`, `_leafPathCache`, paints hoisted out of segment loop, blossom paints per-frame); frustum culling still open
- [x] 1.3 Gate ethereal `MaskFilter.blur(5.0)` + leaf glow `blur(3.0)` to animating/clearing only; off-board path culling for clearing vines (cached AABB vs board rect, edge bloom still renders) — done via `drawVine(isAnimating:)`; camera-space culling deferred as low-value (board is small/on-screen by design)
- [x] 1.4 `projection_lines_component.dart`: hoist line `Paint`, precompute `extensionLength` per level — done; viewport clipping deferred (2x off-screen extension is by design, canvas clips)
- [x] 1.5 `CellComponent.render`: hoist dot `Paint` to shared static (both theme branches were the identical beige), drop per-frame `Theme.of` + `toRect()` except on debug-coordinate path — done
- [ ] 1.6 Evaluate single `GridBackgroundComponent` vs N `RectangleComponent` cells (100+ nodes); measure `raster` time before/after
- [x] 1.7 `garden_game.dart`: parallel `Future.wait` background loads, `removeFromParent()` instead of `setOpacity(0)` for simple-vine style, height-fit contain sizing (cover-fit tried and reverted — cropped artwork on wide screens) — done
- [x] 1.8 Consolidate scattered durations into `AnimationTiming` — done (`tapEffect`, `pondRipple`, `fireworkRipple/Travel`, `autoClearPause`, `levelCompleteDelay`, `guidePulse`, `blockedTapDisplay`, `cameraTick`); call sites in `garden_game`, `grid_component`, tap/pond/fireworks components, both screens, guide overlay, camera providers
- [ ] 1.9 Profile: `flutter run --profile`, check 60fps zoom/pan/clear on mid-range Android + iPhone; record before/after

## Phase 2 — State, Bridge & Camera (P1)

- [x] 2.1 `GameEventSink` interface (`game_event_sink.dart`) replaces the 15-closure `GardenGameCallbacks` struct; `getX()` closures become typed getters, optionals are required methods; `_GameScreenEventSink` / `_TutorialFlowEventSink` hold screen state (same-library private access), `TestGameEventSink` no-op for tests — done, zero `callbacks.` references remain
- [x] 2.2 Move `ref.listen` calls from `build` to `initState` (`_subscribeToProviders()`); theme sync `addPostFrameCallback` → `didChangeDependencies` (`_syncThemeColors()`) — done; also fixed vine-style forwarding to call `updateVineStyle(next)` (previously only `updateSimpleVines`, so classic/blossom/ethereal switches never reached Flame) + same forward added to tutorial screen
- [x] 2.3 Single-owner vine state with optimistic mirror exclusion on clear (provider recomputes and overwrites via `updateVineStates`; `cleared` animation state excluded from blocking set; `setAnimationState` single calculated emit); removed `update(0)` force-redraw hacks; new-level check id-based — done
- [x] 2.4 Memoize `_calculateVineStates` by input signature (level + per-vine cleared/animation/attempted/withered); repeat calls with unchanged inputs return cached result — done + `gameplay_state_updates_test.dart`
- [x] 2.5 Solver singleton injected: `GardenGame.solver` (from `levelSolverServiceProvider` in both screens) → `GridComponent.solver`; `getLevelSolverService()` returns shared instance instead of allocating per tap — done
- [x] 2.6 Camera decoupling: 60fps interpolation no longer writes Riverpod state per tick — `GardenGame.applyCameraFrame(zoom:, panX:, panY:)` applies straight to Flame; Riverpod keeps settled state + throttled ~10fps progress writes + final write (~10 notifications vs ~50 per 0.8s animation). Gestures now interrupt/take over instead of being silently dropped (`updateZoom`/`updatePanOffset`/`resetToCenter`); animation futures always resolve (interrupt/dispose complete the completer) — done + `camera_animation_test.dart`
- [x] 2.7 Unify `min/maxZoom`: single `CameraState.kMaxZoom = 2.5` source; `defaultState()` max 2.0 → 2.5 to match `updateZoomBounds()` — done
- [x] 2.8 Tap ownership unified: cell-level duplicate `lightImpact` removed (`GardenGame.onTapDown` is single owner; long-press `mediumImpact` kept); `onTapIncrement` loop → `LevelTotalTapsNotifier.add(count)` on both screens — done

## Phase 3 — Hygiene & Full Upgrade (P2)

- [x] 3.1 Single `BoardTransform` helper (`core/board_transform.dart`, pure-Dart, tested): grid + projection-lines placement + `getCellScreenPosition` all delegate to it — done + `board_transform_test.dart`
- [x] 3.2 `VineTextureLoader` service (per-game shared in-flight load) replaces racy static `ui.Image?` cache in `VineComponent` (now instance fields from the loader) — done
- [x] 3.3 Hygiene: removed duplicate `_backgroundColor` assignment; `UseSimpleVinesNotifier.setEnabled(false)` no longer clobbers blossom/ethereal; `_InMemoryBox.noSuchMethod` throws explicit `UnimplementedError` — done (settings already single-sourced via derived `useSimpleVinesProvider`)
- [x] 3.4 Split `game_screen.dart` (1337→1104 lines): extracted `GameZoomControls` (self-contained ConsumerWidget), `LevelCompleteOverlay(message:)`, `showGameCompletedDialog`/`showGameOverDialog` (pure UI, callbacks for analytics/nav), `_logLevelQuit()` helper — done + `game_screen_widgets_test.dart` (5 tests)
- [x] 3.5 Dependency upgrade: non-majors (`riverpod`/`flutter_riverpod` 3.4.3, `win32` 6.4.0) + majors (`go_router` 18.0.1 — zero code changes; `dynamic_color` REJECTED at 2.x — returns the `material_ui` fork's `ColorScheme`, incompatible with Flutter SDK type — pinned `^1.7.0`). `vector_math`/`mockito`/`intl`/`test` stay on SDK/flame pins — done, suite green
- [x] 3.6 Validate: Flutter side done (analyze clean); Go side VERIFIED with working toolchain — `lb:lint`/`lb:lint:fix` 0 issues, `lb:build` up to date, `lb:test` pass; `lint:fix:all` passes end-to-end. Remain: screenshot goldens for vines/projections/backgrounds

## Phase 4 — Dedup & Polish (follow-up batch)

- [x] 4.1 Tutorial lifecycle parity: listens → `initState`/`listenManual`, theme sync → `didChangeDependencies` (game creation stays guarded in `build` — needs async lesson data)
- [x] 4.2 Projection sync dedup: shared `syncProjectionLines(ref, game)` + `suppressDuringAnimation()` policy on the notifier; `ProjectionMode.hashCode` hashes set contents (was length-only — hint switches could skip rebuilds)
- [x] 4.3 Celebration dedup: shared `kCongratulationMessages`/`pickCongratulationMessage`/`spawnCelebrationEffect` (+ `celebrationSpanSeconds`); tutorial overlay reuses `LevelCompleteOverlay` (fixes missing-title drift); divergent unlock dialogs deliberately left separate
- [x] 4.4 Guide overlay diet: `select` on camera transform values, blocked-tap timer hoisted to `initState` listen, memoized `_firstMovableId`, `RepaintBoundary` around prompt stack
- [x] 4.5 Backfill N+1: one translation pick per run (`_unlockTranslationId`) across backfill/completeLevel/completeLesson; stored values untouched (migration-safe)
- [x] 4.6 Dead-code sweep: removed zero-caller `updateSimpleVines`/`setVisible`/no-op `leafPetals`+`confetti` arms; collapsed `healCurrentLevel` into `resolveLevelToLoad`; fixed dead `previousLevelId` attempt-reset branch (read-before-set now)

## Verification Checklist (run per phase)

- [ ] `flutter analyze` clean
- [ ] `flutter test` / `task test:all` green (incl. new projection regression test)
- [ ] Manual: long-press single projection + FAB Show-All + auto-hide while animating
- [ ] Profile run: no jank on zoom/pan/vine-clear; backgrounds correct day/night + simple-vine style

## Progress Log

_Add newest entries at top._

- `2026-09-10` — Repaired sentry-wizard damage: wizard wrote into the workspace-root pubspec (floating dep, plugin + config in a code-less package). Root restored; `sentry_flutter` bumped to `^9.30.0` + `sentry_dart_plugin ^3.4.0` + `sentry:` config moved to the app pubspec. `pub get` clean, analyze clean, 763/763. Still needed: `SENTRY_AUTH_TOKEN` in CI for symbol/source-map upload.
- `2026-09-10` — Sentry everywhere + animating-tap verdict fix + deploy hardening: new `ErrorReporting` (DSN-gated, web+mobile; `LoggerService` errors route to Sentry, Crashlytics recordError removed — dep+native cleanup deferred), `main` fatal handlers cover web, `SENTRY_DSN` plumbed through all build tasks + deploy-web (empty = disabled; add the secret value in CI); `Grid.setVineAnimationState` optimistically mirrors (proven by `grid_mirror_test`: fails without, passes with); deploy-web gained `workflow_dispatch` prod/preview + resolution logging. Analyze clean, 763/763.
- `2026-09-10` — Released to prod: `main` includes all Phase 0–4 work; Deploy Web succeeded 18:07 UTC. Prod now runs the healing fix, deadlock fix, listenManual fix, ProjectionMode, and constrained widths. Retest checklist for prod (hard refresh first): completed-profile loads first new cloud level (no false CONGRATULATIONS), pan/zoom/buttons on game screen, tutorial has no zoom controls, no dev banner on store builds (needs rebuild), no error screen on macOS debug.
- `2026-09-06` — Phase 4 complete (streams A–F): tutorial lifecycle parity, projection sync dedup + hash fix, celebration dedup, overlay diet, backfill N+1 hoist, dead-code sweep. Net −160 lines lib code. Analyze clean, 758/758. Left: device-only items (0.8, 1.9, goldens) + prod release train.
- `2026-09-06` — Web readability: new `ConstrainedPage` widget (680 text / 440 form widths, phones unaffected) applied to settings, journal list + reflection sheet, pause dialog (440 cap), auth card (440), home (600). AppBars stay full-bleed. +3 widget tests. Analyze clean, 751/751.
- `2026-09-06` — Env plumbing fix: native/web release builds never passed `--dart-define=APP_ENV`, so every store build compiled as `dev` (banner + `*_dev` Firestore). All `build:*` tasks now take `APP_ENV` (default `prod`); release lanes forward it (`task release:android APP_ENV=preview` to override). Verified via `task --dry`.
- `2026-09-06` — Android deploy fix: Play Edits collision ("change made outside of this Edit") now retried with backoff (3 attempts, 15/30/60s) in the `deploy` lane instead of failing the release; override via `GOOGLE_PLAY_UPLOAD_RETRIES`. `ruby -c` clean (lane itself needs creds+AAB to run). Note: fastlane 2.239 available (on 2.238; not the cause, optional bump).
- `2026-09-06` — Follow-ups from local testing: tutorial zoom controls + camera gestures removed (lesson grids auto-frame on load; the screen had no camera listener so gestures never reached Flame — hiding per agreement, re-enable = add the listen); background reverted to height-fit contain (cover-fit cropped the artwork on wide screens). Analyze clean, 748/748.
- `2026-09-06` — Shipped-code regressions fixed: (1) `ref.listen`→`listenManual` in `GameScreen._subscribeToProviders` (Riverpod 3 asserts build context; was crashing macOS debug into the error screen); (2) ghost-blocker deadlock — optimistic mirror exclusion in `_clearVine`, `cleared` state excluded from blocking set, `setAnimationState` single calculated emit (+2 regression tests); (3) Openpanel network failures demoted to debug (were polluting Crashlytics). Analyze clean, 748/748. OPEN: pan/zoom-both-dead on prod web — gestures exonerated (buttons dead too); needs version/hard-refresh check + local repro before code changes.
- `2026-09-06` — 0.2/0.3 landed: unified `ProjectionMode` replaces the bool+set pair (atomic updates, single listen per screen, value equality skips redundant notifies). Both projection UX preserved bit-for-bit. Analyze clean, 746/746.
- `2026-09-06` — Bug still live on prod: fix NOT on `main` (prod deploys from `main` only; fix sits on `develop`). Hardened further anyway: `resolveLevelToLoad()` resolves across BOTH registry sources (mapped pointer wins incl. replay; else first uncompleted mapped; else first mapped; null only when nothing loadable) so no skew can ever show false CONGRATULATIONS; game screen uses it, `healCurrentLevel` delegates. +2 skew tests. Analyze clean, 745/745. SHIP: release develop→main, then hard-refresh prod and retest.
- `2026-09-06` — Go toolchain restored
- `2026-09-06` — 3.5 landed (see item). 3.6 partial: Flutter analyze + 743/743 green; Go build/test/lint unverifiable here — asdf Go installs are gutted (no `src/`, no `vet` tool) and `GOROOT` env points at the workspace; `GOPROXY` empty. Needs toolchain reinstall with network. Same env note: `lint:fix:all` wiring fixed (nx no longer appends `--fix` to go-task), flutter+next fix through it; `lb:lint:fix` fails only on the env issue.
- `2026-09-06` — 3.4 landed: game_screen split + widget tests. Full suite 743/743, analyze clean.
- `2026-09-06` — Phase 3 batch 1: 3.1 BoardTransform, 3.2 VineTextureLoader, 3.3 hygiene. Go lint: fixed 3 `errcheck` hits in `tools/level-builder/cmd/stats/stats.go` (4th identical site too); `task lb:lint:fix` still fails on package loading — GOPROXY empty/offline env issue, needs network. Full Flutter suite 738/738, analyze clean.
- `2026-09-06` — Bugfix (out of band): completed-profile + new cloud levels loaded nothing ("Play Level 1" → false CONGRATULATIONS). Root cause: next level derived solely from stale persisted `currentLevel`, never recomputed when the playlist grows/migrates. Fix: `GameProgress.nextUncompletedLevel()` single source of truth, `GameProgressNotifier.healCurrentLevel()` persists dangling-pointer repair, `_loadLevelForGame` heals before declaring completion and treats empty mappings as load failure (gameOver) not finished, Home displays first-uncompleted number. Plus `level_healing_test.dart` (6 tests). Lint: fixed `await_only_futures` in `modules_registry_fallback_test`. Analyze clean, full suite 735/735.
- `2026-09-06` — 2.6 landed, PHASE 2 COMPLETE. Full suite 729/729 pass, analyze clean. Pausing before Phase 3 for bug triage.
- `2026-09-06` — 2.1 landed: `GameEventSink` replaces `GardenGameCallbacks` across engine, both screens, and tests. Full suite 726/726 pass, analyze clean. Remains: 2.6 camera decoupling.
- `2026-09-06` — 2.3 landed: single-owner vine state, `update(0)` hacks removed, id-based level check. Full suite 726/726 pass, analyze clean. Remain: 2.1 GameEventSink, 2.6 camera decoupling.
- `2026-09-06` — Phase 2 batch landed: 2.2 listen lifecycle + theme sync, 2.4 vine-state memo, 2.5 solver injection, 2.7 zoom bounds, 2.8 tap/haptics + counter. Bonus bug: vine-style switches never reached Flame (`updateVineStyle` had zero callers) — fixed on both screens. Full suite 726/726 pass, analyze clean. Remain: 2.1 GameEventSink, 2.3 single-owner state, 2.6 camera decoupling.
- `2026-09-06` — Phase 1 batch 2 landed: 1.3 blur gating + off-board cull, 1.5 cell paint/theme hoisting, 1.7 background parallel load + detach + cover-fit, 1.8 timing consolidation (9 constants, 8 files). `flutter analyze` clean, 47/47 related tests pass. Open in Phase 1: grid consolidation eval (1.6), device profiling (1.9).
- `2026-09-06` — Phase 1 batch landed: 1.1 idle-vine caching (`visualVersion` + cached calm color/points), 1.2 shader/paint/leaf-path hoisting, 1.4 projection paint + extension precompute; 0.6 arg-order verified correct. `flutter analyze` clean, 29/29 vine+projection tests pass. Open: blur gating + frustum culling (1.3), viewport clipping (1.4 remainder), device profiling (1.9).
- `2026-09-06` — Phase 0 bridge fix landed: `GardenGame.updateProjectionLinesVisibility` forwards via `updateVisibility()` (+ pure `resolveProjectionVisibility()` helper), `setVisible()` deprecated, `tutorial_flow_screen.dart` wired with provider listens + `_updateProjectionLinesVisibility()` (it never forwarded before). New `test/providers/projection_lines_visibility_test.dart` (7 tests); `flutter analyze` clean, 17/17 projection tests pass. Manual device verify (long-press + FAB) still open. Sealed `ProjectionMode` (0.2/0.3) deferred pending design approval.
- `2026-09-06` — Plan created from architecture review + projection bug trace. No code changed yet.
