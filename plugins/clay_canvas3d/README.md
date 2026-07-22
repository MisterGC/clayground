# Canvas3D User Guide

## Overview

The Canvas3D plugin provides components for creating 3D visualizations in
Clayground applications. It offers primitives for 3D boxes, lines, and
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

Two components put readable text into a 3D scene the way technical illustrations
and maps do. Both render unlit (never toon-shaded, never shadow-casting) and stay
crisp under the camera.

- **Label3D**: a camera-facing callout - a rounded "pill" with optional icon -
  anchored to a moving `anchorNode` or a fixed `anchorPosition`. It billboards to
  the camera every frame and, by default, holds a constant on-screen size
  (`sizeMode: Label3D.Screen`); switch to `Label3D.World` to scale with the scene.
  An optional `showLeader` draws a thin line from the pill to the anchor - the
  offset-callout look. A single shared per-view ticker (via `Label3DRegistry`)
  drives all labels in one pass and skips the work entirely while the camera and
  anchors are still, so many labels stay cheap and hidden ones are dormant.

```qml
Label3D {
    view: view
    anchorNode: reactor
    text: "REACTOR CORE"
    labelOffset: Qt.vector3d(0, 40, 0)
    showLeader: true
}
```

- **PathLabel3D**: street-name style text laid flat on the ground along a line of
  a `LineBatch3D`, the way a map paints a road name. It splits the text into words
  placed tangent to the path, makes one flip-to-read decision per placement so
  text never appears upside-down, and `repeatEvery` stamps the name at a fixed
  spacing along a long road. The words ride 2x-oversampled textures that stay
  crisp under the top-down/tactical cameras these labels are made for.

```qml
LineBatch3D { id: roads /* ... */ }

PathLabel3D {
    lines: roads
    lineId: 0
    text: "CLAY STREET"
    worldHeight: 30
    repeatEvery: 900
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
