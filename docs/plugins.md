---
layout: page
title: Plugins
permalink: /plugins/
---

# Clayground Plugins

Each plugin provides specific functionality that you can mix and match to build your game. All plugins come with comprehensive documentation and examples.

## 🏗️ Foundation Plugins

Essential utilities and data management components.

### [Common]({{ site.baseurl }}/plugins/common/)
Essential utilities and timing tools used across the framework. Includes the Clayground singleton for environment detection and ClayStopWatch for precise timing.

### [Storage]({{ site.baseurl }}/plugins/storage/)
Persistent key-value storage for game data, settings, and player progress. Built on Qt's LocalStorage for cross-platform compatibility.

### [Text]({{ site.baseurl }}/plugins/text/)
Advanced text processing including CSV parsing, JSON transformations with JSONata, and regex-based text highlighting.

### [SVG]({{ site.baseurl }}/plugins/svg/)
Read and write SVG files, extract game objects from Inkscape drawings, and use SVG elements as image sources. Perfect for level design workflows.

## 🎨 Rendering Plugins

Visual presentation systems for 2D and 3D games.

### [Canvas]({{ site.baseurl }}/plugins/canvas/)
2D world coordinate system with camera controls, viewport management, and visual elements positioned in world units. Includes debug overlays and keyboard navigation.

### [Canvas3D]({{ site.baseurl }}/plugins/canvas3d/)
3D primitives including boxes, lines, and voxel maps. Features toon shading support, edge rendering, and efficient batch rendering for complex 3D scenes.

## 🎮 Game System Plugins

Core gameplay mechanics and world management.

### [Physics]({{ site.baseurl }}/plugins/physics/)
Box2D-based 2D physics simulation with automatic world unit conversion. Provides easy-to-use components for rigid bodies and collision detection.

### [World]({{ site.baseurl }}/plugins/world/)
Complete game world management for both 2D and 3D games. Integrates canvas, physics, and SVG scene loading with automatic entity creation.

### [Behavior]({{ site.baseurl }}/plugins/behavior/)
Reusable entity behaviors including movement patterns, path following, triggers, and complex object builders. Works seamlessly with physics and world systems.

## 🔌 Input/Output Plugins

User interaction and communication systems.

### [GameController]({{ site.baseurl }}/plugins/gamecontroller/)
Unified input system supporting keyboard, physical gamepads, and touchscreen controls. Features NES-style simplicity with debug visualization.

### [Network]({{ site.baseurl }}/plugins/network/)
Peer-to-peer networking for local multiplayer games and HTTP client for web API integration. Includes automatic peer discovery and group messaging.

## 📦 Using Plugins

### Import in QML

```qml
import Clayground.Common
import Clayground.Canvas
import Clayground.Physics
```

### Plugin Dependencies

Some plugins build on others. For example:
- **World** requires Canvas (2D) or Canvas3D (3D) and Physics
- **Behavior** works best with World and Physics
- Most plugins use Common for utilities

### Creating Your Own Plugin

Follow the plugin structure:

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