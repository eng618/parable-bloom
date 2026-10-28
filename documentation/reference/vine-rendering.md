# Vine Rendering — the "Vine Rail" pipeline

Reference for how binds (vines) are rendered and animated. The rail renderer
replaces the legacy per-frame Path painter; both remain reachable through the
`vineRenderModeProvider` flag (`rail` | `legacy`) for A/B regression.

Date: 2026-10-19 (last updated 2026-10-26: real trellis+ivy texture with body-pinned wrap UVs; baked sine-coil atlas removed)

## Why a redesign

The legacy renderer rebuilt mutable snake geometry every frame (O(N) bezier
corner path, O(N) stroke tessellation, ~2N foliage draws per animating vine,
`MaskFilter.blur` gated to the most expensive frames, unclipped off-screen
slides). Root causes of visible segmentation/jank:

1. Per-cell-step ease-out → sawtooth velocity pulse on long binds.
2. Corner rounding recomputed from lerped points → corners pop.
3. Per-frame allocations scaling with vine length.
4. Unclipped, uncullable off-screen travel.

Key insight: a clearing vine is a **rigid shape sliding along a fixed track** —
the tube geometry never changes during a clear, so per-cell interpolation is
unnecessary.

## Architecture

```
lib/features/game/presentation/widgets/
  vine_component.dart          logic owner; owns rail track + controller,
                               per-frame payload assembly, bloom trigger
  vine/vine_track.dart         invariant "rail": baked polyline + corner arcs,
                               uniform samples (pos/normal/fade alpha)
  vine/vine_strip_mesh.dart    sliding-window vertex strip writer (reused buffers);
                               cylindrical-wrap UVs into the real texture
  vine/vine_slide_controller.dart  scalar phase machine (replaces VineAnimator)
  vine/vine_foliage_atlas.dart startup-baked white leaf atlas + quad writer
  vine/vine_rail_draw.dart     per-frame draw payload record
  vine/vine_rail_renderer.dart native pass (drawVertices strips + caps +
                               arrow for textured styles; AA stroked path
                               for the simple style)
  vine/vine_path_painter.dart  legacy painter (legacy mode only; still samples
                               the full-scene JPEG textures)
  vine/vine_animator.dart      legacy step animator (legacy mode only)
  vine/vine_tube_path.dart     legacy corner/arrow geometry (arrow still used)
  vine/vine_metrics.dart       shared visual constants
```

### VineTrack (built once per run)

- Input: head-first `ordered_path`, `headDirection`, grid size, extension arc.
- Centerline = tail→head cell centers (`visualY = (gridHeight-1) - y`,
  origin `(0,0)` lower-left) plus a straight head extension past the board
  edge reserved for the exit slide.
- Corner arcs (quadratic, `VineMetrics.cornerRadius` = 12px, radius clamped
  to lane half-lengths — the same rounding as the legacy `VineTubePath`) are
  baked into a fine polyline and resampled at fixed 8px spacing. Position,
  unit normal, and fade alpha are static per sample.
- Arc `0` sits at the head cell center; negative arcs run back to the tail;
  positive arcs are off-board extension. `windowLength` = baked tail→head
  arc: a moving vine is exactly a window of this length.
- `exitArc` (fade start, board edge) and `exitTriggerArc` (one full cell
  beyond the edge — the bloom trigger) are derived from board geometry.

### Sliding window + vertex strip

- `VineSlideController` advances ONE scalar `headArc` per run; the body is
  always the window `[headArc - windowLength, headArc]`. Slot geometry is
  invariant, so no per-cell interpolation happens anywhere.
- `VineStripMesh.writeWindow` copies the visible window's rows into reusable
  typed-data buffers (`O(window)` float writes) and `Vertices.raw` is drawn
  with one `canvas.drawVertices` per vine — draw calls are independent of
  vine length.
