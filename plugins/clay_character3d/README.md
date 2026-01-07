# Character3D Plugin

The Character3D plugin provides a framework for creating animated 3D characters
in Clayground applications. It features a modular body part system, procedural
animation capabilities, and integrates with the Canvas3D toon shading system
for stylized cartoon characters.

## Getting Started

To use Character3D components, import the module in your QML file:

```qml
import Clayground.Character3D
```

## Core Components

- **Character** - Base component managing body parts and animations with extensive dimension properties
- **ParametricCharacter** - High-level parameters (bodyHeight, realism, maturity, femininity, mass) that auto-calculate dimensions
- **RatioBasedCharacter** - Dimension ratios for fine-tuned proportion control
- **CharacterEditor** - Visual editor overlay for character customization with persistence
- **ThoughtBubble** - Simple text bubble for speech/thought display

## Usage Examples

### Basic Character

```qml
import QtQuick
import QtQuick3D
import Clayground.Canvas3D
import Clayground.Character3D

View3D {
    anchors.fill: parent

    PerspectiveCamera {
        position: Qt.vector3d(0, 200, 400)
        eulerRotation.x: -20
    }

    DirectionalLight {
        eulerRotation.x: -35
        castsShadow: true
        shadowFactor: 78
        shadowMapQuality: Light.ShadowMapQualityVeryHigh
    }

    Character {
        y: 0
        activity: Character.Activity.Idle
    }
}
```

### Parametric Character Creation

```qml
ParametricCharacter {
    name: "hero"
    bodyHeight: 10.0

    // Body shape
    realism: 0.3       // Cartoon-like
    maturity: 0.7      // Adult
    femininity: 0.3    // Masculine
    mass: 0.5          // Average
    muscle: 0.7        // Athletic

    // Face
    faceShape: 0.5
    eyes: 1.2
    hair: 0.8

    // Colors
    skin: "#d38d5f"
    hairTone: "#734120"
    topClothing: "#4169e1"
    bottomClothing: "#708090"
}
```

### Character with Movement

```qml
ParametricCharacter {
    id: player
    name: "player"

    // Activity controls animation
    activity: isMoving ? Character.Activity.Running : Character.Activity.Idle

    // Movement derived from animation geometry
    property bool isMoving: controller.axisX !== 0 || controller.axisY !== 0

    // Move based on currentSpeed (auto-calculated from animation)
    x: x + controller.axisX * currentSpeed * dt
    z: z - controller.axisY * currentSpeed * dt
}
```

### Character Editor Integration

```qml
import Clayground.Character3D
import Clayground.GameController

Item {
    View3D {
        id: view3d
        anchors.fill: parent

        ParametricCharacter {
            id: character1
            name: "char1"
        }

        ParametricCharacter {
            id: character2
            name: "char2"
            x: 20
        }
    }

    GameController {
        id: gameController
        Component.onCompleted: selectKeyboard(
            Qt.Key_W, Qt.Key_S, Qt.Key_A, Qt.Key_D,
            Qt.Key_Shift, Qt.Key_Space
        )
    }

    CharacterEditor {
        anchors.fill: parent
        characters: [character1, character2]
        view3d: view3d
        gameController: gameController
        enabled: true
    }
}
```

### Facial Expressions

```qml
Character {
    id: character

    // Set facial expression
    faceActivity: Head.Activity.ShowJoy

    // Animate expressions
    SequentialAnimation on faceActivity {
        loops: Animation.Infinite
        PropertyAnimation { to: Head.Activity.ShowJoy; duration: 2000 }
        PropertyAnimation { to: Head.Activity.Idle; duration: 1000 }
        PropertyAnimation { to: Head.Activity.Talk; duration: 2000 }
        PropertyAnimation { to: Head.Activity.Idle; duration: 1000 }
    }
}
```

## Best Practices

1. **Use ParametricCharacter** for quick character creation with intuitive parameters.

2. **Activity-Based Animation**: Set the `activity` property to control animations - speeds are auto-derived from geometry.

3. **Toon Shading**: Use the Canvas3D DirectionalLight setup for consistent cartoon rendering.

4. **Character Editor**: Add CharacterEditor during development for visual tuning, remove for production.

5. **Proportions**: Adjust `realism` (0-1) to shift between cartoon and realistic body ratios.

## Technical Implementation

The Character3D plugin implements:

- **Modular Body Parts**: Head, torso, arms, legs with independent dimensions
- **Procedural Animation**: Walk, run, idle animations derived from body geometry
- **Animation-Speed Coupling**: Movement speeds calculated from leg swing geometry
- **Facial Expressions**: Multiple expression states (idle, joy, anger, sadness, talk)
- **Editor Integration**: 3D picking, parameter sliders, and per-character persistence
- **Coordinate System**: Origin at ground level (Y=0 at feet), character faces -Z when rotation is (0,0,0)

The animation system uses frame-based updates with biomechanically-inspired joint rotations and parent-child transform hierarchies.
