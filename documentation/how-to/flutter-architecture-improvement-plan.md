# Flutter Architecture Improvement Plan — Performance, UX, Maintainability

> Living tracker. Update checkboxes + Progress Log as work lands.
> Scope decisions (2026-09-06): bundle bug fix with improvements · general devices (no low-end-only tuning) · keep both projection modes (long-press single + Show-All FAB) behind a unified model · full upgrade scope allowed.

Related: [System Architecture](../explanation/architecture.md) · App: `apps/parable-bloom/`

## Status

- Current phase: Phase 3 — remain 3.6 full validation (Flutter side green; Go toolchain broken in this env)
- Last updated: 2026-09-06
- Progress: 24 / ~40 items

## Phase 0 — Projection Lines Bug Fix (P0, bundled)

Root cause: `GardenGame.updateProjectionLinesVisibility()` (`lib/features/game/presentation/widgets/garden_game.dart:225-234`) only calls `setVisible()`, never `updateVisibility()`, so `ProjectionLinesComponent` (`lib/features/game/presentation/widgets/projection_lines_component.dart:80-91,124`) keeps `_hintedVineIds={} / _showAllVines=false` and `render():124` skips all vines. Data flow upstream (FAB `lib/features/game/presentation/screens/game_screen.dart:391-399`, long-press `lib/features/game/presentation/widgets/grid_component.dart:454-469`, providers `lib/features/game/application/providers/gameplay_state_providers.dart:353-387`) is intact.

- [x] 0.1 Replace `setVisible()` call with `updateVisibility(visible:, hintedVineIds:, showAllVines:)` in `garden_game.dart:225-234`
- [ ] 0.2 Introduce unified `ProjectionMode` sealed model (`Hidden` / `SingleVine(id)` / `ShowAll`, single-wins) in `gameplay_state_providers.dart`; keep existing providers as compat façade during migration — deferred pending approval of unification design; bridge now forwards via testable `GardenGame.resolveProjectionVisibility()`
- [ ] 0.3 Migrate `_updateProjectionLinesVisibility()` (`game_screen.dart:1069-1087`) + FAB `toggle()` (`:391-399`) + `onHintVine/onClearHints` callbacks (`:108-127`) to `ProjectionMode` — deferred with 0.2
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
- [x] 1.7 `garden_game.dart`: parallel `Future.wait` background loads, `removeFromParent()` instead of `setOpacity(0)` for simple-vine style, cover-fit scale (no wide-screen letterbox, top-aligned art preserved) — done
- [x] 1.8 Consolidate scattered durations into `AnimationTiming` — done (`tapEffect`, `pondRipple`, `fireworkRipple/Travel`, `autoClearPause`, `levelCompleteDelay`, `guidePulse`, `blockedTapDisplay`, `cameraTick`); call sites in `garden_game`, `grid_component`, tap/pond/fireworks components, both screens, guide overlay, camera providers
- [ ] 1.9 Profile: `flutter run --profile`, check 60fps zoom/pan/clear on mid-range Android + iPhone; record before/after

## Phase 2 — State, Bridge & Camera (P1)

- [x] 2.1 `GameEventSink` interface (`game_event_sink.dart`) replaces the 15-closure `GardenGameCallbacks` struct; `getX()` closures become typed getters, optionals are required methods; `_GameScreenEventSink` / `_TutorialFlowEventSink` hold screen state (same-library private access), `TestGameEventSink` no-op for tests — done, zero `callbacks.` references remain
- [x] 2.2 Move `ref.listen` calls from `build` to `initState` (`_subscribeToProviders()`); theme sync `addPostFrameCallback` → `didChangeDependencies` (`_syncThemeColors()`) — done; also fixed vine-style forwarding to call `updateVineStyle(next)` (previously only `updateSimpleVines`, so classic/blossom/ethereal switches never reached Flame) + same forward added to tutorial screen
- [x] 2.3 Single-owner vine state: `_clearVine` no longer mutates the local mirror (provider recomputes and pushes back via `updateVineStates`); removed `update(0)` force-redraw hacks (`grid_component`, `garden_game` — Flame renders continuously, `update(0)` was a dt=0 no-op); new-level check is now id-based instead of identity — done
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
- [x] 3.6 Validate: Flutter side done (analyze clean, 743/743); Go side now VERIFIED with working toolchain — `lb:lint`/`lb:lint:fix` 0 issues (stats.go errcheck fix confirmed by real linter), `lb:build` up to date, `lb:test` pass (cmd/stats 71.9%); `lint:fix:all` passes end-to-end (flutter+next+lb). Remain: screenshot goldens for vines/projections/backgrounds

## Verification Checklist (run per phase)

- [ ] `flutter analyze` clean
- [ ] `flutter test` / `task test:all` green (incl. new projection regression test)
- [ ] Manual: long-press single projection + FAB Show-All + auto-hide while animating
- [ ] Profile run: no jank on zoom/pan/vine-clear; backgrounds correct day/night + simple-vine style

## Progress Log

_Add newest entries at top._

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
