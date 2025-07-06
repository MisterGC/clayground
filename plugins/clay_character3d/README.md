# Character3D User Guide

## Overview

The Character3D plugin provides a comprehensive framework for creating animated 3D characters in Clayground applications. It features a modular body part system, procedural animation capabilities, and integrates seamlessly with the Canvas3D toon shading system to create stylized cartoon characters.

## Table of Contents

1. [Getting Started](#getting-started)
2. [Core Components](#core-components)
   - [Character](#character)
   - [Body Parts](#body-parts)
   - [Animation System](#animation-system)
   - [Character Control](#character-control)
3. [Animation Guide](#animation-guide)
4. [Body Part Customization](#body-part-customization)
5. [Character Controller](#character-controller)
6. [Camera System](#camera-system)
7. [Examples](#examples)
8. [Best Practices](#best-practices)

## Getting Started

To use Character3D components, import the module in your QML file:

```qml
import Clayground.Character3D
```

### Minimal Example

Here's a simple example showing a basic character with idle animation:

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
        activity: Character.ActivityIdle
        
        // Enable toon shading for cartoon look
        useToonShading: true
    }
}
```

## Core Components

### Character

The `Character` component is the main entry point for creating 3D characters. It manages all body parts and animations.

#### Properties

| Property | Type | Default | Description |
|----------|------|---------|-------------|
| activity | enum | ActivityIdle | Current activity (Idle, Walking) |
| walkSpeed | real | 100 | Walking speed in units per second |
| strideLength | real | 40 | Length of walking stride |
| turnSpeed | real | 200 | Rotation speed in degrees per second |
| faceMood | int | 0 | Face expression (0-4: normal, joy, anger, sadness, talk) |
| headPosition | vector3d | (0, torsoHeight, 0) | Head offset position |
| leftArmPosition | vector3d | calculated | Left arm position |
| rightArmPosition | vector3d | calculated | Right arm position |
| hipPosition | vector3d | (0, 0, 0) | Hip offset position |
| leftLegPosition | vector3d | calculated | Left leg position |
| rightLegPosition | vector3d | calculated | Right leg position |
| useToonShading | bool | false | Enable cartoon-style shading |

#### Activity States

- `Character.ActivityIdle` - Standing idle with subtle breathing animation
- `Character.ActivityWalking` - Walking with procedural leg and arm movement

### Body Parts

All body parts extend the `BodyPart` component, which itself extends Canvas3D's `Box3D`.

#### BodyPart Base Properties

| Property | Type | Default | Description |
|----------|------|---------|-------------|
| label | string | "" | Debug label for the body part |
| baseColor | color | parent.color | Main color of the body part |
| edgeColorFactor | real | 0.8 | Darkening factor for edges |
| useToonShading | bool | false | Enable cartoon-style shading |

#### Head

Creates a character head with face expressions.

```qml
Head {
    width: 32
    height: 32
    depth: 25
    color: "#ffe0bd"  // Skin color
    mood: Head.Joy    // Face expression
}
```

**Mood Options**: Normal, Joy, Anger, Sadness, Talk

#### Arm

Creates a complete arm with upper arm, lower arm, and hand.

```qml
Arm {
    upperArmLength: 25
    upperArmWidth: 12
    lowerArmLength: 22
    lowerArmWidth: 10
    handSize: Qt.vector3d(8, 8, 6)
    shoulderAngle: -45  // Rotation at shoulder
    elbowAngle: 30      // Rotation at elbow
}
```

#### Leg

Creates a complete leg with upper leg, lower leg, and foot.

```qml
Leg {
    upperLegLength: 28
    upperLegWidth: 14
    lowerLegLength: 25
    lowerLegWidth: 12
    footSize: Qt.vector3d(12, 6, 20)
    hipAngle: 0     // Rotation at hip
    kneeAngle: 0    // Rotation at knee
    ankleAngle: 0   // Rotation at ankle
}
```

### Animation System

The animation system is built on `ProceduralAnim` base class with specialized implementations.

#### WalkAnim

Procedurally generates walking animation based on walk speed and stride length.

```qml
WalkAnim {
    walkSpeed: 120      // Units per second
    strideLength: 45    // Length of each step
    
    onFrameUpdate: function(phase, stridePhase) {
        // phase: 0-1 for complete walk cycle
        // stridePhase: -1 to 1 for left/right stride
    }
}
```

**Technical Implementation**: The animation calculates realistic joint angles based on biomechanical principles, including:
- Hip flexion/extension
- Knee flexion during swing phase
- Ankle dorsiflexion/plantarflexion
- Synchronized arm swing

#### IdleAnim

Creates subtle idle movements including breathing and slight swaying.

```qml
IdleAnim {
    breathingDepth: 0.2    // Intensity of breathing
    swayAmount: 2.0        // Amount of body sway
}
```

### Character Controller

Handles input and movement for character control.

```qml
CharacterController {
    id: controller
    character: myCharacter
    camera: myCamera
    turnSpeed: 180  // Degrees per second
    
    // Connect to GameController input
    connections: Connections {
        target: gameController
        function onLeftStickChanged(x, y) {
            controller.move(x, -y)
        }
    }
}
```

## Animation Guide

### Walk Cycle

The walk animation automatically adjusts based on:
- **Walk Speed**: Faster walking increases animation speed
- **Stride Length**: Longer strides create more exaggerated movements
- **Phase Synchronization**: Arms and legs move in opposite pairs

### Transitioning Between Activities

```qml
Character {
    id: character
    
    // Smooth transition from idle to walking
    states: [
        State {
            name: "walking"
            PropertyChanges { target: character; activity: Character.ActivityWalking }
        },
        State {
            name: "idle"
            PropertyChanges { target: character; activity: Character.ActivityIdle }
        }
    ]
    
    transitions: Transition {
        NumberAnimation { properties: "activity"; duration: 200 }
    }
}
```

## Body Part Customization

### Color Schemes

Create custom character appearances by setting body part colors:

```qml
Character {
    // Skin tone
    property color skinColor: "#ffe0bd"
    // Hair color
    property color hairColor: "#4a3c28"
    // Clothing colors
    property color shirtColor: "#2196f3"
    property color pantsColor: "#1565c0"
    property color shoeColor: "#424242"
    
    // Apply colors to body parts
    headBaseColor: skinColor
    torsoColor: shirtColor
    leftArmBaseColor: skinColor
    rightArmBaseColor: skinColor
    // ... etc
}
```

### Proportions

Adjust body proportions for different character types:

```qml
// Child character
Character {
    torsoSize: Qt.vector3d(30, 35, 18)
    headWidth: 36
    headHeight: 36
    leftArmUpperArmLength: 18
    leftLegUpperLegLength: 20
}

// Adult character
Character {
    torsoSize: Qt.vector3d(36, 50, 22)
    headWidth: 32
    headHeight: 32
    leftArmUpperArmLength: 28
    leftLegUpperLegLength: 35
}
```

## Camera System

The `CharacterCamera` provides a third-person camera that follows the character.

```qml
CharacterCamera {
    observedCharacter: myCharacter
    distance: 400          // Distance from character
    pitchOffset: -20       // Vertical angle
    yawOffset: 0          // Horizontal angle
    height: 150           // Camera height above character
    
    // Enable smooth following
    Behavior on position {
        Vector3dAnimation { duration: 100 }
    }
}
```

## Examples

### Complete Character with WASD Controls

```qml
import QtQuick
import QtQuick3D
import Clayground.Common
import Clayground.GameController
import Clayground.Canvas3D
import Clayground.Character3D

View3D {
    id: root
    anchors.fill: parent
    
    environment: SceneEnvironment {
        clearColor: "#87CEEB"
        backgroundMode: SceneEnvironment.Color
    }
    
    // Toon-shaded lighting setup
    DirectionalLight {
        eulerRotation: Qt.vector3d(-35, -70, 0)
        castsShadow: true
        shadowFactor: 78
        shadowMapQuality: Light.ShadowMapQualityVeryHigh
        pcfFactor: 2
        shadowBias: 18
    }
    
    // Third-person camera
    CharacterCamera {
        id: camera
        observedCharacter: character
        distance: 500
        pitchOffset: -25
        height: 200
    }
    
    // Ground plane
    Box3D {
        y: -5
        width: 1000
        height: 10
        depth: 1000
        color: "#90EE90"
        useToonShading: true
        showEdges: false
    }
    
    // Main character
    Character {
        id: character
        y: 0
        useToonShading: true
        
        // Custom colors
        headBaseColor: "#ffe0bd"
        torsoColor: "#e74c3c"
        leftArmBaseColor: "#ffe0bd"
        rightArmBaseColor: "#ffe0bd"
        leftLegBaseColor: "#2c3e50"
        rightLegBaseColor: "#2c3e50"
    }
    
    // Character controller
    CharacterController {
        id: controller
        character: character
        camera: camera
    }
    
    // Input handling
    GameController {
        id: gameController
    }
    
    Connections {
        target: gameController
        function onLeftStickChanged(x, y) {
            controller.move(x, -y)
        }
    }
}
```

### Animated Character Showcase

```qml
Row {
    spacing: 150
    
    // Walking character
    Character {
        activity: Character.ActivityWalking
        walkSpeed: 80
        strideLength: 35
        useToonShading: true
        
        // Auto-rotate for showcase
        NumberAnimation on eulerRotation.y {
            from: 0; to: 360
            duration: 8000
            loops: Animation.Infinite
        }
    }
    
    // Idle character with changing expressions
    Character {
        activity: Character.ActivityIdle
        useToonShading: true
        
        SequentialAnimation on faceMood {
            loops: Animation.Infinite
            NumberAnimation { to: 1; duration: 2000 }  // Joy
            NumberAnimation { to: 0; duration: 1000 }  // Normal
            NumberAnimation { to: 4; duration: 2000 }  // Talk
            NumberAnimation { to: 0; duration: 1000 }  // Normal
        }
    }
}
```

## Best Practices

### Performance

- **Animation Updates**: Walk animation runs at 60 FPS by default; reduce for better performance on low-end devices
- **Toon Shading**: No significant performance impact when enabled
- **Multiple Characters**: Use LOD (Level of Detail) system for crowds (future feature)

### Visual Design

- **Consistent Lighting**: Use the same DirectionalLight settings for all toon-shaded objects
- **Edge Rendering**: Adjust `edgeColorFactor` on body parts for cartoon outline effect
- **Color Palettes**: Use limited color palettes for cohesive cartoon aesthetic

### Animation

- **Smooth Transitions**: Use State/Transition system for activity changes
- **Speed Matching**: Ensure walkSpeed and actual movement speed are synchronized
- **Realistic Proportions**: Match strideLength to leg length for natural movement

### Code Organization

- **Custom Characters**: Extend Character component for specialized character types
- **Animation States**: Create custom ProceduralAnim subclasses for new animations
- **Modular Design**: Override individual body parts for unique character features

## Technical Details

### Coordinate System

- **Origin**: Character's origin is at ground level, center of torso
- **Forward Direction**: Character faces -Z direction when rotation is (0,0,0)
- **Up Direction**: Y-axis points up

### Animation Architecture

The animation system uses:
- Frame-based updates with configurable intervals
- Phase calculations for cyclic animations
- Biomechanically-inspired joint rotations
- Parent-child transform hierarchies for body parts

### Integration Points

- **Physics**: Can be combined with clay_physics for collision detection
- **Networking**: Character state can be synchronized via clay_network
- **World Integration**: Works with SceneLoader3D for level-based games

## Future Enhancements

This plugin is under active development. Planned features include:
- Additional animation states (running, jumping, crouching)
- Facial animation system with blend shapes
- Clothing and accessory system
- IK (Inverse Kinematics) for foot placement
- Animation blending and layering
- Character customization UI components