---
layout: docs
title: GameController Plugin
permalink: /docs/plugins/gamecontroller/
---


The Clay GameController plugin provides a unified game input system that
supports multiple input sources including keyboard, physical gamepads, and
touchscreen controls. A game picks the controller's layout: `nes`, a stick and
two buttons (the default), or `full`, two sticks, A/B/X/Y, shoulders, triggers
and start/select. Every source delivers in the terms of that layout.

## Getting Started

To use the Clay GameController plugin in your QML files:

```qml
import Clayground.GameController
```

## Layouts

`layout` decides which inputs a `GameController` has. The sources - keyboard,
touchscreen and the dojo's agent input - set only those; every other input
stays at its neutral value (0 or `false`). `inputs` lists the layout's input
names, and `inputValue(name)` reads one by its name.

| Input | Property | Range | `nes` | `full` |
|---|---|---|---|---|
| `axisX`, `axisY` | `axisX`, `axisY` | -1..1, up and right positive | yes | yes, the left stick |
| `axisRightX`, `axisRightY` | `axisRightX`, `axisRightY` | -1..1 | | yes |
| `buttonA`, `buttonB` | `buttonAPressed`, `buttonBPressed` | bool | yes | yes |
| `buttonX`, `buttonY` | `buttonXPressed`, `buttonYPressed` | bool | | yes |
| `buttonL1`, `buttonR1` | `buttonL1Pressed`, `buttonR1Pressed` | bool, the shoulders | | yes |
| `triggerL2`, `triggerR2` | `triggerL2`, `triggerR2` | 0..1 | | yes |
| `buttonStart`, `buttonSelect` | `buttonStartPressed`, `buttonSelectPressed` | bool | | yes |

```qml
GameController {
    id: controller
    layout: "full"
    Component.onCompleted: selectKeyboard({
        axisX: [Qt.Key_A, Qt.Key_D],       // [negative, positive]
        axisY: [Qt.Key_S, Qt.Key_W],
        axisRightX: [Qt.Key_J, Qt.Key_L],
        axisRightY: [Qt.Key_K, Qt.Key_I],
        buttonA: Qt.Key_Space, buttonB: Qt.Key_Shift,
        buttonX: Qt.Key_F, buttonY: Qt.Key_R,
        buttonL1: Qt.Key_Q, buttonR1: Qt.Key_E,
        triggerL2: Qt.Key_1, triggerR2: Qt.Key_3,   // a held key reads 1
        buttonSelect: Qt.Key_Tab, buttonStart: Qt.Key_Return
    })
}

CharacterController {
    character: hero
    axisX: controller.axisX
    axisY: controller.axisY
    sprinting: controller.buttonL1Pressed
}
```

- **Keyboard**: `selectKeyboard()` takes either the six keys it always took
  (up, down, left, right, then two buttons - the fifth key presses B and the
  sixth A, as it always has) or one map from input name to key, as above. A
  map may name inputs the layout lacks; they are ignored until the layout has
  them.
- **Touchscreen**: with `nes` a stick appears wherever the area is touched,
  and B and A sit in the lower right. With `full` the left half is the left
  stick and the right half the right stick, A/B/X/Y sit in the lower right as
  a diamond (A at the bottom), L1/L2 in the upper left, R1/R2 in the upper
  right, select and start at the bottom centre. A stick reads the finger's
  offset from where it touched down over the stick's radius, so it reaches 1
  half a stick's width away; a trigger reads 1 while touched. Sticks and pads
  each follow their own finger.
- **Dojo**: the inspector's `input` action takes every input name in its
  `gamepad` object, e.g.
  `{"action": "input", "gamepad": {"axisRightX": 1, "buttonL1": true}}`; a
  `nes` controller reads only its stick and A/B of it.
- Changing `layout` at run time sets the inputs it drops to neutral, and the
  keyboard and dojo sources set the ones it adds from what they hold.

## Core Components

- **GameController** - Main unified input component with axis and button states
- **GameControllerDV** - Debug visualization showing every input of the layout live, with the layout and the active source
- **InputAction** - One action read as a tap, a hold or a buffered press, timed on the game clock
- **KeyboardGamepad** - Internal keyboard-to-controller mapping
- **TouchscreenGamepad** - Virtual on-screen gamepad for touch devices
- **GamepadWrapper** - Qt Gamepad API wrapper (currently disabled in Qt6)

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

### Tap, Hold and Buffered Press

A `GameController` says whether a button is down. An `InputAction` says how it
is used: a tap or a hold, how long it has been held, how long ago it was
pressed or released, and whether a press made a moment too early can still be
claimed. Its clock is the physics world when one is given, so the dojo's pause,
a single step and a hit stop in `ClayWorld2d`'s `"physics"` mode hold every
reading - the same clock a `PhysicsTimer` counts. A `"view"` mode hit stop
keeps the physics stepping, and the clock with it. Without a world it runs on
wall clock.

```qml
import QtQuick
import Clayground.GameController
import Clayground.Physics
import Clayground.World

ClayWorld2d {
    id: theWorld
    components: new Map()

    Item {
        anchors.fill: parent
        focus: true
        // Actions first: they leave key events unaccepted for the controller.
        Keys.forwardTo: [swing, controller]

        GameController { id: controller }

        InputAction {
            id: swing
            world: theWorld.physics
            key: Qt.Key_J
            mouseButton: Qt.LeftButton
            holdThresholdMs: 200     // shorter is a tap, longer a hold
            bufferMs: 150            // a press stays claimable this long
            onPressedChanged: if (pressed) trySwing()
            onHoldStarted: player.startCharging()
            onReleased: (heldMs) => { if (heldMs >= 600) player.heavySwing() }
        }

        InputAction {
            id: block
            world: theWorld.physics
            mouseButton: Qt.RightButton
        }

        // The game's MouseArea keeps aiming; it hands its buttons on.
        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            onPressed: (mouse) => { swing.press(mouse); block.press(mouse) }
            onReleased: (mouse) => { swing.release(mouse); block.release(mouse) }
            onCanceled: { swing.release(); block.release() }
        }
    }

    // A blow lands: a shield raised in the last 133 ms is a perfect block.
    function onBlow() {
        if (block.pressed && block.pressedAgoMs <= 133) player.perfectBlock()
        else if (block.pressed) player.block()
    }

    // A swing pressed during the cooldown comes out when it ends, if it is
    // at most bufferMs old by then.
    function trySwing() {
        if (cooldown.running || !swing.consume()) return
        player.swing()
        cooldown.start()
    }
    PhysicsTimer {
        id: cooldown
        world: theWorld.physics
        interval: 300
        onTriggered: trySwing()
    }
}
```

- `pressed`, `heldMs`, `pressedAgoMs`, `releasedAgoMs` are properties; the last
  two are `Infinity` before the first press or release.
- `tapped()` follows `released(heldMs)` on a release before the threshold;
  `holdStarted()` comes once per press, on the step that reaches it.
- `consume()` returns true once per press, while the press is at most
  `bufferMs` old - also for several presses made while the clock stands.
- `press()` / `release()` without an event press the action from anything
  else - a touch button, a script.
- A key press counts as released (with no tap) when the focus item changes or
  the window becomes inactive, as the keyboard gamepad does.

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
- **Two layouts**: `nes`, a stick and two buttons, and `full`, the inputs of a modern gamepad

Note: Physical gamepad support is currently disabled due to Qt6 compatibility issues but the architecture supports it for future versions.

## API Reference

{% include api/gamecontroller.html %}
