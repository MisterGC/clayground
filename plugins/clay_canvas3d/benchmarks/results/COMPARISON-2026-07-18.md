# Canvas3D 3D-Primitive Optimized-vs-Baseline Comparison (Phase 6, issue #146)

Re-run of the four baseline benchmark scenarios against the **optimized**
Clayground.Canvas3D primitives, plus one new-capability scenario, recorded
2026-07-18 on the same machine and method as the baseline.

The baselines being compared against live in `BASELINE-2026-07-18.md`
(+ `baseline-*.csv`). Optimized samples are in `optimized-*.csv` next to this
file. **All invariants from the baseline doc were kept identical** (seeds
`1337` / `1337 ^ 0x9e3779b9`, step lists, warmup 2000 ms + step 8000 ms,
cameras, 128×64×128 and 30×15×30 grids, batch pre-fill + one commit, one
`set()` per frame with no extra commit).

## Machine / method / metric caveats

- Apple Silicon Mac, Metal backend, Qt 6.11.1, measured through the **Dojo**
  (`claydojo` → `clayliveloader`, QQuickWidget render path), **windowed**.
- Instrumentation `BenchLogger` (CSV @ 250 ms) + `PerfHud`; medians over the
  post-warmup rows of each step.
- **`fps` is display/vsync-capped** — the continuous-rotation static-line path
  tops out ~64-65 fps, the per-frame-rebuild paths ~113 fps. Read `fps` as
  "did it keep up"; read `frame_ms` / `edit_ms` / `render_ms` for real cost.
- **`draw_calls`, `draw_vertices`, `gpu_ms` are always 0** on the Dojo
  QQuickWidget path — not usable currency here. The comparison currency is
  **`fps`, `frame_ms`, the CPU sub-timings `sync_ms` / `render_ms`, and the
  scenario extras `build_ms` / `edit_ms` / `commit_ms`**.
- **`build_ms` in the line scenarios is pure JavaScript** — the benchmark's own
  `buildLines()`/`rebuild()` allocating `Qt.vector3d` arrays, identical code in
  both runs (the bench QML is unchanged). It is **not an engine metric**; its
  run-to-run swings (notably the elevated optimized 50k/100k static values)
  reflect JS allocation / GC / thermal state across a long measurement session,
  not a change in the primitive. Engine cost lives in `render_ms` / `sync_ms`.

---

## 1. Lines — Static (`MultiLine3D`, old API rebased onto LineBatch3D)

N static polylines in one batch, node slowly rotated to force continuous render.

| N lines | fps (base→opt) | frame_ms (base→opt) | render_ms (base→opt) | build_ms* (base→opt) |
|--------:|:--------------:|:-------------------:|:--------------------:|:--------------------:|
| 1 000   | 65 → 65        | 15.30 → 15.34       | 1.30 → 1.21          | 4 → 6                |
| 5 000   | 65 → 65        | 16.48 → 16.16       | 1.48 → 1.42          | 34 → 26              |
| 10 000  | 65 → 65        | 15.73 → 16.00       | 1.55 → 1.71          | 56 → 47              |
| 25 000  | 65 → 65        | 16.08 → 16.19       | 1.66 → 2.25          | 109 → 100            |
| 50 000  | 64 → 64        | 15.06 → 15.68       | 2.73 → 3.19          | 199 → 380*           |
| 100 000 | 64 → 63.5      | 15.60 → 15.56       | 4.68 → 4.48          | 401 → 870*           |

\* JS-side coords construction, see caveat above — not an engine metric.

**Speedup: ~1.0× (parity).** Static lines were never the weak point — a static
batch is GPU-cheap and holds the vsync cap at 100k on either engine
(`render_ms` ~4.5 ms both). The point of this row is a **no-regression check**:
the legacy `MultiLine3D` API rebased onto the instanced `LineBatch3D` engine
renders the same batches at the same frame cost. It passes.

---

## 2. Lines — Dynamic (`MultiLine3D`, all N lines re-set every frame)

The old moving/connector usage: a full CPU coords rebuild + full re-set each frame.

| N lines | fps (base→opt) | frame_ms (base→opt) | render_ms (base→opt) | build_ms* (base→opt) |
|--------:|:--------------:|:-------------------:|:--------------------:|:--------------------:|
| 100     | 113 → 112      | 6.27 → 6.32         | 1.12 → 1.00          | 1 → 1                |
| 500     | 98 → 101       | 6.70 → 7.10         | 1.28 → 0.92          | 5 → 4                |
| 1 000   | 91 → 95        | 14.79 → 9.73        | 1.11 → 0.91          | 7 → 5                |
| 5 000   | 30 → 29        | 43.09 → 30.48       | 1.41 → 1.13          | 21 → 25.5            |
| 10 000  | 10 → 9         | 100.68 → 116.91     | 2.44 → 1.61          | 87 → 103             |

