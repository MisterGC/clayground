# Clay Common Plugin

The Clay Common plugin provides essential utilities and helper components that
are used across the Clayground framework. It includes singleton utilities for
resource management, debugging support, and timing functionality.

## Table of Contents

- [Getting Started](#getting-started)
- [Core Components](#core-components)
  - [Clayground Singleton](#clayground-singleton)
  - [ClayStopWatch](#claystopwatch)
- [Usage Examples](#usage-examples)
- [Best Practices](#best-practices)
- [Technical Implementation](#technical-implementation)

## Getting Started

To use the Clay Common plugin in your QML files:

```qml
import Clayground.Common
```

## Core Components

### Clayground Singleton

The `Clayground` singleton provides utilities for resource management and debugging across your application.

#### Properties

| Property | Type | Description |
|----------|------|-------------|
| `runsInSandbox` | bool (readonly) | Indicates whether the application is running in the Clayground sandbox environment |
| `watchView` | var | Reference to the watch view for debugging (set externally) |

#### Methods

| Method | Parameters | Description |
|--------|-----------|-------------|
| `resource(path)` | path: string | Returns the correct resource path based on the runtime environment |
| `watch(obj, prop, logPropChange)` | obj: object, prop: string, logPropChange: bool | Watches property changes for debugging purposes |
| `typeName(obj)` | obj: object | Returns the type name of a QML object |

### ClayStopWatch

A QML-exposed stopwatch component for measuring elapsed time.

#### Properties

| Property | Type | Description |
|----------|------|-------------|
| `elapsed` | int | The elapsed time in milliseconds |
| `running` | bool | Whether the stopwatch is currently running |

#### Methods

| Method | Description |
|--------|-------------|
| `start()` | Starts the stopwatch |
| `stop()` | Stops the stopwatch and updates the elapsed time |

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

## Best Practices

1. **Resource Loading**: Always use `Clayground.resource()` for loading assets to ensure compatibility between sandbox and production environments.

2. **Debugging**: Use the `watch()` function during development to monitor property changes, but remember to remove or disable these calls in production code.

3. **Performance Timing**: Use `ClayStopWatch` for performance profiling during development to identify bottlenecks.

4. **Singleton Access**: The `Clayground` singleton is automatically available when you import the plugin - no instantiation needed.

## Technical Implementation

The Clay Common plugin consists of:

- **Clayground.qml**: A QML singleton that provides runtime environment detection and utility functions
- **ClayStopWatch**: A C++ class exposed to QML that wraps Qt's QElapsedTimer for precise timing

The plugin automatically detects whether it's running in the ClayLiveLoader sandbox environment and adjusts resource paths accordingly. This allows seamless development and deployment without changing resource references in your code.

The watch functionality integrates with the Clayground development tools to provide real-time property monitoring, making it easier to debug complex interactions and state changes in your application.
