---
layout: page
title: Features
permalink: /features/
---

# Clayground Features

Clayground combines modular plugins with powerful development tools for rapid game prototyping.

---

## Plugins

Each plugin provides specific functionality that you can mix and match to build your game.

### Foundation Plugins

Essential utilities and data management components.

#### [Common]({{ site.baseurl }}/plugins/common/)
Essential utilities and timing tools used across the framework. Includes the Clayground singleton for environment detection and ClayStopWatch for precise timing.

#### [Storage]({{ site.baseurl }}/plugins/storage/)
Persistent key-value storage for game data, settings, and player progress. Built on Qt's LocalStorage for cross-platform compatibility.

#### [Text]({{ site.baseurl }}/plugins/text/)
Advanced text processing including CSV parsing, JSON transformations with JSONata, and regex-based text highlighting.

#### [SVG]({{ site.baseurl }}/plugins/svg/)
Read and write SVG files, extract game objects from Inkscape drawings, and use SVG elements as image sources. Perfect for level design workflows.

### Rendering Plugins

Visual presentation systems for 2D and 3D games.

#### [Canvas]({{ site.baseurl }}/plugins/canvas/)
2D world coordinate system with camera controls, viewport management, and visual elements positioned in world units. Includes debug overlays and keyboard navigation.

#### [Canvas3D]({{ site.baseurl }}/plugins/canvas3d/)
3D primitives including boxes, lines, and voxel maps. Features toon shading support, edge rendering, and efficient batch rendering for complex 3D scenes.

### Game System Plugins

Core gameplay mechanics and world management.

#### [Physics]({{ site.baseurl }}/plugins/physics/)
Box2D-based 2D physics simulation with automatic world unit conversion. Provides easy-to-use components for rigid bodies and collision detection.

#### [World]({{ site.baseurl }}/plugins/world/)
Complete game world management for both 2D and 3D games. Integrates canvas, physics, and SVG scene loading with automatic entity creation.

#### [Behavior]({{ site.baseurl }}/plugins/behavior/)
Reusable entity behaviors including movement patterns, path following, triggers, and complex object builders. Works seamlessly with physics and world systems.

### Input/Output Plugins

User interaction and communication systems.

#### [GameController]({{ site.baseurl }}/plugins/gamecontroller/)
Unified input system supporting keyboard, physical gamepads, and touchscreen controls. Features NES-style simplicity with debug visualization.

#### [Network]({{ site.baseurl }}/plugins/network/)
Peer-to-peer networking for local multiplayer games and HTTP client for web API integration. Includes automatic peer discovery and group messaging.

### Using Plugins

```qml
import Clayground.Common
import Clayground.Canvas
import Clayground.Physics
```

Some plugins build on others:
- **World** requires Canvas (2D) or Canvas3D (3D) and Physics
- **Behavior** works best with World and Physics
- Most plugins use Common for utilities

---

## Development Tools

Clayground ships with powerful development tools designed for rapid iteration.

### Dojo - Live Reloading Sandbox

The primary development tool for Clayground projects. Dojo monitors your source files and automatically reloads the sandbox when changes are detected.

#### Basic Usage

```bash
# Run a single sandbox
./build/bin/claydojo --sbx examples/platformer/Sandbox.qml

# Run multiple sandboxes (switch with Ctrl+1-5)
./build/bin/claydojo \
    --sbx examples/platformer/Sandbox.qml \
    --sbx examples/topdown/Sandbox.qml \
    --sbx examples/visualfx/Sandbox.qml
```

#### Command-Line Options

| Option | Description |
|--------|-------------|
| `--sbx <path>` | QML sandbox file to load (can be used multiple times) |
| `--sbxindex <n>` | Which sandbox to load initially (0-based) |
| `--dynplugin <src,bin>` | Watch plugin source and binary directories |
| `--import <dir>` | Add QML import directory |
| `--guistyle <style>` | Set Qt Quick GUI style |

#### Keyboard Shortcuts

| Shortcut | Action |
|----------|--------|
| `Ctrl+G` | Toggle guide overlay |
| `Ctrl+L` | Toggle logging overlay |
| `Ctrl+1` to `Ctrl+5` | Switch between loaded sandboxes |

### Live-Reloading

At the heart of Dojo is a sophisticated hot-reload system. When you save a QML file, changes appear within milliseconds.

**How it works:**
1. A recursive file watcher monitors your sandbox directory
2. A fresh QML engine is created for each reload
3. Changes fade in with a brief loading indicator
4. Session statistics persist across reloads

The 50ms debounce window catches rapid file changes from editor auto-saves.

### Logging Overlay

The logging overlay (`Ctrl+L`) provides real-time debugging:

- **Console Output**: All `console.log()` messages appear here
- **Property Watching**: Monitor values as they change

```qml
Component.onCompleted: {
    Clayground.watch("Player X", () => player.x)
    Clayground.watch("Speed", () => player.body.linearVelocity.x)
}
```

### Dynamic Plugin Development

Beyond QML hot-reloading, Dojo supports live development of C++ plugins:

```bash
./build/bin/claydojo \
    --sbx examples/pluginlive/Sandbox.qml \
    --dynplugin examples/pluginlive/plugin,build/examples/pluginlive/plugin
```

The format is `--dynplugin <source_dir>,<binary_dir>`. Dojo detects when your plugin binary is rebuilt and automatically restarts with the updated code.

### Creating Your Own Plugin

```cmake
clay_plugin(clay_myplugin
    QML_SOURCES
        MyComponent.qml
        Sandbox.qml
    SOURCES
        src/myclass.cpp
        src/myclass.h
)
```

See the [Plugin Development Guide](https://github.com/mistergc/clayground#plugin-development) for details.
