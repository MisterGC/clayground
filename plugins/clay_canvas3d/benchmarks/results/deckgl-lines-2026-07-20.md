# deck.gl Line-Rendering Benchmark (3-way comparison, deck.gl column)

deck.gl `PathLayer` measured on the same geometry recipe and the same
warmup/measure timing as the Clayground Canvas3D line benchmarks
(`BenchLinesStatic.qml` / `BenchLinesDynamic.qml`), recorded 2026-07-20. This is
the **deck.gl** column of the 3-way line-rendering comparison (old Clayground vs
new Clayground vs deck.gl). The compared-against Clayground numbers live in
`BASELINE-2026-07-18.md` and `COMPARISON-2026-07-18.md`.

Harness: `plugins/clay_canvas3d/benchmarks/deckgl/` (`bench.html` + `bench.js`,
see that dir's `README.md`). Raw per-step medians in
`deckgl-lines-2026-07-20.csv`.

## Machine / method

- **Apple M5 Max**, Chrome **150.0.0.0**, deck.gl **9.3.7** (umbrella scripting
  bundle from unpkg, same CDN as the neoncity deck.gl reference twin).
- Renderer: **WebGL 2.0 via ANGLE -> Metal** (`ANGLE Metal Renderer: Apple M5
  Max`). deck.gl ran on WebGL2, not WebGPU.
- Measured **live in the foreground Chrome tab**. `requestAnimationFrame` drives
  the harness; deck.gl orbits its `OrbitView` continuously so it redraws every
  frame (deck.gl only redraws on change).
- Per step: **first 2000 ms discarded (warmup), next 8000 ms measured**; per-frame
  delta times recorded; medians over the ~480 post-warmup samples per step. Same
  discipline as the Clayground baseline.
- Deterministic geometry: LCG `seed = 1337`, drawn in the same order as the QML
  recipe (segments, then start point, then per-segment deltas), so the polyline
  point geometry is byte-comparable. Extent 500, height extent 300, 3-6 segments
  per polyline. Per-path color (Clayground palette, `index % 4`) and width
  (`2.0 + (index % 5) * 0.4`) are derived from the line index only (no extra RNG
  draws), exercising deck.gl's per-path styling without shifting the geometry.

### Display-refresh sanity (empty-scene probe)

Before scenario A, 2 s of empty `requestAnimationFrame`:
**59.9 Hz**. This session's vsync cap was therefore **60 Hz, not the 120 Hz
ProMotion** the Clayground (Qt) runs used. macOS did not ramp the
automation-driven Chrome window to 120 Hz; the empty probe and every rendering
step all sit at the 60 Hz cap. Read every `fps` below as **"held the 60 Hz cap"**,
not "maxed out at 60".

### Metric caveats (important, read before the tables)

- **`median_fps` / `median_frame_ms` are vsync-capped.** Every tested workload
  held 59.9 fps / 16.7 ms. As in the Clayground docs, `fps` answers **"did it
  keep up?"** (deck.gl did, in all 22 steps), not "how fast could it go". Real
  cost lives in the sub-frame columns.
- **`deck_cpu_ms` = deck.gl's `cpuTimePerFrame`** (its main-thread render time per
  frame, deck-reported). This is the most reliable per-frame cost column.
- **`deck_gpu_ms` is 0 across the board — GPU time is unavailable.** deck.gl did
  not populate `gpuTimePerFrame` (the `EXT_disjoint_timer_query_webgl2`
  extension is present but deck returned 0). So **absolute GPU cost is unknown**;
  the honest claim for static is only "within the frame budget".
- **`deck_update_ms` = deck.gl's `updateAttributesTime`** (attribute
  regen/upload). deck accumulates this per ~1 s metrics interval rather than
  strictly per frame, so treat it as a **trend indicator**, not an exact
  per-frame number. It is 0 for static (data never changes) and the dominant
  cost for the dynamic scenarios.
