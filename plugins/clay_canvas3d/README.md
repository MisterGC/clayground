# Canvas3D User Guide

## Overview

The Canvas3D plugin provides components for creating 3D visualizations in
Clayground applications. It offers primitives for 3D boxes, areas, lines, and
voxel-based structures with support for custom edge rendering, toon shading,
and efficient batch rendering.

## Getting Started

To use Canvas3D components, import the module in your QML file:

```qml
import Clayground.Canvas3D
```

### Minimal Example

Here's a simple example showing a red box with dark edges:

```qml
import QtQuick
import QtQuick3D
import Clayground.Canvas3D

View3D {
    anchors.fill: parent

    PerspectiveCamera {
        position: Qt.vector3d(0, 200, 300)
        eulerRotation.x: -30
    }

    DirectionalLight {
        eulerRotation.x: -30
        castsShadow: true
        shadowFactor: 78
        shadowMapQuality: Light.ShadowMapQualityVeryHigh
    }

    Box3D {
        width: 100
        height: 100
        depth: 100
        color: "red"
        useToonShading: true
    }
}
```

## Core Components

### Box3D

The `Box3D` component creates a 3D box with customizable dimensions, edge
rendering, and cartoon-style shading.

#### Creating Non-Uniform Shapes

Use scale properties to create pyramids, trapezoids, and other shapes:

```qml
// Pyramid
Box3D {
    width: 100; height: 100; depth: 100
    scaledFace: Box3DGeometry.TopFace
    faceScale: Qt.vector2d(0.1, 0.1)
}
```

#### Edge Mask Usage

Control which edges are visible:

```qml
Box3D {
    edgeMask: topEdges | bottomEdges  // Only horizontal edges
}
```

### Poly3D

The area primitive: hand it a ring of 2D points and it fills the polygon.
Anything region-shaped — a lake, a plaza, a footprint, a zone on the ground —
is one `Poly3D` rather than a fan of faked strips.

```qml
Poly3D {
    vertices: [Qt.vector2d(-50, -50), Qt.vector2d(50, -50),
               Qt.vector2d(50, 50), Qt.vector2d(-50, 50)]
    color: "#0f9d9a"
    useToonShading: true
}
```

Concave rings are triangulated properly, and `holes` takes inner rings, so a
courtyard is part of the same object rather than a second shape punched
through it:

```qml
Poly3D {
    vertices: [...]                 // outer ring
    holes: [[...], [...]]           // inner rings
}
```

#### Planes and orientation

The ring is 2D, so `plane` decides which two world axes its points map to —
`Poly3D.XZ` (default, flat on the ground), `Poly3D.XY` (a wall) or
`Poly3D.YZ`. Any other orientation is the node's own `eulerRotation`; a
`Poly3D` is a `Model`, so it moves, rotates and scales like anything else.

A polygon lying exactly on another surface will z-fight. Lift it slightly
along its normal — `Model`'s `depthBias` biases the *sort* distance and does
not offset depth, so it is not the fix here.

#### Extrusion

`extrude` turns the same ring into a prism: the polygon is the base, walls
rise along the plane normal, and a cap closes the top. Holes get walls too,
so a ring with a courtyard extrudes into a building with a courtyard.

```qml
Poly3D {
    vertices: [...]
    extrude: 120        // 0 = flat area (default)
    color: "#00d9ff"
}
```

Walls are faceted, never smoothed across the ring, so a hexagonal column
reads as six flat faces under toon shading rather than as a cylinder.

To **animate a prism's height, scale the node** (`scale.y` for `XZ`) rather
than animating `extrude`. Scaling touches no geometry at all; changing
`extrude` rebuilds the mesh.

#### Wireframe

`showEdges` is off by default on `Poly3D` — a box's borders are its look, but
a polygon's triangulation is a deliberate choice. `edgeMode` picks what the
lines mean:

```qml
Poly3D {
    vertices: [...]
    showEdges: true
    edgeMode: Poly3D.Triangles      // or Poly3D.FaceBorders
    edgeThickness: 1.5              // pixels
    edgeColor: "#2f3437"
}
```

- `FaceBorders` — the outline of every ring, plus the seams of a prism.
- `Triangles` — the above plus the triangulation itself, for when the mesh
  is the subject rather than the shape.

