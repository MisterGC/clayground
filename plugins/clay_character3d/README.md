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

## Analysis and Next Steps

### Current State Analysis

The Character3D plugin provides a foundation for box-based humanoid characters with:
- **Box3D body parts** with face scaling capabilities
- **Basic animations** (walk, idle) with realistic motion
- **Simple facial expressions** (5 moods)
- **Extensive property exposure** for dimensions and colors

However, the system lacks the expressiveness needed for iconic, comic-inspired characters.

### Key Limitations for Iconic Characters

1. **Limited Actions**: Only walk and idle - missing run, jump, crouch
2. **No Personality Variations**: All characters move identically
3. **Basic Expressions**: Simple face changes without eye movement
4. **Missing Classic Poses**: No victory pose, damage reaction, or item interactions

### Vision: NES/SNES-Inspired Simplicity

Our goal is to create instantly recognizable characters through clear, minimal animations inspired by classic games, where personality comes from subtle timing and proportion differences:

```qml
// Example of future API
Character {
    moveStyle: "heavy"     // Subtle timing variations
    jumpHeight: 1.2        // Character-specific abilities
    
    // Like Mario vs Luigi in SMB2:
    // - Heavy: slightly slower acceleration
    // - Light: higher jump, more air control
    // - Standard: balanced movement
}
```

### Proposed Enhancements for Iconic Recognition

#### 1. Essential Action States
Add the fundamental actions from classic games:
- **Run**: Faster walk with slight forward lean (3 frame cycle)
- **Jump**: Simple up/down with minimal air pose
- **Crouch**: Lower stance for ducking
- **Climb**: Hand-over-hand ladder movement
- **Victory**: Arms up celebration pose

```qml
Character {
    activity: Character.ActivityRunning
    
    // Simple changes from walk:
    // - 1.5x animation speed
    // - 5° forward torso lean
    // - Slightly longer stride
    // No flailing or exaggeration
}
```

#### 2. Character Differentiation
Subtle personality through movement properties:
- **Move Styles**: standard, heavy, light, quick
- **Jump Properties**: height, air control, landing lag
- **Walk Rhythm**: even steps vs slight bounce
- **Idle Behavior**: frequency of looking around

```qml
// Like classic game characters
Character {
    moveStyle: "heavy"      // Like DK or Bowser
    jumpHeight: 0.8         // Lower jump
    landingLag: 200         // ms before can move
    
    // Affects all animations subtly:
    // - Walk has more weight shift
    // - Jump has harder landing
    // - Turn is slightly slower
}
```

#### 3. Action System
Simple, recognizable actions for combat and activities:

**Combat Actions** (2-3 frame sequences):
- **Punch**: Arm extend, hold, return
- **Kick**: Leg out, hold, return  
- **Block**: Arms up defensive stance
- **Dodge**: Quick lean back/side

**Work Activities** (looping animations):
- **Hammer**: Raise arm, swing down, repeat
- **Dig**: Shovel motion with torso rotation
- **Carry**: Arms forward, slight forward lean
- **Push/Pull**: Leaning stance with arm cycles

```qml
Character {
    // Combat action
    action: Character.ActionPunch
    actionSide: "right"     // Which arm/leg
    actionSpeed: 0.2        // Seconds per action
    
    // Work activity  
    activity: Character.ActivityHammering
    toolInHand: "hammer"    // Visual prop
    
    // Both use same simple approach:
    // - Clear key poses
    // - Minimal in-between frames
    // - No complex physics
}
```

#### 4. Iconic Pose System
Clear, readable positions for game states:
- **Victory**: Classic arms-raised pose
- **Defeat**: Slumped shoulders, head down
- **Ready**: Combat stance or tool-ready position
- **Interact**: Reaching forward to grab/use
- **Damage**: Brief knockback pose

```qml
Character {
    // Static poses for game moments
    pose: Character.PoseVictory
    
    // Or activity-specific ready poses
    readyPose: "boxing"  // Fists up guard position
}
```

#### 5. Simple Face States
Limited but effective expressions:
- **Eyes**: Open, closed, looking left/right
- **Mouth**: Neutral, smile, frown, open
- **Combinations**: Happy (smile + open eyes), hurt (frown + closed eyes)

```qml
Character {
    // Simple face states like classic sprites
    faceState: "determined"  // Furrowed brow + firm mouth
    
    // Or individual controls
    eyeState: "looking-up"
    mouthState: "open"  // For surprise or yelling
}
```

