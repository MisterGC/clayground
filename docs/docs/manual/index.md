---
layout: docs
title: Manual
permalink: /docs/manual/
---

The Clayground manual covers the development tools and workflows in detail.

## Development Tools

- **[Dojo - Live Reloading]({{ site.baseurl }}/docs/manual/dojo/)** - The primary development environment with hot-reload
- **[Logging Overlay]({{ site.baseurl }}/docs/manual/logging/)** - Real-time debugging and property watching
- **[Plugin Development]({{ site.baseurl }}/docs/manual/plugin-development/)** - Creating your own Clayground plugins

## Core Concepts

### Live Development

Clayground is built around the concept of instant feedback. Edit your QML files while the sandbox is running, and changes appear within milliseconds.

### Plugin Architecture

The framework is modular - each plugin provides specific functionality that you can mix and match:

```qml
import Clayground.Common
import Clayground.Canvas
import Clayground.Physics
```

Some plugins build on others:
- **World** requires Canvas (2D) or Canvas3D (3D) and Physics
- **Behavior** works best with World and Physics
- Most plugins use Common for utilities

### Scene Loading

Use SVG files for level design with `SceneLoader2d` or `SceneLoader3d`. World components often have built-in camera tracking via `observedObject`.

## Best Practices

1. **Prototype in the Sandbox First** - Test ideas quickly before creating standalone apps
2. **Small Incremental Changes** - Make small changes to leverage instant feedback
3. **Watch Properties** - Use `Clayground.watch()` to monitor game state
4. **Check Examples** - The examples demonstrate most common patterns
5. **Read Plugin Docs** - Each plugin has comprehensive documentation

## Next Steps

- Explore [Dojo]({{ site.baseurl }}/docs/manual/dojo/) in detail
- Learn about the [Logging Overlay]({{ site.baseurl }}/docs/manual/logging/)
- Create your own [plugins]({{ site.baseurl }}/docs/manual/plugin-development/)
