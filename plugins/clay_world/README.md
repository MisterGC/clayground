# Clay World Plugin

The Clay World plugin provides comprehensive game world management for both 2D
and 3D games. It integrates canvas rendering, physics simulation, and SVG-based
level loading into cohesive world components. The plugin offers separate
implementations for 2D and 3D worlds while sharing common functionality like
scene loading and entity management.

## Table of Contents

- [Getting Started](#getting-started)
- [Core Components](#core-components)
  - [ClayWorld2d](#clayworld2d)
  - [ClayWorld3d](#clayworld3d)
  - [SceneLoader2d/3d](#sceneloader2d3d)
  - [Minimap2d](#minimap2d)
  - [Box3DBody](#box3dbody)
- [Usage Examples](#usage-examples)
- [Best Practices](#best-practices)
- [Technical Implementation](#technical-implementation)

## Getting Started

To use the Clay World plugin in your QML files:

```qml
import Clayground.World
```

## Core Components

### ClayWorld2d

Complete 2D game world with physics, rendering, and scene loading.

#### Properties

| Property | Type | Description |
|----------|------|-------------|
| `canvas` | ClayCanvas | The rendering canvas (readonly) |
| `room` | Item | Container for world entities |
| `physics` | World | Box2D physics world |
| `scene` | string | SVG file path for level data |
| `components` | Map | Component mapping for scene loading |
| `loadMapAsync` | bool | Load entities asynchronously |
| `observedItem` | var | Item for camera to follow |

#### World Dimensions

| Property | Type | Description |
|----------|------|-------------|
| `xWuMin/xWuMax` | real | World X boundaries |
| `yWuMin/yWuMax` | real | World Y boundaries |
| `pixelPerUnit` | real | Pixel to world unit ratio |

#### Physics Properties

| Property | Type | Description |
|----------|------|-------------|
| `gravity` | point | Gravity vector |
| `timeStep` | real | Physics simulation timestep |
| `physicsEnabled` | bool | Enable physics simulation |

#### Signals

| Signal | Parameters | Description |
|--------|-----------|-------------|
| `mapAboutToBeLoaded()` | none | Before loading starts |
| `mapLoaded()` | none | Loading complete |
| `mapEntityCreated(obj, groupId, compName)` | Various | Entity created |
| `groupAboutToBeLoaded(id, description)` | id: string, description: string | Group loading |

### ClayWorld3d

Complete 3D game world with physics and scene management.

#### Properties

| Property | Type | Description |
|----------|------|-------------|
| `root` | Node | Root 3D scene node |
| `physics` | PhysicsWorld | 3D physics world |
| `camera` | Camera | Main camera |
| `observedObject` | Node | Object for camera to follow |
| `freeCamera` | bool | Enable WASD camera controls |
| `floor` | StaticRigidBody | Ground plane |

#### World Dimensions

| Property | Type | Description |
|----------|------|-------------|
| `xWuMax` | real | World X size |
| `zWuMax` | real | World Z size |

### SceneLoader2d/3d

Loads entities from SVG files into the world.

#### Properties

| Property | Type | Description |
|----------|------|-------------|
| `sceneSource` | string | SVG file path |
| `loadEntitiesAsync` | bool | Asynchronous loading |
| `components` | Map | Component mapping |
| `baseZCoord` | real | Base Z coordinate (2D only) |

### Minimap2d

Miniature map view of the 2D world.

#### Properties

| Property | Type | Description |
|----------|------|-------------|
| `world` | ClayWorld2d | World to display (required) |
| `typeMapping` | Map | Type to component mapping |

### Box3DBody

3D physics-enabled box shape.

#### Properties

| Property | Type | Description |
|----------|------|-------------|
| `width/height/depth` | real | Box dimensions |
| `color` | color | Box color |
| `scaledFace` | enum | Face to scale |
| `faceScale` | real | Face scale factor |

## Usage Examples

### Basic 2D World

```qml
import QtQuick
import Clayground.World
import Clayground.Physics

ClayWorld2d {
    id: gameWorld
    anchors.fill: parent
    
    // World setup
    xWuMin: 0
    xWuMax: 100
    yWuMin: 0
    yWuMax: 50
    
    // Physics
    gravity: Qt.point(0, 10)
    
    // Camera follows player
    observedItem: player
    
    RectBoxBody {
        id: player
        xWu: 10
        yWu: 10
        widthWu: 2
        heightWu: 2
        color: "blue"
        bodyType: Body.Dynamic
    }
}
```

### Level Loading from SVG

```qml
ClayWorld2d {
    id: world
    scene: "levels/level1.svg"
    loadMapAsync: true
    
    // Register components for SVG loading
    components: new Map([
        ["Wall", wallComponent],
        ["Enemy", enemyComponent],
        ["Collectible", coinComponent]
    ])
    
    Component {
        id: wallComponent
        RectBoxBody {
            color: "#333333"
            bodyType: Body.Static
        }
    }
    
    Component {
        id: enemyComponent
        RectBoxBody {
            color: "red"
            bodyType: Body.Dynamic
            Component.onCompleted: {
                // Initialize enemy behavior
            }
        }
    }
    
    onMapLoaded: {
        console.log("Level loaded!")
    }
}
```

### 3D World Setup

```qml
ClayWorld3d {
    id: world3d
    anchors.fill: parent
    
    // World size
    xWuMax: 200
    zWuMax: 200
    
    // Camera setup
    observedObject: player3d
    
    Box3DBody {
        id: player3d
        position: Qt.vector3d(50, 10, 50)
        width: 20
        height: 20
        depth: 20
        color: "orange"
    }
    
    // Load 3D scene
    scene: "levels/3d_level.svg"
    components: new Map([
        ["Platform", platform3dComponent]
    ])
}
```

### Minimap Implementation

```qml
ClayWorld2d {
    id: mainWorld
    // ... world setup
}

Minimap2d {
    world: mainWorld
    width: 200
    height: 150
    
    anchors.right: parent.right
    anchors.top: parent.top
    anchors.margins: 20
    
    // Map entity types to minimap representations
    typeMapping: new Map([
        ["Player", playerDotComponent],
        ["Enemy", enemyDotComponent],
        ["Wall", wallRectComponent]
    ])
    
    Component {
        id: playerDotComponent
        Rectangle {
            color: "green"
            radius: width * 0.5
        }
    }
    
    Component {
        id: enemyDotComponent
        Rectangle { color: "red" }
    }
}
```

### Dynamic Entity Creation

```qml
ClayWorld2d {
    id: world
    
    function spawnEnemy(x, y) {
        let enemy = enemyComponent.createObject(room, {
            xWu: x,
            yWu: y
        })
        return enemy
    }
    
    Component {
        id: enemyComponent
        RectBoxBody {
            widthWu: 2
            heightWu: 2
            color: "red"
            bodyType: Body.Dynamic
        }
    }
    
    Timer {
        interval: 5000
        repeat: true
        running: true
        onTriggered: {
            world.spawnEnemy(
                Math.random() * world.xWuMax,
                Math.random() * world.yWuMax
            )
        }
    }
}
```

### Custom Scene Loading

```qml
ClayWorld2d {
    id: world
    
    onPolylineLoaded: (id, groupId, points, fillColor, strokeColor, description) => {
        // Handle patrol paths
        if (description.includes("patrol_path")) {
            createPatrolPath(id, points)
        }
    }
    
    onGroupAboutToBeLoaded: (id, description) => {
        console.log("Loading group:", id)
    }
    
    onMapEntityCreated: (obj, groupId, compName) => {
        // Post-process loaded entities
        if (compName === "Enemy") {
            obj.target = player
        }
    }
}
```

### Physics Configuration

```qml
ClayWorld2d {
    // Platformer physics
    gravity: Qt.point(0, 20)
    timeStep: 1/60
    
    // Top-down physics
    // gravity: Qt.point(0, 0)
    
    // Debug rendering
    debugPhysics: true
    debugRendering: true
    
    // Pause physics
    MouseArea {
        anchors.fill: parent
        onClicked: parent.physicsEnabled = !parent.physicsEnabled
    }
}
```

## Best Practices

1. **Scene Organization**: Use SVG groups to organize level elements logically.

2. **Component Registration**: Register all components before loading scenes.

3. **Async Loading**: Use `loadMapAsync: true` for large levels to prevent UI freezing.

4. **World Units**: Always work in world units for consistency across different screen sizes.

5. **Entity Management**: Use the `room` container for proper entity lifecycle management.

6. **Performance**: Limit physics bodies and use static bodies where possible.

## Technical Implementation

The Clay World plugin provides:

- **Unified World Management**: Common base for 2D and 3D worlds
- **SVG Scene Loading**: Parse SVG files with JSON metadata for game entities
- **Physics Integration**: Seamless Box2D (2D) and Qt Quick 3D Physics integration
- **Camera Systems**: Automatic following for 2D, orbit/WASD controls for 3D
- **Async Loading**: Non-blocking entity creation for smooth gameplay
- **Component Factory**: Map SVG descriptions to QML components

The plugin handles coordinate transformations, physics body creation, and proper parent-child relationships automatically, making it easy to create complex game worlds from simple SVG layouts.