Edges are not free: they need one vertex per index instead of a shared,
indexed mesh, which costs roughly 3x the vertex memory for a flat polygon.
That is why the lean layout is the default. The buffer upgrades the first
time edges are switched on and never downgrades, so binding `showEdges` to a
hover or selection state costs one rebuild rather than one per toggle.

#### Scale

One `Poly3D` is one `Model` and one draw call — sized for tens of areas, not
thousands. It is the rich end of the family, the way `Label3D` is next to
`LabelBatch3D`; there is no batched sibling yet.


### Lines

Canvas3D provides several components for drawing lines in 3D space:

- **LineBatch3D**: Instanced renderer for very large sets of independently
  styled polylines in a single draw call. Supports pixel- or world-width
  ribbons with round caps, a per-line `styleId` selecting a row of the `styles`
  table (dash pattern in world units, cap shape, opacity), and cheap per-frame
  updates via `updateLinePoints` / `updateEndpointsBulk`.
- **Line3D**: Simple wrapper for drawing a single line (batched backend)
- **MultiLine3D**: Draws multiple line paths with one color/width (batched backend)
- **BoxLine3D**: Creates a line using connected box segments for thicker, more visible lines

#### Dynamic Connectors

- **ConnectorLayer3D**: Owns one `LineBatch3D` and draws all of its connectors
  as a single instanced draw call, patching only the endpoints that moved each
  frame.
- **Connector3D**: A declarative link between two scene nodes (`from`/`to`);
  it follows their scene positions and registers into a `ConnectorLayer3D`
  (either declared inside one, or via an explicit `layer` reference for
  `Repeater3D` delegates). N connectors cost one draw call.

#### Styled bulk lines with LineBatch3D

Give each line its own colour, width and dash style, all in one instanced draw
call. The `styles` table holds dash/cap/opacity rows; a line's `styleId` selects
one:

```qml
LineBatch3D {
    viewportSize: Qt.vector2d(view.width, view.height)
    widthUnits: LineBatch3D.Pixel   // or LineBatch3D.World
    styles: [
        { dash: [0, 0],  capRound: true,  opacity: 1.0 },  // 0: solid
        { dash: [12, 8], capRound: false, opacity: 1.0 }   // 1: dashed
    ]
    lines: [
        { points: [Qt.vector3d(0,0,0), Qt.vector3d(100,0,0)], color: "#00d9ff", width: 2, styleId: 0 },
        { points: [Qt.vector3d(0,0,0), Qt.vector3d(0,0,100)], color: "#ff3366", width: 2, styleId: 1 }
    ]
}
```

For very large sets, skip the per-object `lines` list and push packed binary
buffers via `setBulk(positions, startIndices, colors, widths, styleIds)` — the
optional fifth `styleIds` (uint16 per line) is backward-compatible; omit it and
every line renders solid. Move lines cheaply per frame with
`updateLinePoints(lineIndex, points)` or `updateEndpointsBulk(positions)` — both
patch the instance table in place instead of rebuilding geometry.

```qml
// N moving links as a single instanced batch, endpoints patched each frame.
ConnectorLayer3D {
    id: links
    viewportSize: Qt.vector2d(view.width, view.height)
    widthUnits: LineBatch3D.Pixel
    color: "#00d9ff"; width: 1.5
}
Repeater3D {
    model: satellites
    delegate: Node {
        required property int index
        Connector3D { layer: links; from: this; to: hubs[index % hubs.length] }
    }
}
```

### Labels

Three components put readable text into a 3D scene the way technical
illustrations and maps do. All render unlit (never toon-shaded, never
shadow-casting) and stay crisp under the camera. Pick by role:

- **Label3D** - a camera-facing callout pill anchored to a thing. Reach for it to
  annotate individual entities or points - dozens - with rich, always-readable
  UI-style tags, optionally with a leader line.
- **PathLabel3D** - text laid flat along a line, the street-name look. Reach for
  it to paint a name onto a road or route from a `LineBatch3D`, read from above.
- **LabelBatch3D** - thousands of instanced SDF text labels. Reach for it when you
  need many cheap, uniform world-anchored labels (map features, data points,
  particle tags) in a couple of draw calls.

