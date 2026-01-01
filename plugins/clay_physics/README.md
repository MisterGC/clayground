# Clay Physics Plugin

The Clay Physics plugin provides physics simulation components built on top of
the Box2D physics engine. It offers easy-to-use QML components for creating
physics-enabled game objects with proper world unit integration and collision
detection capabilities.

## Getting Started

To use the Clay Physics plugin in your QML files:

```qml
import Clayground.Physics
import Box2D
```

## Core Components

- **PhysicsItem** - Base component for physics-enabled items with world unit support
- **RectBoxBody** - Rectangle-shaped physics body with visual representation
- **ImageBoxBody** - Image-based physics body with box collision
- **VisualizedPolyBody** - Polygon physics body integrated with Canvas visualization
- **CollisionTracker** - Tracks entities colliding with a fixture
- **PhysicsUtils** - Singleton with collision connection helpers

## Usage Examples

### Basic Physics Object

```qml
import QtQuick
import Box2D
import Clayground.Physics

World {
    id: physicsWorld
    gravity: Qt.point(0, -10)

    RectBoxBody {
        xWu: 5
        yWu: 10
        widthWu: 2
        heightWu: 1
        color: "blue"

        bodyType: Body.Dynamic
        density: 1
        friction: 0.3
        restitution: 0.5
    }
}
```

### Platform Game Character

```qml
RectBoxBody {
    id: player
    widthWu: 1
    heightWu: 2
    color: "orange"

    bodyType: Body.Dynamic
    fixedRotation: true
    bullet: true

    categories: Box.Category1
    collidesWith: Box.Category2 | Box.Category3

    // Jump logic
    function jump() {
        if (onGround) {
            linearVelocity.y = 10
        }
    }

    // Ground detection
    property bool onGround: false
    CollisionTracker {
        fixture: player.fixture
        debug: true
        onBeginContact: (entity) => {
            if (entity.objectName === "ground") {
                player.onGround = true
            }
        }
        onEndContact: (entity) => {
            if (entity.objectName === "ground") {
                player.onGround = false
            }
        }
    }
}
```

### Collectible Items

```qml
ImageBoxBody {
    source: "coin.png"
    xWu: 10
    yWu: 5
    widthWu: 0.5
    heightWu: 0.5

    bodyType: Body.Static
    sensor: true

    categories: Box.Category4
    collidesWith: Box.Category1  // Player category

    Component.onCompleted: {
        PhysicsUtils.connectOnEntered(fixture, (entity) => {
            if (entity.objectName === "player") {
                // Award points
                destroy()
            }
        })
    }
}
```

### Moving Platform

```qml
RectBoxBody {
    id: platform
    widthWu: 4
    heightWu: 0.5
    color: "gray"

    bodyType: Body.Kinematic

    SequentialAnimation on xWu {
        loops: Animation.Infinite
        NumberAnimation { to: 10; duration: 3000 }
        NumberAnimation { to: 5; duration: 3000 }
    }
}
```

### Complex Polygon Shape

```qml
VisualizedPolyBody {
    canvas: myCanvas
    vertices: [
        {x: 0, y: 0},
        {x: 2, y: 0},
        {x: 2, y: 1},
        {x: 1, y: 2},
        {x: 0, y: 1}
    ]
    fillColor: "green"
    strokeColor: "darkgreen"

    bodyType: Body.Dynamic
    density: 2
}
```

### Trigger Zones

```qml
RectBoxBody {
    id: triggerZone
    xWu: 15
    yWu: 10
    widthWu: 5
    heightWu: 5
    color: "yellow"
    opacity: 0.3

    bodyType: Body.Static
    sensor: true

    CollisionTracker {
        fixture: triggerZone.fixture
        onBeginContact: (entity) => {
            console.log("Entity entered zone:", entity)
            // Trigger game event
        }
        onEndContact: (entity) => {
            console.log("Entity left zone:", entity)
        }
    }
}
```

## Best Practices

1. **World Units**: Always use world units (Wu) for consistency across different screen sizes.

2. **Collision Categories**: Use Box2D categories and masks for efficient collision filtering.

3. **Body Types**:
   - Static: Non-moving obstacles
   - Kinematic: Moving platforms (animated)
   - Dynamic: Physics-controlled objects

4. **Performance**: Use sensors for triggers to avoid physical collision responses.

5. **Continuous Collision**: Enable `bullet` property for fast-moving objects to prevent tunneling.

## Technical Implementation

The Clay Physics plugin:

- **Box2D Integration**: Wraps QML Box2D with world unit support
- **Coordinate System**: Automatic conversion between screen pixels and world units
- **Collision Management**: Simplified collision detection with signal-based API
- **Visual Integration**: Seamless integration with visual components
- **Memory Management**: Automatic cleanup of collision tracking when objects are destroyed

The plugin handles the complexity of coordinate transformations and provides a clean API for common game physics scenarios.
