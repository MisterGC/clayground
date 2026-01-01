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

Canvas3D provides three components for drawing lines in 3D space:

- **Line3D**: Simple wrapper for drawing a single line
- **MultiLine3D**: Efficient component for drawing multiple lines in a single draw call
- **BoxLine3D**: Creates a line using connected box segments for thicker, more visible lines

### Voxel Maps

Voxel maps create 3D structures composed of cubic voxels with support for both
dynamic updates and static optimization.

- **DynamicVoxelMap**: Best for voxel maps that change frequently
- **StaticVoxelMap**: Optimized for large, static voxel structures using greedy meshing

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

- **DynamicVoxelMap**: Frequent updates, smaller maps (< 50^3 voxels)
- **StaticVoxelMap**: Static content, large maps, performance-critical applications

### Optimization Tips

- **Batch Operations**: Call `model.commit()` once after multiple voxel changes
- **Edge Control**: Disable `showEdges` for large voxel maps
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