They compose: `Label3D` is the rich end (one QObject per label), `LabelBatch3D`
is the mass-scale end (one GPU instance per glyph), and `PathLabel3D` sits on top
of `LineBatch3D` for the flat-on-ground case.

#### Label3D - anchored callouts

A rounded "pill" with optional icon, anchored to a moving `anchorNode` or a fixed
`anchorPosition`. It billboards to the camera every frame and, by default, holds a
constant on-screen size (`sizeMode: Label3D.Screen`); switch to `Label3D.World` to
scale with the scene. An optional `showLeader` draws a thin line from the pill to
the anchor - the offset-callout look. A single shared per-view ticker (via
`Label3DRegistry`) drives all labels in one pass and skips the work entirely while
the camera and anchors are still, so many labels stay cheap and hidden ones are
dormant.

```qml
Label3D {
    view: view
    anchorNode: reactor
    text: "REACTOR CORE"
    labelOffset: Qt.vector3d(0, 40, 0)
    showLeader: true
}
```

#### PathLabel3D - names along a line

Street-name style text laid flat on the ground along a line of a `LineBatch3D`,
the way a map paints a road name. Placement rides the line via `pathLength()` /
`positionAt()`: the label centers on `at` (or the path middle), one flip-to-read
decision per placement keeps text from ever appearing upside-down, and
`repeatEvery` stamps the name at a fixed spacing along a long road.

It offers two carriers, chosen with `glyphPlacement`:

- **Word mode (default, `glyphPlacement: false`)**: each word rides its own
  2x-oversampled texture quad tangent to the path. Cheap; bends happen at word
  boundaries. Crisp down to roughly the oversample factor.