- Cross-tube rows carry 6 columns with a baked alpha feather on both edges
  (`VineMetrics.tubeFeather` = 2px): CanvasKit has no per-edge AA for vertex
  strips, and the feather replaces the legacy blur glow entirely.
- Topology: rows form an **indexed triangle grid** (`VertexMode.triangles`
  plus a two-triangles-per-quad index list), not a chained triangle strip —
  a strip chain across a 6-column row is almost all degenerate triangles
  and renders as hollow dashes. Foliage quads use the same indexed form.
- Per-vertex colors encode tint × fade alpha. The exit fade ramps 1→0 across
  `VineMetrics.exitFadeArc` (63px) past the board edge, replacing the
  unclipped "draw until fully off-screen" travel and making frustum culling
  valid again.
- Tube width varies by style: `VineMetrics.tubeWidth` (13px) for the flat
  vector stroke, `VineMetrics.texturedTubeWidth` (15px) for the textured
  skins — the wrapped-vine pattern needs the extra width to read.

### Skin texture: real trellis+ivy with body-pinned wrap UVs

Textured styles sample the real trellis/ivy texture images
(`assets/art/classic_vine_texture.png`, `blossom_vine_texture.png`,
`ethereal_vine_texture.png`) instead of a baked atlas — this is what gives
the wood grain and vine wrapping their natural, non-repeating look.

Each texture is wrapped around the tube with **cylindrical wrap UVs** pinned
to the vine body:

- `v` (along the tube axis) = `(rowArc − headArc + uvPhase) × (texHeight /
  textureRepeatArc)`, wrapped into `[0, texHeight)`. Because `v` is
  body-relative, the texture is pinned to the rigid vine and travels with it
  as it slides — no more arbitrary world-anchored slices that looked like
  random color bands.
