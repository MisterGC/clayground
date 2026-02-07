---
layout: docs
title: Logging Overlay
permalink: /docs/manual/logging/
---

The logging overlay provides real-time debugging capabilities in the Dojo sandbox.

## Activating the Overlay

Press `Ctrl+L` in the sandbox window to toggle the logging overlay.

## Features

### Console Output

All `console.log()` messages appear in the overlay:

```qml
Component.onCompleted: {
    console.log("Player spawned at", player.x, player.y)
}

function onCollision(other) {
    console.log("Collision detected with", other.objectName)
}
```

### Property Watching

Monitor values as they change in real-time:

```qml
Component.onCompleted: {
    Clayground.watch("Player X", () => player.x)
    Clayground.watch("Player Y", () => player.y)
    Clayground.watch("Speed", () => player.body.linearVelocity.x)
    Clayground.watch("Health", () => gameState.health)
}
```

Watched properties update automatically and show their current values in the overlay.

### Performance Metrics

The overlay displays:
- Frame rate
- Reload count
- Session duration

## Best Practices

1. **Watch key game state** - Monitor player position, health, score during development
2. **Use meaningful names** - The first argument to `watch()` is the display label
3. **Remove watches in production** - Watches have minimal overhead but clean code is better
4. **Combine with console.log** - Use logging for events, watching for continuous values

## Example: Debugging Physics

```qml
import QtQuick
import Clayground.Canvas
import Clayground.Physics
import Clayground.Common

ClayCanvas {
    anchors.fill: parent
    pixelPerUnit: 50

    World {
        RectBoxBody {
            id: player
            width: 2
            height: 2
            color: "red"
            bodyType: Body.Dynamic

            Component.onCompleted: {
                // Watch physics state
                Clayground.watch("Velocity X", () => body.linearVelocity.x.toFixed(2))
                Clayground.watch("Velocity Y", () => body.linearVelocity.y.toFixed(2))
                Clayground.watch("Angular", () => body.angularVelocity.toFixed(2))
                Clayground.watch("Grounded", () => isGrounded ? "Yes" : "No")
            }
        }
    }
}
```

## Next Steps

- Learn about [Dojo]({{ site.baseurl }}/docs/manual/dojo/) features
- Create your own [plugins]({{ site.baseurl }}/docs/manual/plugin-development/)
