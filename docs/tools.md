---
layout: page
title: Tools
permalink: /tools/
---

# Development Tools

Clayground ships with powerful development tools designed for rapid iteration. The centerpiece is **Dojo**, a live-reloading sandbox environment that watches your files and instantly reflects changes—for both QML and C++ plugins.

## 🛠️ Dojo

The primary development tool for Clayground projects. Dojo monitors your source files and automatically reloads the sandbox when changes are detected.

### Basic Usage

```bash
# Run a single sandbox
./build/bin/claydojo --sbx examples/platformer/Sandbox.qml

# Run multiple sandboxes (switch with Ctrl+1-5)
./build/bin/claydojo \
    --sbx examples/platformer/Sandbox.qml \
    --sbx examples/topdown/Sandbox.qml \
    --sbx examples/visualfx/Sandbox.qml
```

### Command-Line Options

| Option | Description |
|--------|-------------|
| `--sbx <path>` | QML sandbox file to load (can be used multiple times) |
| `--sbxindex <n>` | Which sandbox to load initially (0-based) |
| `--dynplugin <src,bin>` | Watch plugin source and binary directories |
| `--import <dir>` | Add QML import directory |
| `--guistyle <style>` | Set Qt Quick GUI style |

### Session Statistics

Dojo displays a manager window with session information:
- Restart counter tracking how many times your sandbox reloaded
- Session timer showing development time
- Error status indicator for critical issues

## ⚡ Live-Reloading

At the heart of Dojo is a sophisticated hot-reload system. When you save a QML file, changes appear within milliseconds—no restart required.

### How It Works

1. **File Detection**: A recursive file watcher monitors your sandbox directory
2. **Cache Clearing**: A fresh QML engine is created for each reload
3. **Smooth Transition**: Changes fade in with a brief loading indicator
4. **State Preservation**: Session statistics persist across reloads

The 50ms debounce window catches rapid file changes from editor auto-saves, ensuring stable reloads without flickering.

### QML Import Watching

Dojo automatically watches all directories in your QML import path, so changes to shared components trigger reloads too.

## 🔧 Dynamic Plugin Development

Beyond QML hot-reloading, Dojo supports live development of C++ plugins. The `--dynplugin` option enables automatic reloading when your plugin binaries are rebuilt.

### Setup

```bash
./build/bin/claydojo \
    --sbx examples/pluginlive/Sandbox.qml \
    --dynplugin examples/pluginlive/plugin,build/examples/pluginlive/plugin
```

The format is `--dynplugin <source_dir>,<binary_dir>` where:
- **source_dir**: Your plugin source files (`.h`, `.cpp`, `.qml`)
- **binary_dir**: Where CMake outputs the compiled plugin

### Development Workflow

1. Start Dojo with `--dynplugin` pointing to your plugin
2. Edit your C++ plugin code
3. Rebuild with CMake (or let your IDE rebuild automatically)
4. Dojo detects the new binary and restarts with the updated plugin

Dojo intelligently waits for builds to complete before restarting, preventing partial reloads during compilation.

### Example Plugin Structure

The `pluginlive` example demonstrates the pattern:

```
examples/pluginlive/
├── Sandbox.qml           # Uses the plugin
├── CMakeLists.txt
└── plugin/
    ├── mycomponent.h     # C++ QML types
    ├── mycomponent.cpp
    ├── MyItem.qml        # QML components
    └── CMakeLists.txt
```

The plugin exposes C++ functions to QML:

```cpp
class MyComponent: public QObject {
    Q_OBJECT
    QML_ELEMENT
public slots:
    QString sayHello() { return "It works :)"; }
};
```

Use it in your sandbox:

```qml
import Clayground.MyPlugin

Sandbox {
    MyComponent { id: comp }
    Text { text: comp.sayHello() }
}
```

## ⌨️ Keyboard Shortcuts

Press `Ctrl+G` in the sandbox window to see all available shortcuts:

| Shortcut | Action |
|----------|--------|
| `Ctrl+G` | Toggle guide overlay |
| `Ctrl+L` | Toggle logging overlay |
| `Ctrl+1` to `Ctrl+5` | Switch between loaded sandboxes |

## 📊 Logging Overlay

The logging overlay (`Ctrl+L`) provides real-time debugging:

- **Console Output**: All `console.log()` messages appear here
- **Property Watching**: Monitor values as they change

### Watching Properties

```qml
Component.onCompleted: {
    Clayground.watch("Player X", () => player.x)
    Clayground.watch("Speed", () => player.body.linearVelocity.x)
}
```

Watched properties update in real-time, making it easy to debug gameplay without cluttering the console.

## 🎯 Development Philosophy

The tools reflect Clayground's core principles:

- **Source Code First**: Focus on code and keyboard, not graphical editors
- **Immediate Feedback**: See changes instantly to maintain creative flow
- **Full Control**: Use high-level APIs or bypass them when needed
- **Minimal Friction**: Simple command-line interface, no configuration files

## Getting Started

1. Build Clayground following the [installation guide]({{ site.baseurl }}/getting-started/)
2. Run an example sandbox: `./build/bin/claydojo --sbx examples/void/Sandbox.qml`
3. Edit the QML file and watch it reload
4. Press `Ctrl+G` to explore available shortcuts

For C++ plugin development, study the `pluginlive` example to understand the full hot-reload workflow.
