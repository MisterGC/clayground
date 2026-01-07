# Clay World Plugin

The Clay World plugin provides comprehensive game world management for both 2D
and 3D games. It integrates canvas rendering, physics simulation, and SVG-based
level loading into cohesive world components. The plugin offers separate
implementations for 2D and 3D worlds while sharing common functionality like
scene loading and entity management.

## Getting Started

To use the Clay World plugin in your QML files:

```qml
import Clayground.World
```

## Core Components

- **ClayWorld2d** - Complete 2D game world with Box2D physics, ClayCanvas rendering, and camera following
- **ClayWorld3d** - Complete 3D game world with Qt Quick 3D physics and WASD/orbit camera controls
- **ClayWorldBase** - Shared base functionality for scene loading and entity management
- **SceneLoader2d** - Loads entities from SVG files into 2D worlds
- **SceneLoader3d** - Loads entities from SVG files into 3D worlds
- **Minimap2d** - Miniature map view of a 2D world
- **Box3DBody** - 3D physics-enabled box shape

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
