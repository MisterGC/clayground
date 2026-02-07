---
layout: docs
title: First Sandbox
permalink: /docs/getting-started/first-sandbox/
---

This guide walks you through running Dojo and creating your first game object.

## Running the Sandbox

The primary development tool is Dojo, a live-reloading sandbox environment:

```bash
./build/bin/claydojo --sbx examples/void/Sandbox.qml
```

## Key Shortcuts

Press `Ctrl+G` in the sandbox window to see all available shortcuts:

| Shortcut | Action |
|----------|--------|
| `Ctrl+G` | Toggle guide/help overlay |
| `Ctrl+L` | Toggle logging overlay |
| `Ctrl+R` | Reload current sandbox |
| `Ctrl+1-5` | Switch between loaded sandboxes |

## Live Reloading

The key development feature is instant feedback:

1. Keep the sandbox window visible
2. Open `examples/void/Sandbox.qml` in your editor
3. Make changes and save
4. Watch your changes appear instantly!

Example change to try:

```qml
Rectangle {
    width: 200
    height: 200
    color: "cyan"  // Change this color

    Text {
        anchors.centerIn: parent
        text: "Hello Clayground!"  // Change this text
        font.pixelSize: 20
    }
}
```

## Your First Game Object

Let's create a simple moving square using Canvas and Physics:

```qml
import QtQuick
import Clayground.Canvas
import Clayground.Physics

ClayCanvas {
    anchors.fill: parent
    pixelPerUnit: 50

    World {
        id: world
        gravity: Qt.point(0, -10)

        RectBoxBody {
            width: 2
            height: 2
            color: "red"
            bodyType: Body.Dynamic

            Component.onCompleted: {
                // Give it a push!
                body.linearVelocity = Qt.point(5, 10)
            }
        }

        // Ground
        RectBoxBody {
            y: -5
            width: 20
            height: 1
            color: "green"
            bodyType: Body.Static
        }
    }
}
```

## Working with Multiple Sandboxes

Launch with multiple sandbox files to switch between them quickly:

```bash
./build/bin/claydojo \
    --sbx examples/void/Sandbox.qml \
    --sbx examples/platformer/Sandbox.qml \
    --sbx examples/topdown/Sandbox.qml
```

Use `Ctrl+1`, `Ctrl+2`, `Ctrl+3` to switch between them instantly.

## Using the Logging Overlay

The logging overlay (`Ctrl+L`) shows:
- Console output from `console.log()`
- Watched properties
- Performance metrics

Example with property watching:

```qml
Component.onCompleted: {
    Clayground.watch("Player X", () => player.x)
    Clayground.watch("Player Speed", () => player.body.linearVelocity.x)
}
```

## Explore Examples

Each example demonstrates different features:

- **void** - Minimal starting point
- **platformer** - Jump and run mechanics
- **topdown** - RPG-style movement
- **visualfx** - Particle effects
- **gui** - UI components

## Next Steps

- Learn about [Dojo in detail]({{ site.baseurl }}/docs/manual/dojo/)
- Explore the [Plugin Reference]({{ site.baseurl }}/docs/plugins/)
- Try [WASM builds]({{ site.baseurl }}/docs/getting-started/wasm-builds/) for web deployment
