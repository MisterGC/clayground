# neoncity

An endless, seed-deterministic synthwave city that streams around a fly camera
— the Canvas3D showcase for large-scale instanced line rendering. Every road's
lane markings across every loaded tile are drawn by a single `LineBatch3D`, and
every car-to-transmitter link by a single `ConnectorLayer3D`, so the whole
overlay costs a flat handful of draw calls no matter how far you fly.

Run it in the Dojo:

```bash
./build/bin/claydojo --sbx examples/neoncity/Sandbox.qml
```

## What it shows

- **Tile streaming** — `TileManager` materializes `CityTile`s in the
  `(2·streamRadius+1)²` Chebyshev neighborhood around the camera, asynchronously
  via QML incubation so appearing tiles never hitch the frame. Tiles past
  `unloadRadius` (= `streamRadius + 1`, a hysteresis margin so the boundary
  doesn't thrash) are destroyed. Fly in any direction and the city is endless.
- **Seed determinism** — the same `globalSeed` (default `42`) always yields the
  identical city. The road network is a continuous arterial GRID: one avenue per
  tile column and one per tile row, each keyed only to that column/row so it runs
  unbroken across every tile border and the two cross in a real 4-way per tile.
  Local streets subdivide the blocks under a minimum parallel spacing and either
  run edge-to-edge or T-terminate at an avenue (a 3-way) — keyed to the shared
  boundary identity, so neighbours always agree at the seam and no road ever ends
  in open ground. Toggle-independent generation means the deck.gl twin (below)
  can be fed byte-identical geometry.
- **Road paint + lane model** — every road carries real painted markings that
  are ALWAYS drawn (road furniture, not map data): a solid white edge line on
  both carriageway edges, a dashed white lane divider and double solid yellow
  centre on the two-lane avenues, a single dashed white centre on the one-lane
  local streets, and white stop bars at every junction approach — all trimmed at
  the paved junction boxes so no paint runs through a crossing. Over that sits a
  toggleable teal *lane model* (`lanegen.js`, the map-data overlay): the
  per-direction lane centerlines offset to the right for right-hand traffic, plus
  junction connectors — continuous cyan tracks that flow tangent-smooth out of
  each incoming lane into every legal outgoing lane, with direction arrowheads
  and open-road chevrons. Solid vs. dashed rides per line as a `styleId` into
  `LineBatch3D`'s frozen style table — each layer is one instanced batch.
- **Traffic + connectors** — cars drive the right-hand lane centerlines and steer
  through the junction connectors of the graph, and each links to its nearest
  transmitter through the shared `ConnectorLayer3D`; N car→transmitter links are
  one draw call, with only the moved endpoints patched per frame.
- **Synthwave look** — a dusk gradient backdrop behind a transparent, toon-lit
  `View3D` with depth fog melting distant tiles into the horizon.

## Controls

| Key / UI | Action |
|----------|--------|
| **WASD + mouse drag** | fly the camera (`WasdController`) |
| **O** | toggle overview (top-down) vs. street-level camera |
| **P** | toggle the `PerfHud` performance overlay |
| **L** | toggle the teal lane-model overlay (painted markings stay on) |
| **K** | toggle cars |
| **C** | toggle car→transmitter link lines |
| **E** | export the loaded painted markings + lane model to `/tmp/neoncity-lane-export.json` |
| **car slider** | target car count: 0 / 100 / 200 / 500 / 1000 / 2000 (split across loaded tiles) |
| on-screen buttons | the same Lanes / Cars / Links / Export toggles, clickable |

The HUD (bottom-left) shows seed, current tile, loaded-tile / building counts,
lane line & point counts, and car/link state. Tweak `globalSeed`, `tileSize`,
and `streamRadius` at the top of `Sandbox.qml` to explore the generator.

**Benchmark yaw:** `CityView3D` exposes a `benchmark` property (no key binding)
that spins the camera continuously so the `View3D` redraws every frame and
`renderStats` reflect real cost. Enable it through the Clayground inspector
(`eval`: `cityView.benchmark = true`) and trace `perfFps` / `perfFrameMs` for a
clean measurement; the `flagInfo()` root function surfaces streaming state to
snapshots and flags.

## deck.gl reference twin

`deckgl-twin/` renders the *same* exported lane geometry with deck.gl's
`PathLayer` as a best-in-class-library yardstick for side-by-side comparison.
Press **E** in the demo to export, copy the file next to the page, and serve it
over HTTP — full instructions (and the honest apples-to-oranges caveats) are in
`deckgl-twin/README.md`. A seed-42 export ships in that directory so the page
auto-loads real data without running the demo first.

## Files

| file | purpose |
|------|---------|
| `Sandbox.qml` | Dojo entry: sets seed / tileSize / streamRadius, hosts `CityView3D`, exposes `flagInfo()` |
| `Main.qml` | standalone fullscreen window entry |
| `CityView3D.qml` | viewport: camera, lighting, fog, HUD, the shared `LineBatch3D` / `ConnectorLayer3D`, and `TileManager` |
| `TileManager.qml` | camera-following tile streaming (incubated load, hysteretic unload) |
| `CityTile.qml` | one tile: buildings, road/lane geometry, transmitters |
| `CarSystem.qml` | per-tile traffic + connector links |
| `citygen.js` | deterministic road/intersection/building generator |
| `lanegen.js` | detailed lane model layered on the road graph |
| `cargen.js` | deterministic car placement / motion |
| `deckgl-twin/` | standalone deck.gl comparison page |