#### 6. Movement Modifiers
Small adjustments that add character:
- **Run Lean**: 0-10° forward tilt
- **Jump Crouch**: How much to compress before jumping
- **Turn Speed**: How quickly character faces new direction
- **Arm Swing**: Range of arm movement while walking

```qml
Character {
    // Subtle modifiers
    runLean: 5          // degrees
    jumpCrouch: 0.9     // 90% of normal height
    armSwingRange: 25   // degrees
    
    // Creates personality without exaggeration
}
```

### Implementation Roadmap

#### Phase 1: Core Actions
1. Add run animation (faster walk with slight lean)
2. Implement jump/land states with simple poses
3. Add basic combat actions (punch, kick, block)

#### Phase 2: Combat System
1. Create action system for attacks (2-3 frame sequences)
2. Add combat stances and ready poses
3. Implement dodge/evade movements
4. Add hit reactions and damage poses

#### Phase 3: Work Activities
1. Implement looping work animations (hammer, dig, carry)
2. Add tool/prop attachment system
3. Create activity-specific stances
4. Add push/pull mechanics

#### Phase 4: Movement Styles
1. Add moveStyle property affecting all animations
2. Implement combat styles (boxing, martial arts, brawler)
3. Add character archetypes (warrior, worker, rogue)

#### Phase 5: Polish & RPG Integration
1. Add combo system for chaining actions
2. Create skill/special move animations
3. Implement item use animations (potion, magic)
4. Add interaction animations (chest open, door push)

### Example: Creating Classic Characters (Future API)

```qml
// Street Fighter-style Boxer
Character {
    moveStyle: "standard"
    readyPose: "boxing"
    
    // Athletic proportions
    torsoWidth: 40
    leftArmUpperArmWidth: 14
    
    // Throwing a punch
    action: Character.ActionPunch
    actionSide: "right"
    actionSpeed: 0.15  // Quick jab
}

// Construction Worker
Character {
    activity: Character.ActivityHammering
    toolInHand: "hammer"
    
    // Work clothes colors
    torsoColor: "#ff8c00"      // Safety orange
    headAccessory: "hardhat"
    
    // Sturdy build
    moveStyle: "heavy"
}

// Martial Artist
Character {
    moveStyle: "quick"
    
    // Multiple combat moves
    action: Character.ActionKick
    actionSide: "right"
    actionHeight: "high"  // Head-level kick
    
    // Fighting stance when idle
    idleStance: "martial-arts"
}

// Gardener
Character {
    activity: Character.ActivityDigging  
    toolInHand: "shovel"
    
    // Casual work pace
    activitySpeed: 0.5  // Relaxed digging
    
    // Gardening attire
    torsoColor: "#228b22"  // Green shirt
    headAccessory: "sun-hat"
}

// Mario-style Hero (Platforming)
Character {
    moveStyle: "standard"
    jumpHeight: 1.0
    
    // Currently jumping
    activity: Character.ActivityJumping
    // Simple air pose - arms out
}

// Multi-Activity Character
Character {
    // Can switch between different activities
    activities: {
        primary: Character.ActivityWalking,
        onInteract: Character.ActivityHammering,
        onCombat: Character.ActionPunch
    }
    
    // Context-aware animations
    contextAnimation: true
}
```

### Design Principles

1. **Clarity First**: Every pose must read instantly as a silhouette
2. **Subtle Differences**: Personality through small timing/proportion changes  
3. **Classic Actions**: Focus on timeless game movements
4. **Minimal Frames**: Each animation uses few, clear positions
5. **Game Feel**: Responsive controls over elaborate animations

### Technical Approach

Using only Box3D components, we achieve classic game feel through:
- **Simple rotations** for lean and direction
- **Position-based states** for jump, crouch, climb
- **Timing variations** for personality
- **Clear silhouettes** for instant recognition
- **Minimal deformation** (only slight crouch for jumps)

### Backwards Compatibility

All enhancements will be additive:
- Existing Character API remains unchanged
- Default moveStyle is "standard" (current behavior)
- New actions are opt-in through activity property

## Future Enhancements

This plugin is under active development. Planned features include:
- Additional animation states (running, jumping, crouching)
- Facial animation system with blend shapes
- Clothing and accessory system
- IK (Inverse Kinematics) for foot placement
- Animation blending and layering
- Character customization UI components