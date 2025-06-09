# Clay GameController Plugin

The Clay GameController plugin provides a unified game input system that
supports multiple input sources including keyboard, physical gamepads, and
touchscreen controls. It's designed with simplicity in mind, offering NES-style
controller functionality with directional controls and two action buttons.

## Table of Contents

- [Getting Started](#getting-started)
- [Core Components](#core-components)
  - [GameController](#gamecontroller)
  - [GameControllerDV](#gamecontrollerdv)
  - [KeyboardGamepad](#keyboardgamepad)
  - [TouchscreenGamepad](#touchscreengamepad)
  - [GamepadWrapper](#gamepadwrapper)
- [Usage Examples](#usage-examples)
- [Best Practices](#best-practices)
- [Technical Implementation](#technical-implementation)

## Getting Started

To use the Clay GameController plugin in your QML files:

```qml
import Clayground.GameController
```

## Core Components

### GameController

The main controller component that unifies input from different sources.

#### Properties

| Property | Type | Description |
|----------|------|-------------|
| `axisX` | real | Horizontal axis value (-1 to 1) |
| `axisY` | real | Vertical axis value (-1 to 1) |
| `buttonAPressed` | bool | State of button A |
| `buttonBPressed` | bool | State of button B |
| `showDebugOverlay` | bool | Show visual debug overlay |

#### Read-only Properties

| Property | Type | Description |
|----------|------|-------------|
| `gamepadSelected` | bool | True if a physical gamepad is active |
| `vGamepadSelected` | bool | True if touchscreen gamepad is active |
| `keyboardSelected` | bool | True if keyboard input is active |
| `gamepad` | var | Reference to connected gamepad (if any) |
| `gamepadDeviceId` | int | ID of connected gamepad (-1 if none) |
| `numConnectedGamepads` | int | Number of connected physical gamepads |

#### Methods

| Method | Parameters | Description |
|--------|-----------|-------------|
| `selectGamepad(gamePadIdx, useAnalogAxis)` | gamePadIdx: int, useAnalogAxis: bool | Select a physical gamepad |
| `selectKeyboard(upKey, downKey, leftKey, rightKey, buttonAKey, buttonBKey)` | Qt.Key values | Configure keyboard input |
| `selectTouchscreenGamepad()` | none | Enable touchscreen controls |

### GameControllerDV

Debug visualization component that shows the current state of a GameController.

#### Properties

| Property | Type | Description |
|----------|------|-------------|
| `observed` | GameController | The controller to visualize |

### KeyboardGamepad

Internal component that handles keyboard input mapping.

#### Properties

| Property | Type | Description |
|----------|------|-------------|
| `enabled` | bool | Whether keyboard input is active |
| `gameController` | GameController | Parent controller reference |

### TouchscreenGamepad

Virtual on-screen gamepad for touch devices.

#### Properties

| Property | Type | Description |
|----------|------|-------------|
| `enabled` | bool | Whether touch input is active |
| `visible` | bool | Visibility of touch controls |
| `gameController` | GameController | Parent controller reference |

### GamepadWrapper

Wrapper for Qt's Gamepad API (currently disabled in Qt6).

## Usage Examples

### Basic Controller Setup

```qml
import QtQuick
import Clayground.GameController

Item {
    GameController {
        id: controller
        
        // Enable debug visualization
        showDebugOverlay: true
        
        Component.onCompleted: {
            // Try gamepad first, fallback to keyboard
            if (numConnectedGamepads > 0)
                selectGamepad(0, true)  // Use analog sticks
            else
                selectKeyboard(
                    Qt.Key_W,      // Up
                    Qt.Key_S,      // Down
                    Qt.Key_A,      // Left
                    Qt.Key_D,      // Right
                    Qt.Key_Space,  // Button A
                    Qt.Key_Return  // Button B
                )
        }
    }
}
```

### Player Movement

```qml
Rectangle {
    id: player
    width: 50
    height: 50
    color: "blue"
    
    GameController {
        id: controller
        anchors.fill: parent
    }
    
    // Move player based on controller input
    x: x + controller.axisX * 5
    y: y - controller.axisY * 5  // Invert Y for screen coordinates
    
    // Change color when buttons pressed
    color: controller.buttonAPressed ? "red" : 
           controller.buttonBPressed ? "green" : "blue"
}
```

### Multi-Controller Support

```qml
Row {
    GameController {
        id: player1Controller
        Component.onCompleted: {
            if (numConnectedGamepads > 0)
                selectGamepad(0, false)  // Use D-pad
            else
                selectKeyboard(
                    Qt.Key_Up, Qt.Key_Down, 
                    Qt.Key_Left, Qt.Key_Right,
                    Qt.Key_M, Qt.Key_N
                )
        }
    }
    
    GameController {
        id: player2Controller
        Component.onCompleted: {
            if (numConnectedGamepads > 1)
                selectGamepad(1, false)
            else
                selectTouchscreenGamepad()
        }
    }
}
```

### Touch Controls for Mobile

```qml
GameController {
    id: mobileController
    anchors.fill: parent
    
    Component.onCompleted: {
        // Auto-select input based on platform
        if (Qt.platform.os === "android" || Qt.platform.os === "ios") {
            selectTouchscreenGamepad()
        } else {
            selectKeyboard(
                Qt.Key_Up, Qt.Key_Down,
                Qt.Key_Left, Qt.Key_Right,
                Qt.Key_X, Qt.Key_Z
            )
        }
    }
}
```

### Custom Input Handling

```qml
GameController {
    id: controller
    
    // React to input changes
    onAxisXChanged: {
        if (axisX > 0.5) 
            console.log("Moving right")
        else if (axisX < -0.5) 
            console.log("Moving left")
    }
    
    onButtonAPressedChanged: {
        if (buttonAPressed)
            console.log("Jump!")
    }
}
```

## Best Practices

1. **Input Priority**: Always check for gamepads first, then fall back to keyboard or touch controls.

2. **Dead Zones**: The gamepad implementation includes a 0.2 dead zone for analog sticks to prevent drift.

3. **Platform Detection**: Use Qt.platform.os to automatically select appropriate input methods.

4. **Key Forwarding**: Use Keys.forwardTo to ensure the controller receives keyboard input.

5. **Debug Mode**: Enable showDebugOverlay during development to visualize input states.

## Technical Implementation

The GameController plugin implements:

- **Unified API**: Single interface for all input types
- **Auto-switching**: Seamless switching between input sources
- **Visual Feedback**: Built-in debug visualization
- **Touch Adaptation**: Virtual joystick with visual feedback for touch screens
- **Simple Design**: NES-inspired two-button controller for broad compatibility

Note: Physical gamepad support is currently disabled due to Qt6 compatibility issues but the architecture supports it for future versions.
