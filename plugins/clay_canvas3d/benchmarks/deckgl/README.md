# deck.gl line-rendering benchmark

A standalone deck.gl page that mirrors the Clayground Canvas3D line benchmarks
(`BenchLinesStatic.qml` / `BenchLinesDynamic.qml`) so deck.gl's `PathLayer` can
be measured on the same geometry recipe and the same warmup/measure timing. The
result becomes the "deck.gl" column of the 3-way line-rendering comparison
(old Clayground vs new Clayground vs deck.gl).

## Run it

```bash
cd plugins/clay_canvas3d/benchmarks/deckgl
python3 -m http.server 8124
```

Open `http://localhost:8124/bench.html` in Chrome and **keep the tab
foregrounded and visible** for the whole run (~3-4 minutes). Browsers throttle
`requestAnimationFrame` to ~1 Hz in a background/occluded tab, which would make
every number meaningless -- the harness detects this via the empty-scene probe
and aborts rather than record garbage.

The page auto-runs, advancing through all steps of all scenarios. When it
finishes it writes the full results object to `window.__benchResults` (JSON) and
renders it as a visible `<pre>` block. The live panel (top-left) shows the
current scenario, N, warmup/measure phase, and live fps.

## What it measures

deck.gl 9.3.7 (umbrella scripting bundle from unpkg, same as the neoncity
deck.gl reference twin), `PathLayer`, `OrbitView` orbiting continuously so
deck.gl redraws every frame (it only redraws on change; without the orbit you
would measure an idle page).

- **empty** -- 2 s of pure `requestAnimationFrame` cadence, the display refresh
  sanity number (ProMotion should read ~120 Hz).
- **static** -- N polylines with per-path color and width (deck.gl native
  capability), N in `[1000, 5000, 10000, 25000, 50000, 100000]`.
- **static-dashed** -- same as static but every path dashed via
  `PathStyleExtension`, to show the feature-parity cost. Included only if the
  extension is present in the umbrella bundle.
- **dynamic-rebuild** -- N polylines whose endpoints move every frame, rebuilt
  the idiomatic simple way (fresh JS path-object array + fresh `PathLayer` each
  frame), N in `[100, 500, 1000, 5000, 10000]`. Analog of the Clayground
  "full coords rebuild per frame" path.
- **dynamic-binary** -- same motion via deck.gl's documented faster path:
  pre-allocated typed-array attributes, positions mutated in place each frame
  (only the animated Y is rewritten), handed to `PathLayer` in binary form. No
  per-object accessors, no per-frame JS garbage.

## Geometry recipe

Identical to the QML benches: a deterministic LCG (`state = (state * 1664525 +
1013904223) >>> 0; return state / 4294967296`) seeded `1337`, drawn in the same
order (segments, then start point, then per-segment deltas), so the polyline
point geometry is byte-comparable. Extent 500, height extent 300, 3-6 segments
per polyline. Per-path color (Clayground palette, `index % 4`) and width
(`2.0 + (index % 5) * 0.4`) are derived from the line index only -- no extra RNG
draws -- so they exercise deck.gl's per-path styling without shifting the
geometry sequence.

## Method

Per step: discard the first 2000 ms (warmup), measure the next 8000 ms, record
per-frame delta times, report `median_frame_ms` and `median_fps`
(= 1000 / median_frame_ms). This matches the QML benches (2 s warmup discarded,
8 s measured window, medians over post-warmup samples).

Results for a given run are recorded under
`plugins/clay_canvas3d/benchmarks/results/deckgl-lines-<date>.{csv,md}`.
