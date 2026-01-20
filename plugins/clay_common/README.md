# Clay Common Plugin

The Clay Common plugin provides essential utilities and helper components that
are used across the Clayground framework. It includes singleton utilities for
resource management, debugging support, and timing functionality.

## Getting Started

To use the Clay Common plugin in your QML files:

```qml
import Clayground.Common
```

## Core Components

- **Clayground** - Global singleton providing utility functions for resource loading, environment detection, and browser detection.
- **ClayStopWatch** - A simple stopwatch for measuring elapsed time with millisecond precision.

## Usage Examples

### Resource Management

```qml
import QtQuick
import Clayground.Common

Image {
    // Automatically handles resource paths for both sandbox and production environments
    source: Clayground.resource("assets/player.png")
}
```

### Property Watching for Debugging

```qml
import QtQuick
import Clayground.Common

Rectangle {
    id: player
    property real velocity: 0
    
    Component.onCompleted: {
        // Watch velocity changes for debugging
        Clayground.watch(player, "velocity", true)
    }
}
```

### Timing Operations

```qml
import QtQuick
import Clayground.Common

Item {
    ClayStopWatch {
        id: stopwatch
    }
    
    Button {
        text: stopwatch.running ? "Stop" : "Start"
        onClicked: {
            if (stopwatch.running) {
                stopwatch.stop()
                console.log("Elapsed time:", stopwatch.elapsed, "ms")
            } else {
                stopwatch.start()
            }
        }
    }
}
```

### Type Name Inspection

```qml
import QtQuick
import Clayground.Common

Rectangle {
    Component.onCompleted: {
        console.log("This component type is:", Clayground.typeName(this))
    }
}
```

### Platform and Browser Detection

```qml
import QtQuick
import Clayground.Common

Item {
    Component.onCompleted: {
        console.log("Is WASM:", Clayground.isWasm)
        console.log("Browser:", Clayground.browser)
    }

    // Show warning for Firefox clipboard limitations
    Text {
        visible: Clayground.isWasm && Clayground.browser === "firefox"
        text: "Note: Clipboard paste requires Ctrl+V in Firefox"
        color: "orange"
    }
}
```

**`Clayground.isWasm`**: `true` when running as WebAssembly in a browser.

**`Clayground.browser`** values:
`"none"` (native app), `"chrome"`, `"firefox"`, `"safari"`, `"edge"`, `"opera"`, `"other"`

## Best Practices

1. **Resource Loading**: Always use `Clayground.resource()` for loading assets to ensure compatibility between sandbox and production environments.

2. **Debugging**: Use the `watch()` function during development to monitor property changes, but remember to remove or disable these calls in production code.

3. **Performance Timing**: Use `ClayStopWatch` for performance profiling during development to identify bottlenecks.

4. **Singleton Access**: The `Clayground` singleton is automatically available when you import the plugin - no instantiation needed.

## Technical Implementation

The Clay Common plugin consists of:

- **Clayground.qml**: A QML singleton that provides runtime environment detection, utility functions, and browser detection via JavaScript
- **ClayStopWatch**: A C++ class exposed to QML that wraps Qt's QElapsedTimer for precise timing

The plugin automatically detects whether it's running in the ClayLiveLoader sandbox environment and adjusts resource paths accordingly. This allows seamless development and deployment without changing resource references in your code.

Browser detection uses JavaScript's `navigator.userAgent` when running in WebAssembly, providing compatibility with dynamically loaded QML content.

The watch functionality integrates with the Clayground development tools to provide real-time property monitoring, making it easier to debug complex interactions and state changes in your application.