- **`work_ms`** is the harness's own synchronous per-frame main-thread time
  (geometry build for the dynamic scenarios + the `setProps` call). deck.gl
  evaluates path accessors / uploads attributes **after** `setProps` returns
  (inside its own animation frame), so `work_ms` captures only the JS array
  construction, not the upload — it under-states total dynamic cost, which shows
  up in `deck_cpu_ms` / `deck_update_ms` instead. Analogous to the QML `build_ms`
  caveat: JS benchmark code, not an engine metric.

## 1. Static (N polylines, per-path color + width, camera orbiting)

| N lines | fps | frame_ms | deck_cpu_ms | deck_gpu_ms | work_ms |
|--------:|----:|---------:|------------:|:-----------:|--------:|
| 1 000   | 59.9 | 16.7 | 0.45 | n/a | 0.1 |
| 5 000   | 59.9 | 16.7 | 0.68 | n/a | 0.1 |
| 10 000  | 59.9 | 16.7 | 0.67 | n/a | 0.1 |
| 25 000  | 59.9 | 16.7 | 0.71 | n/a | 0.2 |
| 50 000  | 59.9 | 16.7 | 0.71 | n/a | 0.2 |
| 100 000 | 59.9 | 16.7 | 0.70 | n/a | 0.2 |

**Observation:** a static `PathLayer` batch holds the vsync cap from 1k to
**100k** polylines, with deck's per-frame CPU cost essentially **flat at
~0.5-0.7 ms** (one instanced draw call; data is uploaded once and never touched
again, so `deck_update_ms` is 0). This mirrors the Clayground finding exactly:
static line batches are GPU-cheap and never the weak point. Note deck.gl carries
**per-path color and width natively** here, which the old `MultiLine3D` (one
color/width for the whole batch) could not.

## 2. Static + dashed (same, all paths dashed via PathStyleExtension)

| N lines | fps | frame_ms | deck_cpu_ms | deck_gpu_ms | work_ms |
|--------:|----:|---------:|------------:|:-----------:|--------:|
| 1 000   | 59.9 | 16.7 | 0.74 | n/a | 0.1 |
| 5 000   | 59.9 | 16.7 | 0.74 | n/a | 0.2 |
| 10 000  | 59.9 | 16.7 | 0.73 | n/a | 0.2 |
| 25 000  | 59.9 | 16.7 | 0.75 | n/a | 0.1 |
| 50 000  | 59.9 | 16.7 | 0.73 | n/a | 0.2 |
| 100 000 | 59.9 | 16.7 | 0.74 | n/a | 0.2 |

**Observation:** `PathStyleExtension` dashing on every path costs a **near-nil
constant** over solid (~0.73 ms vs ~0.70 ms `deck_cpu_ms`) and still holds the
cap at 100k. Feature-parity dashing is effectively free on the CPU side here.

## 3. Dynamic — variant "rebuild" (fresh path-object array + fresh PathLayer per frame)

The idiomatic simple update path, and the analog of the Clayground
"full coords rebuild per frame".

| N lines | fps | frame_ms | deck_cpu_ms | deck_update_ms | work_ms |
|--------:|----:|---------:|------------:|---------------:|--------:|
| 100     | 59.9 | 16.7 | 1.23 | 10.2 | 0.3 |
| 500     | 59.9 | 16.7 | 1.52 | 13.1 | 0.4 |
| 1 000   | 59.9 | 16.7 | 1.93 | 16.4 | 0.6 |
| 5 000   | 59.9 | 16.7 | 2.76 | 23.9 | 1.2 |
| 10 000  | 59.9 | 16.7 | 3.96 | 35.4 | 1.8 |

**Observation:** even rebuilding all paths every frame, deck.gl **held 60 fps
through 10 000 moving polylines**. The cost is real and scales — `deck_cpu_ms`
rises 1.2 -> 4.0 ms and the attribute regen/upload trend (`deck_update_ms`)
climbs 10 -> 35 ms — but it stays within (or is pipelined under) the frame
budget, so frame rate does not fall. This is the sharp contrast with the old
Clayground `MultiLine3D` rebuild path, which dropped to ~30 fps at 5k and ~10 fps
at 10k. Caveat: the browser's vsync + async GPU pipeline can hide cost that
exceeds one CPU frame; the rising sub-frame metrics are the honest cost signal.