- `u` (around the tube's circumference) = a narrow per-column bark sliver
  centered on `texWidth/2`, so the tube reads as a single wood dowel strip.
- `uvPhase` is a per-vine offset (deterministic from the vine id) so vines
  sample different parts of the trellis image.

`VineMetrics.textureRepeatArc` (63px) is the body arc over which the
texture advances one full vertical cycle. `VineMetrics.textureUPerPx`
(2.5) scales the cross-tube bark sliver. One `ImageShader` per texture
(image px, repeated in both axes); draw-time vertex tint stays white so the
real bark/vine detail shows. A failed clear attempt modulates the strip with
`VineMetrics.witheredColor`, turning dead vines brown naturally (like dead
vines on wood) — no separate withered tile needed.

The old baked sine-coil atlas and its choppy repeating oval "buds" are gone;
the real texture carries the vine detail, with head/tail distinction still
provided by round caps and the arrow head in the style's accent color
(flat fill, brown when withered).

- Idle vines freeze their built `ui.Vertices` (keyed on tint × skin tile);
  animating vines rebuild only the window each frame.

### Simple render pass (stroked path)

The `simple` style does **not** render through the vertex strip: `drawVertices`
is never edge-anti-aliased (Impeller or CanvasKit), so a crisp flat look is
impossible there. Instead it strokes the baked centerline — a vector-crisp,
DPI-independent pass:

- `VineTrack.windowPath(headArc, windowLength)` cuts the fine baked centerline
  (the exact legacy `buildRoundedTube` geometry) at both window edges,
  interpolating mid-corner when an edge lands inside a corner arc.
  `O(fine points in window)` per frame — a few hundred points for a 40-cell
  bind; idle vines cache the built `Path` tint-keyed like the `Vertices`.
- Draw = one `drawPath` stroke (`VineMetrics.tubeWidth`, round cap, round
  join, flat tint, no shader/blur) + one solid `VineTubePath.buildArrowHead`
  triangle at the head. Tail cap coverage comes free from the round stroke
  cap.
- Exit fade is uniform: the whole vine's alpha follows the head through the
  `exitFadeArc` band (`tint × fadeAlphaAt(headArc)`), instead of a
  per-vertex gradient. Tail and head vacate simultaneously, so the slide-out
  reads as one object dimming as it leaves.

### VineSlideController (phases)

- **Clear run**: single global ease (`easeInOutSine`) `s: 0 → exitArc +
  windowLength + exitFadeArc`; one smooth velocity profile, no per-step
  easing. Adaptive pacing keeps the legacy `VineMetrics.stepDurationFor`
  contract (>12 planned steps → 0.035s). `justExitedBoard` fires once at
  `exitTriggerArc` (bloom parity with the legacy head-exit check).
- **Blocked run**: eased forward to `approachArc` (the solver's
  `getDistanceToBlocker` remains the single blocking truth), then eased back
  home; `justReachedBlocker` maps to `markVineAttempted`,
  `justReturnedHome` returns the state to `VineAnimationState.normal`.
- Final `justFinished` on a clear run waits for the bloom effect timer, then
  the flow (`VineAnimationState.cleared` → `notifyVineCleared` → remove)
  proceeds unchanged.

### Withered state (failed clear attempts)

A blocked clear attempt is a stateful swap, driven by solver truth:

- `VineComponent.slideOut` resolves the run with the solver's
  `getDistanceToBlocker` **sign preserved**: positive → clear run,
  negative → blocked run traveling `distance.abs()` cells so the head
  visibly reaches the blocker (parity with the legacy animator's
  `rawDistance.abs()`), then returns home. `justReachedBlocker` fires
  `markVineAttempted`, which flips `hasBeenAttempted` + `isWithered` in
  `VineStatesNotifier` (and decrements grace).
- From then on (for the session) the vine renders withered in every rail
  pass: the strip selects the baked withered skin tile, foliage quads tint
  warm bark brown, caps/arrow head go brown, and the flat/simple stroke
  swaps to `VineMetrics.witheredColor`. Motion never changes.
- The idle caches key on tint × skin tile, so the flip rebuilds even when
  the vine is not moving.

### Foliage (one startup bake, zero per-leaf canvas draws)

- `VineFoliageAtlas.bake()` renders five white tiles via `PictureRecorder`
  - `toImageSync` (classic leaf A/B mirrors, ethereal core, ethereal glow
    halo, blossom flower). At draw time vertex colors modulate the atlas —
    the same `texture × color` contract as the legacy painter.
- `VineFoliageMesh` writes one quad (classic/ethereal: two mirrored
  rotated quads + optional glow) per stride cell of the body window; quads
  travel with the vine and rotate through corners using sampled track
  normals. One `drawVertices` per vine regardless of leaf count. The
  foliage tint comes from the layer: the vine's calm palette color while
  healthy, `VineMetrics.witheredColor` when withered.
- `Simple` style skips foliage (and the strip) entirely — see the simple
  render pass above.

## Constants pinned by tests

`13px` flat tube (`VineMetrics.tubeWidth`), `12px` corner radius, `42px`
lane pitch, `8px` sample spacing, `2px` feather, `63px` exit fade, `15px`
textured tube width, `63px` skin tile length (1.5 cells per vine coil),
adaptive step pacing — asserted in `test/vine_track_test.dart`,
`test/vine_strip_mesh_test.dart`, `test/vine_slide_controller_test.dart`.
Per-frame cost is benchmarked in `test/vine_rail_benchmark_test.dart` (a
60-cell multi-turn bind must write + rebuild its strip — and rebuild its
simple-window path — in well under 1.5ms per frame). Window-path edge cuts
and length invariants are asserted in `test/vine_track_test.dart`.

## Renderer selection

`vineRenderModeProvider` (persisted in Hive, default `rail`) flows through
`GameScreen` → `GardenGame.updateVineRenderMode` → `VineLayerComponent`.
`legacy` keeps the previous painter/animator pipeline byte-for-byte; the
legacy code is scheduled for deletion after visual sign-off (see plan
`~/.opencode/plan/vine-rail-redesign.md`).
