---
layout: docs
title: Dojo - Live Reloading
permalink: /docs/manual/dojo/
---

Dojo is the primary development tool for Clayground projects. It monitors your source files and automatically reloads the sandbox when changes are detected.

## Basic Usage

```bash
# Run a single sandbox
./build/bin/claydojo --sbx examples/platformer/Sandbox.qml

# Run multiple sandboxes (switch with Ctrl+1-5)
./build/bin/claydojo \
    --sbx examples/platformer/Sandbox.qml \
    --sbx examples/topdown/Sandbox.qml \
    --sbx examples/visualfx/Sandbox.qml
```

## Command-Line Options

| Option | Description |
|--------|-------------|
| `--sbx <path>` | QML sandbox file to load (can be used multiple times) |
| `--sbxindex <n>` | Which sandbox to load initially (0-based) |
| `--dynplugin <src,bin>` | Watch plugin source and binary directories |
| `--import <dir>` | Add QML import directory |
| `--guistyle <style>` | Set Qt Quick GUI style |

## Keyboard Shortcuts

| Shortcut | Action |
|----------|--------|
| `Ctrl+G` | Toggle guide overlay |
| `Ctrl+L` | Toggle logging overlay |
| `Ctrl+1` to `Ctrl+5` | Switch between loaded sandboxes |

## How Live-Reloading Works

At the heart of Dojo is a sophisticated hot-reload system. When you save a QML file, changes appear within milliseconds.

**The reload process:**

1. A recursive file watcher monitors your sandbox directory
2. A fresh QML engine is created for each reload
3. Changes fade in with a brief loading indicator
4. Session statistics persist across reloads

The 50ms debounce window catches rapid file changes from editor auto-saves.

## Dynamic Plugin Development

Beyond QML hot-reloading, Dojo supports live development of C++ plugins:

```bash
./build/bin/claydojo \
    --sbx examples/pluginlive/Sandbox.qml \
    --dynplugin examples/pluginlive/plugin,build/examples/pluginlive/plugin
```

The format is `--dynplugin <source_dir>,<binary_dir>`. Dojo detects when your plugin binary is rebuilt and automatically restarts with the updated code.

## Tips

1. **Keep the sandbox visible** while editing for immediate feedback
2. **Use multiple sandboxes** to quickly switch between different test scenarios
3. **Watch the console** for QML errors during reload
4. **Use the guide overlay** (`Ctrl+G`) when learning the shortcuts

## Next Steps

- Learn about the [Logging Overlay]({{ site.baseurl }}/docs/manual/logging/)
- Create your own [plugins]({{ site.baseurl }}/docs/manual/plugin-development/)
