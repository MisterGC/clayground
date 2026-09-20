# Clay Canvas Plugin

The Clay Canvas plugin provides a 2D canvas system with world coordinate
mapping, camera controls, and visual elements positioned in world units. It
offers a complete solution for creating 2D game worlds with proper coordinate
transformations and viewport management.

## Getting Started

To use the Clay Canvas plugin in your QML files:

```qml
import Clayground.Canvas
```

## Core Components

- **ClayCanvas** - Main canvas managing viewport, coordinate system, and camera with Y-up orientation
- **Rectangle** - Rectangle positioned and sized in world units
- **Text** - Text element with world unit positioning and scalable font
- **Image** - Image positioned and sized in world units
- **Poly** - Polygon or polyline shape from vertex arrays in world units
- **Connector** - Visual line connecting two items with automatic position tracking
- **Axes** - An x and a y axis out of one origin, with labels and an optional series

## Usage Examples

### Basic Canvas Setup

```qml
import QtQuick
import Clayground.Canvas as Canv

Canv.ClayCanvas {
    id: canvas
    anchors.fill: parent

    // Define world boundaries
    worldXMin: -10
    worldXMax: 10
    worldYMin: -10
    worldYMax: 10

    // Set scale
    pixelPerUnit: 50

    // Enable debug info (press Space to toggle)
    showDebugInfo: true
}
```

### Creating World Objects

```qml
Canv.Rectangle {
    canvas: canvas
    xWu: 0      // Center of world
    yWu: 0
    widthWu: 2
    heightWu: 1
    color: "red"
}

Canv.Text {
    canvas: canvas
    xWu: 0
    yWu: 2
    fontSizeWu: 0.5
    text: "Hello World!"
    color: "blue"
}

Canv.Image {
    canvas: canvas
    xWu: -5
    yWu: 5
    widthWu: 3
    heightWu: 3
    source: "player.png"
}
```

### Drawing Shapes

```qml
// Draw a triangle
Canv.Poly {
    canvas: canvas
    vertices: [
        {x: 0, y: 0},
        {x: 2, y: 0},
        {x: 1, y: 2}
    ]
    fillColor: "green"
    strokeColor: "darkgreen"
    strokeWidth: 2
}

// Draw a path
Canv.Poly {
    canvas: canvas
    vertices: [
        {x: -5, y: -5},
        {x: -3, y: -3},
        {x: -1, y: -3},
        {x: 1, y: -5}
    ]
    strokeColor: "purple"
    strokeStyle: ShapePath.DashLine
}
```

### Camera Following

```qml
Canv.ClayCanvas {
    id: canvas

    Canv.Rectangle {
        id: player
        canvas: canvas
        xWu: 0
        yWu: 0
        widthWu: 1
        heightWu: 1
        color: "orange"

        // Animate position
        NumberAnimation on xWu {
            from: -5; to: 5
            duration: 5000
            loops: Animation.Infinite
        }
    }

    // Camera follows the player
    observedItem: player
}
```

### Visual Connections

```qml
Canv.Rectangle {
    id: nodeA
    canvas: canvas
    xWu: -2; yWu: 0
    widthWu: 1; heightWu: 1
    color: "blue"
}

Canv.Rectangle {
    id: nodeB
    canvas: canvas
    xWu: 2; yWu: 0
    widthWu: 1; heightWu: 1
    color: "red"
}

Canv.Connector {
    from: nodeA
    to: nodeB
    color: "green"
    strokeWidth: 3
    style: ShapePath.DashLine
}
```

### Sketching a board

A board is a 2D world with a camera, so its pieces are ordinary canvas items in
world units. `sketch` picks the pen - "chalk" or "marker" instead of the default
"none" - and `seed` picks which wobble, so the same points with the same seed
give the same line every time. `progress` says how much of a stroke is drawn,
`arrow` puts heads on a connector, a `Text` with `sketch` set is written by hand,
and `Axes` draws two labeled axes with a series on them.

```qml
// A chalk stroke, drawn to 60% of its length
Canv.Poly {
    canvas: canvas
    vertices: [{x: 0, y: 0}, {x: 2, y: 1.4}, {x: 4, y: 0}]
    strokeColor: "#f1efe6"
    strokeWidth: 3
    sketch: "chalk"
    progress: 0.6
}
```

```qml
// An arrow between two world points - no items needed, but a canvas is
Canv.Connector {
    canvas: canvas
    from: {x: 0, y: 0}
    to: {x: 4, y: 2}
    arrow: "to"        // "none", "to", "from" or "both"
    attach: "edge"     // "center" or "edge", for ends that are items
    sketch: "marker"
    color: "#00d9ff"
}
```

```qml
// Two axes out of one origin, with a series drawn on them
Canv.Axes {
    canvas: canvas
    xWu: 1; yWu: 1            // the origin
    widthWu: 5; heightWu: 3   // axis lengths
    xLabel: "Ib"; yLabel: "Ic"
    series: [{x: 1.4, y: 1.2}, {x: 3.0, y: 2.0}, {x: 5.5, y: 3.4}]
    sketch: "chalk"
    strokeColor: "#f1efe6"
}
```

`Text.sketch` switches the font family to the hand font the plugin ships
(Caveat, OFL), so hand text needs no font installed on the machine.

`ClayCanvas.fit(xMin, yMin, xMax, yMax, marginWu)` frames a world rectangle: it
sets the scale so the rectangle plus its margin fills the view, centers the
viewport on it and stops following `observedItem`.

## Best Practices

1. **World Units**: Always use world units (Wu) for positioning and sizing to ensure consistent scaling.

2. **Canvas Reference**: Always set the `canvas` property for visual elements to ensure proper coordinate transformation.

3. **Performance**: For many objects, consider using a single Poly with multiple disconnected segments rather than many individual items.

4. **Camera Control**: Use `observedItem` for automatic camera following, or manually control viewport position.

5. **Debug Mode**: Use `showDebugInfo` during development to understand coordinate mappings.

## Technical Implementation

The Clay Canvas plugin implements:

- **Coordinate System**: Cartesian coordinates with Y-up orientation
- **Viewport Management**: Flickable-based viewport with bounds checking
- **Automatic Scaling**: Device scaling and zoom factor support
- **Debug Overlay**: Grid display and coordinate information
- **Keyboard Navigation**: Optional IJKL navigation with E/D zoom controls

The canvas uses Qt Quick's scene graph for efficient rendering and supports dynamic creation of visual elements at runtime.
