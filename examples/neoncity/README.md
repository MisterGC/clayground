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
  identical city. Roads stay seamless across every tile border: interior spines
  may change lane count, but feeders reaching a tile edge keep an
  edge-deterministic lane count, so neighbouring tiles agree one-to-one at the
  seam. Toggle-independent generation means the deck.gl twin (below) can be fed
  byte-identical geometry.
- **Detailed lane overlay** — a high-detail lane model layered on the
  road/intersection graph (`lanegen.js`). It is a generic model inspired by
  real automotive lane concepts, not any proprietary spec: road groups are
  curb-to-curb and hold both travel directions; boundaries are first-class lines
  shared between adjacent lanes (N side-by-side lanes → N+1 dividers, each
  emitted once); a road's double center line is two parallel boundaries; dashed
  lane dividers turn solid as they approach an intersection; lane-count
  transitions are explicit tapers where a terminating lane curves into its
  neighbour; and each intersection carries per-maneuver turn lanes plus
  transverse stop lines at every approach. Solid vs. dashed is carried per line
  by a `styleId` into `LineBatch3D`'s frozen style table — the whole model is
  one instanced batch.
- **Traffic + connectors** — cars drive the lanes and each links to its nearest
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
| **L** | toggle the lane overlay |
| **K** | toggle cars |
| **C** | toggle car→transmitter link lines |
| **E** | export the loaded lane model to `/tmp/neoncity-lane-export.json` |
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
