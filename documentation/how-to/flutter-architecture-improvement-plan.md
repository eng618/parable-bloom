# Flutter Architecture Improvement Plan — Performance, UX, Maintainability

> Living tracker. Update checkboxes + Progress Log as work lands.
> Scope decisions (2026-09-06): bundle bug fix with improvements · general devices (no low-end-only tuning) · keep both projection modes (long-press single + Show-All FAB) behind a unified model · full upgrade scope allowed.

Related: [System Architecture](../explanation/architecture.md) · App: `apps/parable-bloom/`

## Status

* Current phase: Phase 2 — only camera decoupling (2.6) remains
* Last updated: 2026-09-06
* Progress: 18 / ~40 items

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
- [ ] 2.6 Move camera interpolation out of Riverpod: Flame-local `CameraComponent`/transform holds 60Hz ticks, Riverpod keeps settled state; queue gestures dropped today by `updateZoom:197/updatePanOffset:208` while animating
- [x] 2.7 Unify `min/maxZoom`: single `CameraState.kMaxZoom = 2.5` source; `defaultState()` max 2.0 → 2.5 to match `updateZoomBounds()` — done
- [x] 2.8 Tap ownership unified: cell-level duplicate `lightImpact` removed (`GardenGame.onTapDown` is single owner; long-press `mediumImpact` kept); `onTapIncrement` loop → `LevelTotalTapsNotifier.add(count)` on both screens — done

## Phase 3 — Hygiene & Full Upgrade (P2)

- [ ] 3.1 Single `BoardTransform` helper replacing triplicated `applyCameraTransform` (`projection_lines:50-78` vs `grid:130-159` vs manual `getCellScreenPosition:329-345`)
- [ ] 3.2 Texture loader service replacing racy static `ui.Image?` cache (`vine_component.dart:22-24,40-43`) with eviction + error handling
- [ ] 3.3 Single-source vine style (`settings_providers.dart:97` vs `:124`); fix `_InMemoryBox.noSuchMethod` swallow (`infrastructure_providers.dart:76`); fix duplicate `_backgroundColor=` + ignored `surface/gridColor` (`garden_game.dart:101-128`)
- [ ] 3.4 Split `game_screen.dart` (1270L): extract dialogs, celebration FX, zoom controls, header wiring to widgets
- [ ] 3.5 Dependency upgrade (`apps/parable-bloom/pubspec.yaml:37-56`): `flutter pub outdated` → branch → `upgrade --major-versions` (`flame ^1.35.1`, `riverpod ^3.0.3`, `just_audio`, `firebase_*`, `go_router ^17`, `hive`) with `flutter analyze + flutter test` gate; migrate Flame `TapCallbacks`/`CameraComponent`/`images.prefix` + Riverpod-3 Notifier APIs
- [ ] 3.6 Validate: `task test:all`, `task validate`, screenshot goldens for vines/projections/backgrounds

## Verification Checklist (run per phase)

- [ ] `flutter analyze` clean
- [ ] `flutter test` / `task test:all` green (incl. new projection regression test)
- [ ] Manual: long-press single projection + FAB Show-All + auto-hide while animating
- [ ] Profile run: no jank on zoom/pan/vine-clear; backgrounds correct day/night + simple-vine style

## Progress Log

*Add newest entries at top.*

- `2026-09-06` — 2.1 landed: `GameEventSink` replaces `GardenGameCallbacks` across engine, both screens, and tests. Full suite 726/726 pass, analyze clean. Remains: 2.6 camera decoupling.
- `2026-09-06` — 2.3 landed: single-owner vine state, `update(0)` hacks removed, id-based level check. Full suite 726/726 pass, analyze clean. Remain: 2.1 GameEventSink, 2.6 camera decoupling.
- `2026-09-06` — Phase 2 batch landed: 2.2 listen lifecycle + theme sync, 2.4 vine-state memo, 2.5 solver injection, 2.7 zoom bounds, 2.8 tap/haptics + counter. Bonus bug: vine-style switches never reached Flame (`updateVineStyle` had zero callers) — fixed on both screens. Full suite 726/726 pass, analyze clean. Remain: 2.1 GameEventSink, 2.3 single-owner state, 2.6 camera decoupling.
- `2026-09-06` — Phase 1 batch 2 landed: 1.3 blur gating + off-board cull, 1.5 cell paint/theme hoisting, 1.7 background parallel load + detach + cover-fit, 1.8 timing consolidation (9 constants, 8 files). `flutter analyze` clean, 47/47 related tests pass. Open in Phase 1: grid consolidation eval (1.6), device profiling (1.9).
- `2026-09-06` — Phase 1 batch landed: 1.1 idle-vine caching (`visualVersion` + cached calm color/points), 1.2 shader/paint/leaf-path hoisting, 1.4 projection paint + extension precompute; 0.6 arg-order verified correct. `flutter analyze` clean, 29/29 vine+projection tests pass. Open: blur gating + frustum culling (1.3), viewport clipping (1.4 remainder), device profiling (1.9).
- `2026-09-06` — Phase 0 bridge fix landed: `GardenGame.updateProjectionLinesVisibility` forwards via `updateVisibility()` (+ pure `resolveProjectionVisibility()` helper), `setVisible()` deprecated, `tutorial_flow_screen.dart` wired with provider listens + `_updateProjectionLinesVisibility()` (it never forwarded before). New `test/providers/projection_lines_visibility_test.dart` (7 tests); `flutter analyze` clean, 17/17 projection tests pass. Manual device verify (long-press + FAB) still open. Sealed `ProjectionMode` (0.2/0.3) deferred pending design approval.
- `2026-09-06` — Plan created from architecture review + projection bug trace. No code changed yet.
