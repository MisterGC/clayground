# Canvas3D User Guide

## Overview

The Canvas3D plugin provides a comprehensive set of components for creating 3D
visualizations in Clayground applications. It offers primitives for 3D boxes,
lines, and voxel-based structures with support for custom edge rendering, toon
shading, and efficient batch rendering.

## Table of Contents

1. [Getting Started](#getting-started)
2. [Core Components](#core-components)
   - [Box3D](#box3d)
   - [Lines](#lines)
   - [Voxel Maps](#voxel-maps)
3. [Toon Shading](#toon-shading)
4. [Coordinate System](#coordinate-system)
5. [Edge Rendering](#edge-rendering)
6. [Performance Considerations](#performance-considerations)
7. [Examples](#examples)
8. [Best Practices](#best-practices)

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

The `Box3D` component creates a 3D box with customizable dimensions, edge rendering, and cartoon-style shading.

#### Properties

| Property | Type | Default | Description |
|----------|------|---------|-------------|
| width | real | 1.0 | Width of the box |
| height | real | 1.0 | Height of the box |
| depth | real | 1.0 | Depth of the box |
| color | color | "red" | Main color of the box |
| showEdges | bool | true | Whether to render edge lines |
| edgeThickness | real | 8 | Thickness of edges in pixels |
| edgeColorFactor | real | 0.4 | Darkening factor for edges (0-1) |
| edgeMask | int | AllEdges | Bitmask controlling which edges are visible |
| useToonShading | bool | false | Enable cartoon-style lighting |
| scaledFace | int | None | Which face to scale (TopFace, BottomFace, etc.) |
| faceScale | vector2d | (1,1) | Scale factor for the selected face |

#### Edge Mask Constants

Use the exposed constants for precise edge control:
- `allEdges`, `topEdges`, `bottomEdges`
- `frontEdges`, `backEdges`, `leftEdges`, `rightEdges`

```qml
Box3D {
    edgeMask: topEdges | bottomEdges  // Only horizontal edges
}
```

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

### Lines

Canvas3D provides three components for drawing lines in 3D space:

#### Line3D
Simple wrapper for drawing a single line.

#### MultiLine3D
Efficient component for drawing multiple lines in a single draw call.

#### BoxLine3D
Creates a line using connected box segments for thicker, more visible lines.

### Voxel Maps

Voxel maps create 3D structures composed of cubic voxels with support for both dynamic updates and static optimization.

#### Common Properties

| Property | Type | Default | Description |
|----------|------|---------|-------------|
| voxelCountX/Y/Z | int | 0 | Voxel grid dimensions (number of voxels per axis) |
| width/height/depth | real | (readonly) | World dimensions, computed as: `voxelCount * (voxelSize + spacing) - spacing` |
| voxelSize | real | 1.0 | Size of each voxel in world units |
| spacing | real | 0.0 | Gap between voxels in world units |
| voxelOffset | vector3d | (0,0,0) | World offset for the entire map |
| showEdges | bool | true | Whether to render voxel grid lines |
| edgeThickness | real | 0.05 | Thickness of grid edges |
| edgeColorFactor | real | 1.0 | Darkening factor for edges |
| useToonShading | bool | false | Enable cartoon-style lighting |

**Note:** The `voxelCountX/Y/Z` properties define the discrete grid size (number of voxels), while
`width/height/depth` are read-only properties that give you the actual world dimensions accounting
for both `voxelSize` and `spacing`. This makes it easy to position other objects relative to the voxel map.

#### DynamicVoxelMap
Best for voxel maps that change frequently. Each voxel is rendered as a separate instance.

#### StaticVoxelMap
Optimized for large, static voxel structures. Uses greedy meshing to reduce vertex count by combining adjacent voxels of the same color.

**Implementation Detail**: See `VoxelMapGeometry::generateGreedyMesh()` for the meshing algorithm.

## Toon Shading

Canvas3D implements cartoon-style rendering using a half-lambert lighting
model, providing flat, stylized lighting with distinct shadow boundaries.

### Technical Implementation

The toon shading system uses custom fragment shader functions that override Qt's default lighting:

- **Half-Lambert Formula**: `(dot(normal, lightDir) + 1) * 0.5` ensures surfaces facing away from light still receive 50% illumination
- **Disabled Components**: Specular highlights and IBL are disabled for flat cartoon aesthetics
- **Material Properties**: Automatically sets METALNESS=0, ROUGHNESS=1 for matte surfaces
- **Dual Mode**: Toggleable between toon and standard PBR lighting

**Code Reference**: Study `box3d.frag` and `voxel_map.frag` for the complete shader implementation.

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

**Demo Reference**: See `Box3DDemo.qml` and `VoxelDemo.qml` for complete toon shading implementations with UI controls.

## Coordinate System

Canvas3D uses Qt Quick 3D's coordinate system:
- **X-axis**: Points right
- **Y-axis**: Points up
- **Z-axis**: Points toward the viewer

### Voxel Coordinates

Voxel coordinates (0,0,0) start at the origin. The relationship between voxel coordinates and world positions:
```
worldPosition = voxelCoordinate * (voxelSize + spacing) + voxelOffset
```

The read-only `width`, `height`, and `depth` properties give you the total world dimensions:
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

Two distinct edge rendering systems provide visual depth:

### Screen-Space Edges (Box3D)
Uses UV coordinates and `fwidth()` for pixel-accurate, distance-independent edge thickness. Supports selective edge rendering via bitmasks.

**Implementation**: See `shouldShowEdge()` function in `box3d.frag` for the complete bit masking system.

### World-Space Grid Edges (VoxelMap)
Draws grid lines at voxel boundaries using fractional position calculations. Adapts thickness based on camera distance.

**Implementation**: See grid line calculation in `voxel_map.frag`.

### Edge Artifacts with Greedy Meshing

When using StaticVoxelMap with `fill()` operations (spheres, cylinders), disable edges to avoid visual artifacts:

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

**Technical Note**: Greedy meshing combines adjacent voxels while the edge shader still draws grid lines at original voxel boundaries.

## Performance Considerations

### Choosing Voxel Map Types

**DynamicVoxelMap**: Frequent updates, smaller maps (< 50³ voxels)
**StaticVoxelMap**: Static content, large maps, performance-critical applications

### Optimization

- **Batch Operations**: Call `model.commit()` once after multiple voxel changes
- **Edge Control**: Disable `showEdges` for large voxel maps
- **Toon Shading**: No performance penalty when disabled
- **Shadow Quality**: Balance shadow settings with performance needs

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
- **Lighting Setup**: DirectionalLight configurations in demo files
