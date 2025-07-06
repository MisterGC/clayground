# Clay Physics Plugin

The Clay Physics plugin provides physics simulation components built on top of
the Box2D physics engine. It offers easy-to-use QML components for creating
physics-enabled game objects with proper world unit integration and collision
detection capabilities.

## Table of Contents

- [Getting Started](#getting-started)
- [Core Components](#core-components)
  - [PhysicsItem](#physicsitem)
  - [RectBoxBody](#rectboxbody)
  - [ImageBoxBody](#imageboxbody)
  - [VisualizedPolyBody](#visualizedpolybody)
  - [CollisionTracker](#collisiontracker)
  - [PhysicsUtils](#physicsutils)
- [Usage Examples](#usage-examples)
- [Best Practices](#best-practices)
- [Technical Implementation](#technical-implementation)

## Getting Started

To use the Clay Physics plugin in your QML files:

```qml
import Clayground.Physics
import Box2D
```

## Core Components

### PhysicsItem

Base component for physics-enabled items with world unit support.

#### Properties

| Property | Type | Description |
|----------|------|-------------|
| `pixelPerUnit` | real | Conversion factor between pixels and world units |
| `xWu` | real | X position in world units |
| `yWu` | real | Y position in world units |
| `widthWu` | real | Width in world units |
| `heightWu` | real | Height in world units |
| `body` | Body | The Box2D body instance |

#### Body Properties (Aliases)

| Property | Type | Description |
|----------|------|-------------|
| `world` | World | Physics world reference |
| `bodyType` | Body.BodyType | Static, Kinematic, or Dynamic |
| `linearVelocity` | point | Linear velocity vector |
| `angularVelocity` | real | Angular velocity |
| `linearDamping` | real | Linear motion damping |
| `angularDamping` | real | Angular motion damping |
| `fixedRotation` | bool | Prevent rotation |
| `bullet` | bool | Enable continuous collision detection |
| `gravityScale` | real | Gravity effect multiplier |

### RectBoxBody

Rectangle-shaped physics body with visual representation.

#### Additional Properties

| Property | Type | Description |
|----------|------|-------------|
| `color` | color | Rectangle fill color |
| `radius` | real | Corner radius |
| `border` | Border | Rectangle border properties |
| `density` | real | Fixture density |
| `friction` | real | Fixture friction |
| `restitution` | real | Fixture bounciness |
| `sensor` | bool | Pass-through collision detection |
| `categories` | int | Collision category bits |
| `collidesWith` | int | Collision mask bits |

### ImageBoxBody

Image-based physics body with Box2D collision.

#### Additional Properties

| Property | Type | Description |
|----------|------|-------------|
| `source` | url | Image source URL |
| `fillMode` | Image.FillMode | Image scaling mode |
| `mirror` | bool | Mirror the image |
| `tileWidthWu` | real | Tile width for repeating images |
| `tileHeightWu` | real | Tile height for repeating images |

### VisualizedPolyBody

Polygon-shaped physics body integrated with Clay Canvas.

#### Properties

Inherits all Body and Fixture properties from PhysicsItem, plus:

| Property | Type | Description |
|----------|------|-------------|
| `vertices` | var | Array of polygon vertices |

### CollisionTracker

Tracks entities currently colliding with a fixture.

#### Properties

| Property | Type | Description |
|----------|------|-------------|
| `fixture` | Fixture | Fixture to monitor |
| `entities` | Set | Currently colliding entities |
| `debug` | bool | Show debug visualization |

#### Signals

| Signal | Parameters | Description |
|--------|-----------|-------------|
| `beginContact(entity)` | entity: var | Entity entered collision |
| `endContact(entity)` | entity: var | Entity left collision |

### PhysicsUtils

Singleton utility for physics operations.

#### Methods

| Method | Parameters | Description |
|--------|-----------|-------------|
| `connectOnEntered(fixture, method, fixtureCheck)` | fixture: Fixture, method: function, fixtureCheck: function | Connect to fixture's begin contact |
| `connectOnLeft(fixture, method, fixtureCheck)` | fixture: Fixture, method: function, fixtureCheck: function | Connect to fixture's end contact |

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