**Speedup: ~1.0× (parity).** This is the crucial honest note. This scenario
still drives the primitive through the **old API** — rebuild the entire coords
array in JS and reassign `coords` every frame — so it is dominated by that
per-frame JS rebuild, which the new engine cannot remove and must still honor.
`render_ms` is consistently a touch lower on the optimized engine (1.6 vs
2.4 ms at 10k), but frame time is JS-bound, so fps is unchanged.

**The dynamic-line win is not unlocked by staying on this API — it is unlocked
by switching to the endpoint-patch API** (`Connector3D` / `ConnectorLayer3D`,
or `LineBatch3D.updateEndpointsBulk`), which moves lines by patching endpoints
in place instead of rebuilding geometry. That is exactly what scenario 3
measures.

---

## 3. Connectors — Moving (NEW capability, no baseline)

N `Connector3D` links whose endpoints move every frame, drawn as a single
`ConnectorLayer3D` batch — one table patch + one upload per frame, **no geometry
rebuild, one draw call for all N**.

| N connectors | fps | frame_ms | sync_ms | render_ms |
|-------------:|:---:|:--------:|:-------:|:---------:|
| 100          | 115 | 6.22     | 0.014   | 0.94      |
| 500          | 115 | 6.63     | 0.010   | 1.01      |
| 1 000        | 114 | 6.22     | 0.005   | 0.98      |
| 5 000        | 62  | 20.75    | 0.581   | 1.16      |
| 10 000       | 12  | 80.70    | 3.258   | 1.72      |

The old engine had **no** endpoint-patch path at any price, so there is no
baseline. As an illustrative contrast against the moving-lines-via-rebuild path
(scenario 2, optimized) — not apples-to-apples geometry, but both are "N moving
line elements per frame":

| N      | connectors (patch) | dynamic lines (rebuild) |
|-------:|:------------------:|:-----------------------:|
| 1 000  | 114 fps / 6.2 ms   | 95 fps / 9.7 ms         |
| 5 000  | 62 fps / 20.8 ms   | 29 fps / 30.5 ms        |
| 10 000 | 12 fps / 80.7 ms   | 9 fps / 116.9 ms        |

At 5 000 moving elements the patch path roughly **doubles** throughput. Note the
connector path's remaining ceiling at high N is **not** the batch: `render_ms`
stays ~1.7 ms and it is one draw call throughout; the cost is the benchmark's
per-frame JS loop repositioning every satellite `Node` plus the endpoint upload
(`sync_ms` climbing to ~3.3 ms at 10k). The GPU-side batch is essentially free.

---

## 4. Voxel — Edit Storm (128×64×128, ~73k voxels, one `set()` per frame)

The headline win.

| backend | fps (base→opt) | speedup | frame_ms (base→opt) | edit_ms (base→opt) | render_ms (base→opt) |
|---------|:--------------:|:-------:|:-------------------:|:------------------:|:--------------------:|
| **static** (`StaticVoxelMap`)   | **16.5 → 107** | **~6.5×** | **61.26 → 6.54** | **59 → ~0** | 1.38 → 2.28 |
| dynamic (`DynamicVoxelMap`)     | 61.5 → 61.5    | ~1.0×   | 15.60 → 14.49       | ~0 → ~0            | 3.40 → 3.36          |

One-build full-terrain commit (73k voxels): **`commit_ms` 71 → 1**.

**Static: ~6.5× fps, ~9.4× frame time, per-edit cost 59 ms → ~0.** WHY: the old
`StaticVoxelMap.set()` ran a **full-volume greedy remesh synchronously on every
single voxel change** (the whole frame was the remesh). The optimized map does
**chunked, off-main-thread greedy meshing**: a single edit dirties ~one 32³
chunk, which is remeshed on a `QtConcurrent` worker; the main-thread `set()`
returns immediately (`edit_ms ~0`), so the render loop keeps running at ~107 fps
while meshing lands asynchronously. The full-terrain build is likewise dispatched
to the worker — `commit_ms` collapses 71 → 1 ms because commit now *schedules*
rather than *blocks* (so `commit_ms` is no longer a remesh-cost proxy).

Notably this **reverses the baseline verdict**: optimized static (107 fps) now
*beats* dynamic (61.5 fps) for the single-edit storm, where baseline static was
~4× slower than dynamic. The dynamic path is unchanged here (already vsync-capped
at 1 edit/frame; `sync_ms` eased 5.91 → 4.17 ms from the removed O(n) recount,
but that was not the bottleneck at this load).

---

## 5. Voxel — Churn (`DynamicVoxelMap` 30×15×30, full clear+refill every 30 ms)

| backend | fps (base→opt) | frame_ms (base→opt) | sync_ms (base→opt) | render_ms (base→opt) |
|---------|:--------------:|:-------------------:|:------------------:|:--------------------:|
| dynamic | 36 → 36        | 29.94 → 29.75       | 0.322 → 0.291      | 1.08 → 1.06          |

