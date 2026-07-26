# Dynamic Instancing: InstanceList vs DynamicInstances3D (issue #150)

Compares a declarative `InstanceList` (one `InstanceListEntry` QObject per
instance, `position` + `eulerRotation` written every frame) against the
C++-backed `DynamicInstances3D` (per-frame poses packed into one reused
`Float32Array`, a single `updatePoses()` upload per frame). Same orbiting
motion, same fixed camera, recorded 2026-07-19.

## Machine / method

- **Apple Silicon Mac, Metal backend, Qt 6.11.1**, windowed `clayliveloader`
  (QQuickWidget render path).
- Scenario: `benchmarks/BenchInstances.qml` (auto-runs). N boxes orbiting a
  centre, each box advanced every frame; deterministic LCG `seed = 1337` for the
  per-box radius / start angle / height so both backends animate identically.
- Steps: N = `[1000, 5000, 20000]`, each backend, 2 s warmup + 8 s measured.
- Instrumentation: `BenchLogger` (CSV @ 250 ms) + `PerfHud`.
- Same `gpu_ms`/`draw_calls`/`draw_vertices` caveat as the baseline: these are 0
  on the Dojo QQuickWidget path. The real currency is `fps`, `frame_ms`,
  `render_ms`, and — for the dynamic backend — `pack_ms` (`DynamicInstances3D`'s
  own `packMsLast`, the time to pack + write one frame's poses in C++).
- `fps` is display/vsync-capped (~65 here); read it as "did it keep up" and
  `frame_ms` for the actual cost.

## Summary (medians over the measured window)

| N       | backend            | fps | frame_ms | render_ms | pack_ms |
|--------:|--------------------|----:|---------:|----------:|--------:|
| 1 000   | InstanceList       | 65  | 15.4     | 0.97      | -       |
| 1 000   | DynamicInstances3D | 65  | 16.5     | 1.12      | 0.024   |
| 5 000   | InstanceList       | 65  | 16.0     | 0.98      | -       |
| 5 000   | DynamicInstances3D | 65  | 15.4     | 1.19      | 0.054   |
| 20 000  | InstanceList       | 24  | 51.3     | 1.35      | -       |
| 20 000  | DynamicInstances3D | 61  | 15.5     | 1.73      | 0.254   |

## Observations

- **At 20 000 animated instances the backends diverge sharply.** The
  `InstanceList` path collapses to **24 fps / 51 ms** — the frame is dominated by
  20 000 × 2 QObject property writes plus the full instance-table rebuild the
  built-in instancing runs when entries change. `DynamicInstances3D` holds
  **61 fps / 15.5 ms** (~**3.3× the frame rate, ~1/3 the frame time**), because
  the whole frame's poses are packed straight into the 80-byte table in C++ and
  uploaded once.
- **The pack cost is negligible:** `pack_ms` is **0.25 ms at 20 000** instances
  (0.02 ms at 1 000), i.e. the per-frame CPU work of `DynamicInstances3D` is a
  rounding error against a 15 ms frame. `render_ms` stays ~1–2 ms for both — the
  GPU was never the bottleneck; the win is entirely on the CPU update path.
- At 1 000 / 5 000 both backends sit at the vsync cap, so the numbers are equal
  within noise. The declarative path is fine at small counts; the C++ path is
  what keeps large animated fleets real-time.

## Files

- `BenchInstances.qml` — the auto-running page (in `benchmarks/`, loaded by
  `Sandbox.qml` or standalone via `clayliveloader --sbx BenchInstances.qml`).
- `results/instances-2026-07-19.csv` — raw samples (backend / instance_count /
  pack_ms columns).
