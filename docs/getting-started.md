---
layout: page
title: Getting Started
permalink: /getting-started/
---

# Getting Started with Clayground

Welcome! This guide will get you up and running with Clayground in minutes.

## Prerequisites

- **Qt 6.10.0+**
- **CMake 3.20+**
- **C++17 compiler**
- **Git** (for cloning the repository)

### Platform-Specific Notes

- **Linux**: Best performance and development experience
- **macOS**: Fully supported, good performance
- **Windows**: Supported, use Qt Creator or Visual Studio
- **Mobile**: iOS and Android supported for deployment
- **WebAssembly**: Deploy to the web (see [Building for WebAssembly](#building-for-webassembly))

## Installation

### 1. Clone the Repository

```bash
git clone --recursive https://github.com/mistergc/clayground.git
cd clayground
```

The `--recursive` flag is important as it pulls in required submodules.

### 2. Build the Project

```bash
cmake -B build
cmake --build build
```

For faster builds on multi-core systems:
```bash
cmake --build build -- -j$(nproc)  # Linux/macOS
cmake --build build -- -j%NUMBER_OF_PROCESSORS%  # Windows
```

### 3. Run Your First Sandbox

```bash
./build/bin/claydojo --sbx examples/void/Sandbox.qml
```

🎉 **Congratulations!** You should see a window with a simple sandbox environment.

## Building for WebAssembly

Deploy your Clayground app to the web using WebAssembly (Emscripten).

### Prerequisites

- **Qt 6.10.1+** with the WebAssembly component (single-threaded recommended)
- **Emscripten 4.0.7** (must match your Qt version's requirements)

Install Emscripten:
```bash
git clone https://github.com/emscripten-core/emsdk.git
cd emsdk
./emsdk install 4.0.7
./emsdk activate 4.0.7
source ./emsdk_env.sh
```

### Build for WASM

Use Qt's WASM-specific cmake wrapper:
```bash
~/Qt/6.10.1/wasm_singlethread/bin/qt-cmake -B build-wasm
cmake --build build-wasm
```

### Run Locally

WASM apps need an HTTP server (file:// URLs won't work):
```bash
cd build-wasm/bin
python3 -m http.server 8080
```

Open `http://localhost:8080/platformer.html` in your browser.

### Platform Limitations

- **Network plugin unavailable**: `Clayground.Network` uses TCP sockets which aren't supported in browsers
- **No dynamic plugin loading**: The `pluginlive` example is excluded
- **Single-threaded recommended**: Multi-threaded WASM requires special server headers (SharedArrayBuffer)

## Understanding the Sandbox

### Key Shortcuts

Press `Ctrl+G` in the sandbox window to see all available shortcuts:

- **Ctrl+G** - Toggle guide/help overlay
- **Ctrl+L** - Toggle logging overlay
- **Ctrl+R** - Reload current sandbox
- **Ctrl+1-5** - Switch between loaded sandboxes

### Live Reloading

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

## Next Steps

### Explore Examples

Each example demonstrates different features:

- **void** - Minimal starting point
- **platformer** - Jump and run mechanics
- **topdown** - RPG-style movement
- **visualfx** - Particle effects
- **gui** - UI components

### Learn the Plugins

Start with these essential plugins:
1. [Canvas]({{ site.baseurl }}/plugins/canvas/) - 2D rendering
2. [Physics]({{ site.baseurl }}/plugins/physics/) - Game physics
3. [GameController]({{ site.baseurl }}/plugins/gamecontroller/) - Input handling

### Create Your Own Project

1. Copy an example that's close to your needs
2. Modify the `CMakeLists.txt` with your app name
3. Start building your game!

## Tips for Effective Development

1. **Use the Sandbox First**: Prototype in the sandbox before creating a standalone app
2. **Small Changes**: Make incremental changes to see immediate feedback
3. **Watch Properties**: Use `Clayground.watch()` to monitor game state
4. **Check Examples**: Examples demonstrate most common patterns
5. **Read Plugin Docs**: Each plugin has comprehensive documentation

## Getting Help

- Check the [plugin documentation]({{ site.baseurl }}/plugins/)
- Look at example implementations
- File issues on [GitHub](https://github.com/mistergc/clayground/issues)
- Join the community discussions

---

Ready to create? Pick an [example](https://github.com/mistergc/clayground/tree/main/examples) and start modifying!