# Clay Behavior Plugin

The Clay Behavior plugin provides reusable behavior components for game
entities, including movement patterns, path following, triggers, and complex
object builders. It integrates with the Clay World and Physics plugins to
create dynamic, interactive game behaviors.

## Getting Started

To use the Clay Behavior plugin in your QML files:

```qml
import Clayground.Behavior
```

## Core Components

- **Move** - Placeholder for future movement behavior implementation.
- **MoveTo** - Moves an actor entity to a specified destination using physics-based velocity control.
- **FollowPath** - Makes an entity follow a predefined path of waypoints with optional looping.
- **RectTrigger** - A rectangular sensor area that detects when physics entities enter it.
- **WorldChangedConnections** - Utility that monitors world dimension changes and invokes a callback.
- **DoorBuilder** - Factory component that creates automated doors with switches from SVG map data.

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
