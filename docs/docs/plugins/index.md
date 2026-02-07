---
layout: docs
title: Plugin Reference
permalink: /docs/plugins/
---

Clayground provides a modular plugin system. Each plugin focuses on specific functionality that you can mix and match.

## Foundation Plugins

Essential utilities and data management.

- **[Common]({{ site.baseurl }}/docs/plugins/common/)** - Essential utilities, timing tools, and the Clayground singleton
- **[Storage]({{ site.baseurl }}/docs/plugins/storage/)** - Persistent key-value storage for game data and settings
- **[Text]({{ site.baseurl }}/docs/plugins/text/)** - CSV parsing, JSON transformations, and text highlighting
- **[SVG]({{ site.baseurl }}/docs/plugins/svg/)** - Read/write SVG files and use SVG elements as image sources

## Rendering Plugins

Visual presentation for 2D and 3D games.

- **[Canvas]({{ site.baseurl }}/docs/plugins/canvas/)** - 2D world coordinate system with camera and viewport management
- **[Canvas3D]({{ site.baseurl }}/docs/plugins/canvas3d/)** - 3D primitives with toon shading and voxel maps

## Game System Plugins

Core gameplay mechanics and world management.

- **[Physics]({{ site.baseurl }}/docs/plugins/physics/)** - Box2D-based 2D physics simulation
- **[World]({{ site.baseurl }}/docs/plugins/world/)** - Complete game world management for 2D and 3D
- **[Behavior]({{ site.baseurl }}/docs/plugins/behavior/)** - Entity behaviors: movement, triggers, and path following

## Input/Output Plugins

User interaction and communication.

- **[GameController]({{ site.baseurl }}/docs/plugins/gamecontroller/)** - Unified input for keyboard, gamepad, and touch
- **[Network]({{ site.baseurl }}/docs/plugins/network/)** - P2P multiplayer and HTTP client

## AI Plugin

- **[AI]({{ site.baseurl }}/docs/plugins/ai/)** - Client-side LLM inference (runs locally)

## Using Plugins

Import plugins in your QML files:

```qml
import Clayground.Common
import Clayground.Canvas
import Clayground.Physics
```

### Plugin Dependencies

Some plugins build on others:
- **World** requires Canvas (2D) or Canvas3D (3D) and Physics
- **Behavior** works best with World and Physics
- Most plugins use Common for utilities

## API Reference

For detailed type documentation, see the [API Reference]({{ site.baseurl }}/api/).