## 4. Dynamic — variant "binary" (pre-allocated typed arrays, positions mutated in place per frame)

deck.gl's documented faster update path: no per-object accessors, no per-frame
JS garbage — only the animated coordinate is rewritten in a persistent
`Float32Array`, handed to `PathLayer` in binary form.

| N lines | fps | frame_ms | deck_cpu_ms | deck_update_ms | work_ms |
|--------:|----:|---------:|------------:|---------------:|--------:|
| 100     | 59.9 | 16.7 | 1.24 | 12.0 | 0.2 |
| 500     | 59.9 | 16.7 | 1.20 | 12.1 | 0.2 |
| 1 000   | 59.9 | 16.7 | 1.23 | 11.6 | 0.3 |
| 5 000   | 59.9 | 16.7 | 1.50 | 12.4 | 0.5 |
| 10 000  | 59.9 | 16.7 | 1.90 | 12.7 | 0.8 |

**Observation (rebuild vs binary):** both held 60 fps, but the **binary path
barely scales with N** where rebuild scales steeply:

| N      | binary deck_cpu / update | rebuild deck_cpu / update |
|-------:|:------------------------:|:-------------------------:|
| 1 000  | 1.23 / 11.6 ms           | 1.93 / 16.4 ms            |
| 5 000  | 1.50 / 12.4 ms           | 2.76 / 23.9 ms            |
| 10 000 | 1.90 / 12.7 ms           | 3.96 / 35.4 ms            |

At 10 000 moving polylines the binary path's attribute cost is **~2.8x lower**
than the rebuild path (12.7 vs 35.4 ms) and its per-frame CPU roughly **half**
(1.9 vs 4.0 ms). Both share a **fixed ~10-12 ms floor** at low N — the cost of
issuing a new `PathLayer` and diffing it every frame regardless of point count.
This is deck.gl's own "moving lines" story: keep the buffers, patch coordinates,
skip the JS rebuild.

## Honest caveats (cross-engine reading)

- **Different renderer stack.** deck.gl here is **WebGL2-in-Chrome via ANGLE ->
  Metal**; the Clayground numbers are **Qt Quick 3D on native Metal** through the
  Dojo QQuickWidget path. Read the comparison as **order-of-magnitude and
  trend**, not exact parity.
- **Different vsync cap this session (60 Hz vs Qt's 120 Hz ProMotion).** Because
  both stacks are vsync-capped and every deck step held its cap, the **`fps`
  columns are NOT directly comparable across engines**. The meaningful
  cross-engine signals are (a) the **held-cap / dropped-below-cap verdict**, and
  (b) the **sub-frame cost trends**. deck.gl held the cap in every case,
  including the moving-line cases where old Clayground dropped hard.
- **GPU time is unavailable** (deck reported `gpuTimePerFrame = 0`), so absolute
  GPU cost is unmeasured; "static is GPU-cheap" rests on the flat, sub-millisecond
  CPU cost and the sustained cap, not a GPU-time reading. Symmetric to the
  Clayground caveat that `gpu_ms` is always 0 on the Dojo path.
- **`work_ms` is JS benchmark code, not an engine metric** (see caveats above),
  and `deck_update_ms` is an interval-accumulated trend, not an exact per-frame
  value.
- **Dash / width semantics differ.** deck.gl widths are in screen pixels
  (`widthUnits: "pixels"`), rounded caps/joints; dashing via `PathStyleExtension`
  with a fixed `[8, 4]` pattern. The Clayground `MultiLine3D` had a single width
  in world units and no dashing at all — so scenarios 1-2 measure a **richer**
  deck.gl feature set (per-path color/width, optional dash) than the old batch.
- **"median fps" here** = 1000 / (median per-frame delta over the measured
  window). With vsync it reads the display cap whenever per-frame work fits the
  budget; the sub-frame columns are where the actual cost lives.

## Files

- `../deckgl/bench.html`, `../deckgl/bench.js`, `../deckgl/README.md` — the harness.
- `deckgl-lines-2026-07-20.csv` — raw per-step medians.