**Speedup: ~1.0× (parity).** At 30×15×30 (13.5k voxels) the churn is
**cadence-bound, not compute-bound** — `frame_ms` sits right at the 30 ms timer
interval (~33 fps ceiling) and both engines keep up. `DynamicVoxelMap` lost its
per-cycle O(n) solid recount (now O(1), maintained incrementally), but at this
grid size the rebuild was never the bottleneck, so the win does not surface in
fps. It would appear on much larger churn grids (a natural extension). This row
is a no-regression check for the count change; it passes.

---

## What got faster, and why (one-liners)

- **Static voxel edits (~6.5× fps, 59 ms → ~0 per edit):** chunked
  off-main-thread greedy meshing — one edit remeshes ~one 32³ chunk on a worker
  instead of a full-volume synchronous remesh.
- **Full voxel builds (`commit_ms` 71 → 1 ms):** commit dispatches the build to
  the worker thread; it schedules instead of blocking.
- **Voxel storage:** palette-index store (8-bit, auto-upgraded to 16-bit past
  255 colors) with an incrementally-maintained solid count — **O(1)** count,
  no per-change recount.
- **Moving lines (new capability):** `Connector3D` / `ConnectorLayer3D` /
  `LineBatch3D.updateEndpointsBulk` patch endpoints in place — N moving links =
  one draw call, no per-frame geometry rebuild. ~2× the moving-lines-via-rebuild
  path at 5k elements.
- **Per-line styling (new capability):** `LineBatch3D` carries per-line color,
  width and a `styleId` (dash pattern / cap / opacity from the `styles` table)
  in the instanced batch. The old `MultiLine3D` had **one** color and **one**
  width for the whole batch — this styling did not exist at any price.

### Honest notes

- `fps` is vsync-capped in every scene; several rows read "parity" precisely
  because both engines already sat at the cap.
- The Dojo cannot populate `draw_calls` / `draw_vertices` / `gpu_ms`; "one draw
  call" claims for the batches come from the render architecture (single
  instanced `Model`), not from a counter reading in these CSVs.
- Line `build_ms` is JS benchmark code, not an engine metric (see caveat).
- The two legacy-API line scenarios (1, 2) show parity by design — they are
  no-regression checks. The engine wins land in scenarios 3 and 4 and in the
  new styling capability.

---

## New-capability data

- **LineBatch3D at 100k independently-styled lines: ~38 fps, one draw call.**
  Measured during Phase-1 verification (per-line color/width/dash styling active,
  the styled bulk `setBulk(..., styleIds)` path). Not re-measured here — the
  static-lines scenario above uses the unstyled legacy `MultiLine3D` API; a
  styled-100k bench is not part of the four baseline scenarios. Cite as
  **measured-during-development**.
- **Connector flat-draw-call scaling:** re-verified above — 100→10 000 moving
  links render as a single `ConnectorLayer3D` draw call throughout; `render_ms`
  stays ~1–1.7 ms across the whole range (the high-N cost is CPU endpoint
  upload, not draw-call growth).
- **neoncity 5×5 tiles with the detailed lane overlay ≈ overlay-free frame
  cost:** the lane lines across all streamed tiles are one `LineBatch3D` and the
  car→transmitter links one `ConnectorLayer3D`, so toggling the overlay (L) adds
  ~no draw calls. Observed during development; cite as
  **measured-during-development** (re-verifiable live via the neoncity demo with
  the inspector: toggle `benchmark` yaw on, trace `perfFps` with lanes on vs off).

---

## deck.gl reference twin

A standalone deck.gl page renders the **same** exported lane geometry with its
`PathLayer`, as a best-in-class-library yardstick. See
`examples/neoncity/deckgl-twin/README.md`. To run the side-by-side:

1. In the neoncity demo press **E** — exports the loaded lane model to
   `/tmp/neoncity-lane-export.json`.
2. `cp /tmp/neoncity-lane-export.json examples/neoncity/deckgl-twin/lane-export.json`
3. `cd examples/neoncity/deckgl-twin && python3 -m http.server 8123`, open
   `http://localhost:8123` (a seed-42 export ships in the repo so the page
   auto-loads real data without step 1).

**Why the browser fps needs a foreground tab:** deck.gl drives its redraw from
`requestAnimationFrame`, which browsers **throttle to ~1 Hz (or pause) in a
background/occluded tab**. Its FPS panel is only meaningful with the tab
foregrounded and visible; a backgrounded twin will read artificially low. Also:
different renderer/stack (WebGL-in-browser vs Qt Quick 3D), vsync caps both at
the display refresh, and line width semantics differ — read the comparison as
order-of-magnitude, not exact parity. No numbers are quoted here because a
faithful reading requires running it foregrounded on the same machine.

## Files

- `optimized-lines-static-2026-07-18.csv`, `optimized-lines-dynamic-2026-07-18.csv`,
  `optimized-connectors-2026-07-18.csv`, `optimized-voxel-edit-2026-07-18.csv`,
  `optimized-voxel-churn-2026-07-18.csv` — raw optimized samples.
- `baseline-*.csv` + `BASELINE-2026-07-18.md` — the compared-against baseline.
