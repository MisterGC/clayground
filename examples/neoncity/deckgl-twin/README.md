# neoncity lane overlay — deck.gl reference twin

A standalone web page that renders the **detailed lane model** of the
Clayground `neoncity` demo with [deck.gl](https://deck.gl)'s `PathLayer`.
It consumes the *same* exported lane-line data that Clayground's
`LineBatch3D` draws, so the two renderers can be compared head-to-head on
identical geometry.

This is a reference twin, not a product: deck.gl is a mature,
heavily-optimized WebGL line renderer, so it gives an honest "how fast can a
best-in-class library draw this exact data" baseline to measure Clayground
against.

## Files

| file | purpose |
|------|---------|
| `index.html` | page shell, loads deck.gl from a CDN |
| `app.js`     | data → binary attributes → PathLayer(s), views, metrics |
| `style.css`  | synthwave dark theme |
| `sample-gen.js` | synthetic sample generator (browser + `node`) |

No build step. deck.gl **9.3.7** is pulled from unpkg via a `<script>` tag.

## Serve it

`file://` blocks `fetch`, so serve the directory over HTTP:

```bash
cd examples/neoncity/deckgl-twin
python3 -m http.server 8123
# open http://localhost:8123
```

On load the page tries to fetch `./lane-export.json`. If that file is not
present it shows a hint; click **load synthetic sample** (or drop / open a
JSON file) to render.

## Getting real data from neoncity

Run the neoncity demo and press **E** — it writes the export to
`/tmp/neoncity-lane-export.json`. Copy it next to this page:

```bash
cp /tmp/neoncity-lane-export.json examples/neoncity/deckgl-twin/lane-export.json
```

Reload the page; it auto-loads `lane-export.json`.

## Synthetic sample without the app

```bash
node sample-gen.js > lane-export.json            # ~30k lines, seed 42
node sample-gen.js --lines 45000 > lane-export.json
node sample-gen.js --lines 25000 --seed 7 --tiles 6 > lane-export.json
```

The generator emits the exact export contract (below): a multi-tile grid of
roads, each carrying parallel lane-like polylines with mixed solid and dashed
styles.

## Input format (frozen contract)

```json
{
  "meta": {
    "generator": "neoncity", "globalSeed": 42, "tileSize": 200,
    "tiles": [[tx,tz], ...], "center": [x,z],
    "extent": [minX,minZ,maxX,maxZ], "lineCount": N, "widthUnits": "pixels"
  },
  "styles": [ { "dash": [dashLen,gapLen], "opacity": 1.0 }, ... ],
  "lines": [ { "p": [[x,y,z], ...], "c": "#rrggbb", "w": 2.0, "s": 0 }, ... ]
}
```

- `x`/`z` are the ground plane (metres-ish), `y` is elevation.
- `dash` may be `null`/absent → solid.
- `s` indexes `styles` (absent → 0). `c` accepts `#rrggbb` or `#rrggbbaa`.

## How the rendering mirrors erdblick

The JSON is converted **once** into typed arrays and handed to `PathLayer`
in the documented [binary attributes](https://deck.gl/docs/api-reference/layers/path-layer)
form — no per-object accessor callbacks:

```js
data: {
  length,                       // path count
  startIndices: Uint32Array,    // vertex index at the start of each path
  attributes: {
    getPath:  { value: Float32Array, size: 3 },  // [x, -z, y]
    getColor: { value: Uint8Array,  size: 4 },   // per vertex
    getWidth: { value: Float32Array, size: 1 }   // per vertex
  }
}
```

deck.gl 9 keys binary attributes by the **accessor name** (`getPath`,
`getColor`, `getWidth`), and every attribute must share the same vertex
layout as `getPath` — so colour and width are expanded per vertex rather than
per path. (The older erdblick code used `instanceColors` /
`instanceStrokeWidths`; that naming belongs to a different layer generation
and does **not** apply to deck.gl 9's `PathLayer`.)

World coords are remapped to deck's plane as `[x, -z, y]` so the top-down
`OrthographicView` reads like the Clayground city overview, and the tilted
`OrbitView` keeps elevation (`y`) as "up".

### Layer structure — two PathLayers

Solid and dashed lines are packed into **separate** buffers and drawn by two
`PathLayer`s:

1. `lanes-solid` — plain binary PathLayer.
2. `lanes-dashed` — binary PathLayer + `PathStyleExtension({dash:true})` with
   a `getDashArray` binary attribute (size 2, per vertex).

Splitting keeps the dash extension's attribute off the solid layer and avoids
a binary/extension attribute clash, staying within the ≤3-layer budget. If
`PathStyleExtension` is unavailable in the loaded bundle, dashed lines fall
back into the solid layer (drawn solid) and the meta panel shows
`dash ext: MISSING`.

## What the comparison measures — and caveats

The **metrics panel** shows:

- **FPS (rAF)** — frames per second from `requestAnimationFrame` deltas.
- **FPS (deck)** — deck.gl's own metric when exposed.
- **paths** / **vertices** — total counts in the loaded data.

The **pan/zoom stress** toggle continuously nudges the view target and zoom
every frame to force full redraws — the deck.gl analogue of the Clayground
benchmark-yaw trick — so you measure sustained redraw cost, not an idle
canvas.

Caveats when comparing against Clayground:

- **Different renderers / stacks.** deck.gl is WebGL in a browser; Clayground
  is Qt Quick 3D (native or WASM). Absolute FPS is not apples-to-apples.
- **vsync caps** FPS at the display refresh (usually 60). Numbers above the
  refresh rate are not observable; treat 60 as "comfortably real-time".
- **Browser, GPU, window size and DPI** all move the numbers. Compare on the
  same machine, same window size, same data.
- **Line semantics differ.** deck.gl draws screen-space-width pixel lines with
  rounded caps/joins; Clayground's LineBatch3D may use a different width model.
  Use identical `widthUnits` data and read the comparison as "order of
  magnitude", not "exact parity".