- **Glyph mode (`glyphPlacement: true`)**: the text is shaped once and each glyph
  is placed and rotated individually along the curve (maplibre's model), so the
  baseline hugs tight bends smoothly and the whole name - not just each word -
  reads correctly on a doubling-back leg. Rendering routes through an internal
  `LabelBatch3D` created **lazily on first use**, so word-mode labels pay for no
  SDF atlas (pay-per-use). Being SDF-baked, glyph mode stays crisp at any zoom. A
  curvature guard skips a placement whose baseline would wrap too sharp an arc
  (`skippedPlacements` reports how many); a background pill is not supported in
  glyph mode v1. As a ground decal the glyphs write depth with a small
  toward-camera bias so they draw above the line they sit on from any camera -
  the layering contract is lines first, labels above.

```qml
LineBatch3D { id: roads /* ... */ }

PathLabel3D {
    lines: roads
    lineId: 0
    text: "CLAY STREET"
    worldHeight: 30
    repeatEvery: 900
    glyphPlacement: true   // per-glyph text-on-curve; omit for cheap word mode
}
```

#### LabelBatch3D - mass-scale SDF labels

Draws very large sets of short labels - tens of thousands - as instanced
signed-distance-field glyphs over a shared atlas (deck.gl's TextLayer model): N
labels cost one draw call for the glyphs plus one for the optional pills. Each
label is a world-anchored point with its own text, color and size; glyphs stay
crisp at any zoom. `sizeMode` picks screen-constant (billboard) or world units,
`orientation` picks billboard or flat-on-ground, and moving labels can be repositioned
without re-shaping via `updatePositionsBulk`. It is the mass-scale sibling of
`Label3D`, not a replacement - rich per-label content, icons and leaders stay
`Label3D`'s job.

```qml
LabelBatch3D {
    viewportSize: Qt.vector2d(view.width, view.height)
    sizeMode: LabelBatch3D.Screen
    halo: true
    labels: [
        { position: Qt.vector3d(0, 0, 0),  text: "ALPHA", color: "#00d9ff", size: 22 },
        { position: Qt.vector3d(80, 0, 0), text: "BETA",  color: "#ff3366", size: 22 }
    ]
}
```

### Voxel Maps

Voxel maps create 3D structures composed of cubic voxels. Both backends share a
compact **palette-index store** (8-bit per voxel, auto-upgraded to 16-bit past
255 distinct colours) with an incrementally-maintained (**O(1)**) solid count —
no per-change recount.

- **StaticVoxelMap**: greedy-meshed triangle geometry, chunked and remeshed
  **off the main thread**. A single `set()` dirties only its ~32³ chunk, which is
  remeshed on a worker; the call returns immediately. Best for large maps, and —
  since the remesh no longer blocks — now perfectly usable under frequent edits.
- **DynamicVoxelMap**: GPU-instanced cubes; each `set()` marks the instance table
  dirty and the rebuild lands at render time. Best for maps that churn (full
  clear+refill) or need per-voxel instance semantics.

### Dynamic Instancing

`DynamicInstances3D` renders many copies of one base mesh (cars, crowds,
projectiles) through a single GPU instance table whose per-entry transforms are
updated **every frame from a packed binary buffer** — no per-instance QObject and
no CPU table rebuild on the hot path. It is the C++-backed alternative to a
declarative `InstanceList` of `InstanceListEntry` objects, which pays a property
write per entry per changed field and a full table rebuild.

- Set per-entry statics once with `setBulk(scales, colors, customData)` — one
  `vector3d` scale and one `color` per entry.
- Push movement each frame with `updatePoses(first, poses)`, where `poses` is a
  reused `Float32Array` of `[x, y, z, yawRad]` per entry (pass `.buffer`). The
  transform is `translate(x,y,z) * rotateY(yaw) * scale`, so the base mesh's
  local **+Z** axis points along `yaw` — matching an `InstanceListEntry` with
  `eulerRotation (0, yawDeg, 0)`, so migrations keep their orientation.
- `setEntryColor(i, c)` recolors a single entry; `setExtents(min, max)` declares
  the roaming volume so the table skips the per-upload bounds rescan.
- Read-only `count`, `bytesLastUpload`, `packMsLast`, `uploadsPerSecond` feed a
  HUD.

```qml
Model {
    source: "#Cube"
    instancing: DynamicInstances3D {
        id: fleet
        Component.onCompleted: {
            var scales = [], colors = []
            for (var i = 0; i < 500; ++i) { scales.push(Qt.vector3d(0.02, 0.01, 0.03)); colors.push("#00d9ff") }
            setBulk(scales, colors)
            setExtents(Qt.vector3d(-200, 0, -200), Qt.vector3d(200, 10, 200))
        }
    }
    materials: PrincipledMaterial { lighting: PrincipledMaterial.NoLighting }
}

// per frame, from a reused Float32Array poseBuf (4 floats per entry):
fleet.updatePoses(0, poseBuf.buffer)
```

The neoncity demo drives its whole car fleet (body + cabin + window + 4 wheels =
four tables) this way.

## Toon Shading

Canvas3D implements cartoon-style rendering using a half-lambert lighting
model, providing flat, stylized lighting with distinct shadow boundaries.

### Optimal Lighting Setup

Toon shading requires specific shadow settings for the characteristic cartoon look:

```qml
DirectionalLight {
    eulerRotation.x: -35  // Optimal lighting angle
    castsShadow: true
    shadowFactor: 78                        // Strong shadows
    shadowMapQuality: Light.ShadowMapQualityVeryHigh  // Crisp edges
    pcfFactor: 2                           // Minimal softening
    shadowBias: 18                         // Artifact prevention
}
```

### Usage

Enable toon shading on any Canvas3D component:

```qml
Box3D {
    useToonShading: true
    edgeColorFactor: 2.0  // Increase edge contrast for cartoon look
}

StaticVoxelMap {
    useToonShading: true  // Creates Minecraft-like blocky aesthetics
}
```

## Coordinate System

Canvas3D uses Qt Quick 3D's coordinate system:
- **X-axis**: Points right
- **Y-axis**: Points up
- **Z-axis**: Points toward the viewer

### Voxel Coordinates

The relationship between voxel coordinates and world positions:
```
worldPosition = voxelCoordinate * (voxelSize + spacing) + voxelOffset
```

Example dimensions calculation:
```qml
StaticVoxelMap {
    voxelCountX: 10
    voxelCountY: 5
    voxelCountZ: 10
    voxelSize: 2.0
    spacing: 0.5

    // width = 10 * (2.0 + 0.5) - 0.5 = 24.5
    // height = 5 * (2.0 + 0.5) - 0.5 = 12.0
    // depth = 10 * (2.0 + 0.5) - 0.5 = 24.5
}
```

## Edge Rendering

`Box3D`, `VoxelMap` and `Poly3D` all draw their edges by the same rule, so a
scene made of all three reads as one thing.

### Thickness is a count of pixels

`edgeThickness` is measured on screen, not in world units, so a line keeps its
weight as the camera pulls back, as the window resizes and as a surface turns
away. A line straddles the boundary it marks and each surface draws half of
it, which is why a box border, a voxel map's border and an extruded polygon's
border all come out the same width at the same setting. A voxel map's interior
grid lines sit inside one face and are shared with nothing, so they draw both
halves and are correctly twice that width.

Below about 1 px lines start dropping out of the pixel grid, so `1.0` is the
practical floor rather than a soft limit.

### Edge colour

`edgeColor` names the colour outright:

```qml
Box3D {
    color: "#e6d2f2"
    showEdges: true
    edgeColor: "#2f3437"    // dark edges on a light face
}
```

Without it, `edgeColorFactor` scales the fill instead — which can only ever
darken, so a light surface gets washed-out edges and "dark grey on pale
lilac" is inexpressible. `edgeColor` wins whenever its alpha is above zero;
leave it unset to keep the `edgeColorFactor` behaviour.

### Face borders or triangulation

`Box3D` and `Poly3D` both take `edgeMode`. `FaceBorders` draws the object's
own borders — a box's twelve edges, a polygon's rings. `Triangles` draws the
mesh's triangulation instead, for when how a shape is built is the point.
`edgeMask`, which selects individual box borders, applies to `FaceBorders`
only; a triangulation missing some of its lines is not a triangulation.

### Edge Artifacts with Greedy Meshing

When using StaticVoxelMap with `fill()` operations (spheres, cylinders),
disable edges to avoid visual artifacts:

```qml
StaticVoxelMap {
    voxelCountX: 50
    voxelCountY: 50
    voxelCountZ: 50
    showEdges: false  // Prevents grid artifacts with meshed geometry

    Component.onCompleted: {
        fill({ shape: "sphere", pos: [25,25,25], radius: 10, colors: ["red"] })
    }
}
```

## Performance Considerations

### Choosing Voxel Map Types

- **StaticVoxelMap**: large maps and edit-heavy scenes alike — chunked
  off-thread greedy meshing means a single voxel edit only remeshes its chunk on
  a worker thread (per-edit cost is effectively free on the main thread). It even
  outperforms `DynamicVoxelMap` for a single-edit-per-frame storm.
- **DynamicVoxelMap**: full clear+refill churn, or when you need per-voxel
  instanced cubes rather than meshed geometry.

### Edit costs

- A single `set()` on `StaticVoxelMap` dirties ~one chunk; the greedy remesh runs
  on a `QtConcurrent` worker, so it does not stall the frame.
- `model.commit()` after a batch (e.g. `fillBox`/`fillSphere`) dispatches the
  full build to the worker too — it schedules rather than blocks.
- Still prefer the **batch** path (`fillBox` + one `commit()`) over thousands of
  individual `set()` calls when generating terrain: it is a single build instead
  of one per dirtied chunk.

### Optimization Tips

- **Batch Operations**: Call `model.commit()` once after multiple voxel changes
- **Edge Control**: Disable `showEdges` for large voxel maps
- **Shadow Quality**: Balance shadow settings with performance needs

## Instrumentation & Benchmarks

Three helper types measure real cost from QML:

- **PerfHud**: a compact always-on-top overlay for a `View3D` (`view3D:` +
  optional `extended: true`) showing fps and frame time — drop it into any scene
  while tuning. It automatically appends any `PerfRegistry` section averages and
  counter rates beneath the render stats.
- **PerfRegistry**: an app-wide singleton for timing named code sections and
  counting events, independent of the renderer. Wrap a block with
  `PerfRegistry.begin("name")` / `PerfRegistry.end("name")` for a rolling-average
  section time, or call `PerfRegistry.tick("name")` for a per-second rate;
  `snapshot()` returns the current readings. Cheap when unused. The neoncity car
  sim instruments `"carSim"` (control logic) and `"carPack"` (pose packing +
  upload) so the HUD shows the split.
- **BenchLogger**: samples a `View3D`'s `renderStats` at a fixed `intervalMs` and
  writes a CSV to `outputPath`; `extra` adds custom columns and `annotate(key,
  value)` tags the next sample (e.g. step boundaries).

```qml
PerfHud   { view3D: view; anchors.right: parent.right }
BenchLogger {
    view3D: view
    outputPath: "file:///tmp/mybench.csv"
    intervalMs: 250
    running: true
}
```

The `benchmarks/` directory holds stepped, auto-running scenarios
(`Sandbox.qml` loads them) covering static/dynamic lines, moving connectors,
animated instances (`InstanceList` vs `DynamicInstances3D`), and voxel
edit-storm/churn. Recorded results, the baseline, and the optimized-vs-baseline
comparison live in `benchmarks/results/` — see `results/COMPARISON-2026-07-18.md`
for the line/voxel headline numbers and `results/instances-2026-07-19.md` for the
instancing comparison.

## Examples

### Toon-Shaded Voxel Terrain

```qml
import QtQuick
import QtQuick3D
import Clayground.Canvas3D

View3D {
    environment: SceneEnvironment {
        clearColor: "#87CEEB"  // Sky blue
        backgroundMode: SceneEnvironment.Color
    }

    PerspectiveCamera {
        position: Qt.vector3d(200, 300, 400)
        eulerRotation.x: -30
    }

    DirectionalLight {
        eulerRotation.x: -35
        eulerRotation.y: -70
        castsShadow: true
        shadowFactor: 78
        shadowMapQuality: Light.ShadowMapQualityVeryHigh
        pcfFactor: 2
        shadowBias: 18
    }

    StaticVoxelMap {
        id: terrain
        voxelCountX: 80
        voxelCountY: 30
        voxelCountZ: 80
        voxelSize: 5
        useToonShading: true
        showEdges: false  // Avoid artifacts with terrain

        Component.onCompleted: {
            // Create layered terrain
            for (let x = 0; x < voxelCountX; x++) {
                for (let z = 0; z < voxelCountZ; z++) {
                    let h = Math.sin(x * 0.1) * Math.cos(z * 0.1) * 8 + 15

                    for (let y = 0; y < h; y++) {
                        let color = y < 5 ? "#8B4513" :   // Dirt
                                   y < 12 ? "#228B22" :   // Grass
                                           "#708090"       // Stone
                        set(x, y, z, color)
                    }
                }
            }
            model.commit()
        }
    }
}
```

### Mixed Rendering Styles

```qml
Row {
    spacing: 200

    // Standard PBR rendering
    Box3D {
        width: 100; height: 100; depth: 100
        color: "#e74c3c"
        useToonShading: false
    }

    // Cartoon rendering
    Box3D {
        width: 100; height: 100; depth: 100
        color: "#e74c3c"
        useToonShading: true
        edgeColorFactor: 2.0  // Enhanced edges for cartoon look
    }
}
```

## Best Practices

### Toon Shading
- Use strong directional lighting with high shadow factor (70-80)
- Enable crisp shadow maps (VeryHigh quality, low PCF factor)
- Increase `edgeColorFactor` for enhanced cartoon aesthetics
- Consider scene ambient lighting balance

### Performance
- Choose appropriate voxel map type based on update frequency
- Batch voxel operations when possible
- Use edge rendering selectively on large scenes
- Profile shadow quality vs. performance trade-offs

### Visual Design
- Consistent lighting setup across toon-shaded objects
- Use the demos (`Box3DDemo.qml`, `VoxelDemo.qml`) as implementation references
- Test both rendering modes during development

### Code Organization
- Study shader implementations in `.frag` files for custom lighting
- Refer to geometry classes for edge rendering algorithms
- Use the demo control panels as UI pattern examples

## Implementation References

For developers wanting to understand or extend the system:

- **Toon Shading**: `box3d.frag`, `voxel_map.frag` - complete shader implementations
- **Edge Rendering**: `shouldShowEdge()` function, grid line calculations
- **Greedy Meshing**: `VoxelMapGeometry::generateGreedyMesh()`
- **Demo Implementation**: `Box3DDemo.qml`, `VoxelDemo.qml` - complete working examples
