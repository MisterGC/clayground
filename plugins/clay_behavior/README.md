# Clay Behavior Plugin

The Clay Behavior plugin provides reusable behavior components for game
entities, including movement patterns, path following, triggers, and complex
object builders. It integrates with the Clay World and Physics plugins to
create dynamic, interactive game behaviors.

## Table of Contents

- [Getting Started](#getting-started)
- [Core Components](#core-components)
  - [Move](#move)
  - [MoveTo](#moveto)
  - [FollowPath](#followpath)
  - [RectTrigger](#recttrigger)
  - [WorldChangedConnections](#worldchangedconnections)
  - [DoorBuilder](#doorbuilder)
- [Usage Examples](#usage-examples)
- [Best Practices](#best-practices)
- [Technical Implementation](#technical-implementation)

## Getting Started

To use the Clay Behavior plugin in your QML files:

```qml
import Clayground.Behavior
```

## Core Components

### Move

A placeholder component for future movement behavior implementation.

### MoveTo

Moves an actor entity to a specified destination using physics-based movement.

#### Properties

| Property | Type | Description |
|----------|------|-------------|
| `world` | ClayWorld2d | The world context (required) |
| `actor` | var | The entity to move (defaults to parent) |
| `running` | bool | Whether the movement is active |
| `destXWu` | real | Destination X coordinate in world units |
| `destYWu` | real | Destination Y coordinate in world units |
| `desiredSpeed` | real | Movement speed (default: 2) |
| `debug` | bool | Show debug visualization |
| `debugColor` | color | Color for debug visualization |

#### Signals

| Signal | Description |
|--------|-------------|
| `arrived()` | Emitted when the actor reaches the destination |

### FollowPath

Makes an entity follow a predefined path of waypoints.

#### Properties

| Property | Type | Description |
|----------|------|-------------|
| `world` | ClayWorld2d | The world context (required) |
| `actor` | var | The entity to move (defaults to parent) |
| `wpsWu` | var | Array of waypoints in world units |
| `running` | bool | Whether the path following is active |
| `repeat` | bool | Loop the path when completed |
| `debug` | bool | Show debug visualization |
| `debugColor` | color | Color for debug visualization |

#### Signals

| Signal | Description |
|--------|-------------|
| `arrived()` | Emitted when the actor completes the path |

### RectTrigger

A rectangular trigger area that detects when entities enter it.

#### Properties

| Property | Type | Description |
|----------|------|-------------|
| `bodyType` | Body.BodyType | Set to Body.Dynamic |
| `sensor` | bool | Always true (doesn't cause collisions) |
| `visible` | bool | Whether the trigger is visible |

#### Signals

| Signal | Parameters | Description |
|--------|-----------|-------------|
| `entered(entity)` | entity: var | Emitted when an entity enters the trigger |

### WorldChangedConnections

Utility component that connects to world dimension changes.

#### Properties

| Property | Type | Description |
|----------|------|-------------|
| `world` | ClayWorld2d | The world to monitor (required) |
| `callback` | var | Function to call on world changes (required) |

### DoorBuilder

A specialized builder that creates automated doors with switches from map data.

#### Properties

| Property | Type | Description |
|----------|------|-------------|
| `world` | ClayWorld2d | The world context (required) |

## Usage Examples

### Basic Movement to Target

```qml
import Clayground.Behavior
import Clayground.Physics

RectBoxBody {
    id: enemy
    bodyType: Body.Kinematic
    
    MoveTo {
        world: theWorld
        destXWu: player.xWu
        destYWu: player.yWu
        running: true
        desiredSpeed: 3
        onArrived: console.log("Reached target!")
    }
}
```

### Path Patrol

```qml
import Clayground.Behavior

RectBoxBody {
    id: guard
    bodyType: Body.Kinematic
    
    FollowPath {
        world: theWorld
        wpsWu: [
            Qt.point(5, 5),
            Qt.point(10, 5),
            Qt.point(10, 10),
            Qt.point(5, 10)
        ]
        repeat: true
        running: true
        debug: true
    }
}
```

### Creating Triggers

```qml
import Clayground.Behavior

RectTrigger {
    xWu: 10
    yWu: 10
    widthWu: 2
    heightWu: 2
    visible: true
    color: "yellow"
    opacity: 0.5
    
    onEntered: (entity) => {
        console.log("Entity entered:", entity)
        // Trigger game logic
    }
}
```

### Automated Door System

```qml
import Clayground.Behavior
import Clayground.World

ClayWorld2d {
    id: theWorld
    
    // Door builder automatically creates doors from map data
    DoorBuilder {
        world: theWorld
    }
    
    // Map should contain groups named "door*" with:
    // - Door entities (component: "Door")
    // - DoorOpener entities (component: "DoorOpener")
    // - Polyline paths for door movement
}
```

### Responding to World Changes

```qml
import Clayground.Behavior

Item {
    WorldChangedConnections {
        world: theWorld
        callback: function() {
            // Recalculate positions when world dimensions change
            updateEntityPositions()
        }
    }
}
```

## Best Practices

1. **Performance**: Use `running` property to disable behaviors when not needed to save CPU cycles.

2. **Debug Visualization**: Enable `debug` property during development to visualize paths and destinations.

3. **Collision Setup**: Ensure proper collision categories are set for triggers and moving entities.

4. **Path Design**: Keep waypoints reasonable distances apart for smooth movement.

5. **World Units**: Always use world units (Wu) for positions and dimensions to maintain consistency.

## Technical Implementation

The Clay Behavior plugin implements several patterns:

- **Physics-Based Movement**: MoveTo uses Box2D's kinematic bodies with velocity adjustments
- **Waypoint System**: FollowPath manages sequential waypoint navigation
- **Trigger System**: RectTrigger uses Box2D sensors for enter detection
- **Builder Pattern**: DoorBuilder demonstrates complex object assembly from map data

The plugin integrates tightly with Clay World for coordinate systems and Clay Physics for collision detection and movement.
