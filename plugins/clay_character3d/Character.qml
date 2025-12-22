// (c) Clayground Contributors - MIT License, see "LICENSE" file

// Import Strategy:
// - Subdirectories use relative imports (e.g., 'import ".."' to access root)
// - This enables hot-reloading in sandbox development
// - Example files use module imports to demonstrate proper usage
// - Internal components use relative imports for cross-directory access

import QtQuick
import Clayground.Canvas3D
import "bodyparts"
import "animation"

pragma ComponentBehavior: Bound

BodyPartsGroup {
    id: _character

    // Character origin is at ground level, center of body
    // Y=0 is at the bottom of the feet

    property string name: "unknown"

    // Movement properties - speeds derived from animation geometry
    // This ensures feet movement exactly matches character movement
    readonly property real walkSpeed: _walkAnim.derivedWalkSpeed
    readonly property real runSpeed: _runAnim.derivedRunSpeed

    // Idle animation configuration
    property alias idleCycleDuration: _idleAnim.duration

    // Bounding box dimensions (derived from body parts)
    width: Math.max(shoulderWidth, waistWidth, hipWidth)
    height: footHeight + legHeight + hipHeight + torsoHeight + neckHeight + headHeight
    depth: Math.max(torsoDepth, hipDepth)

    // ============================================================================
    // ACTIVITY & BEHAVIOR PROPERTIES
    // ============================================================================
    enum Activity {
        Idle,
        Walking,
        Running
    }
    property int activity: Character.Activity.Idle

    // Current movement speed based on activity (derived from animation)
    readonly property real currentSpeed: {
        if (activity === Character.Activity.Running) return _runAnim.derivedRunSpeed;
        if (activity === Character.Activity.Walking) return _walkAnim.derivedWalkSpeed;
        return 0;
    }
    property alias faceActivity: _head.activity

    // ============================================================================
    // HEAD PROPERTIES
    // ============================================================================
    // Absolute dimensions
    property real neckHeight: 0.333
    readonly property real headHeight: upperHeadHeight + lowerHeadHeight

    // Dimension aliases
    property alias upperHeadWidth: _head.upperHeadWidth
    property alias upperHeadHeight: _head.upperHeadHeight
    property alias upperHeadDepth: _head.upperHeadDepth
    property alias lowerHeadWidth: _head.lowerHeadWidth
    property alias lowerHeadHeight: _head.lowerHeadHeight
    property alias lowerHeadDepth: _head.lowerHeadDepth
    property alias chinPointiness: _head.chinPointiness

    // Feature size multipliers
    property alias eyeSize: _head.eyeSize
    property alias noseSize: _head.noseSize
    property alias mouthSize: _head.mouthSize
    property alias hairVolume: _head.hairVolume

    // Colors
    property alias skinColor: _head.skinColor
    property alias hairColor: _head.hairColor
    property alias eyeColor: _head.eyeColor

    // ============================================================================
    // TORSO PROPERTIES
    // ============================================================================
    // Dimension aliases
    property alias shoulderWidth: _torso.width
    property alias torsoHeight: _torso.height
    property alias torsoDepth: _torso.depth
    property alias waistWidth: _torso.waistWidth

    // Colors
    property alias torsoColor: _torso.color

    // ============================================================================
    // HIP PROPERTIES
    // ============================================================================
    // Dimension aliases
    property alias hipWidth: _hip.width
    property alias hipHeight: _hip.height
    property alias hipDepth: _hip.depth

    // Colors
    property alias hipColor: _hip.color

    // ============================================================================
    // ARM PROPERTIES (symmetric - right arm drives both)
    // ============================================================================
    // Dimension aliases
    property alias armWidth: _rightArm.width
    property alias armHeight: _rightArm.height
    property alias armDepth: _rightArm.depth

    // Proportion controls
    property alias armUpperRatio: _rightArm.upperRatio
    property alias armLowerTaper: _rightArm.lowerTaper

    // Hand dimension aliases (accessed through arm)
    property alias handWidth: _rightArm.handWidth
    property alias handHeight: _rightArm.handHeight
    property alias handDepth: _rightArm.handDepth

    // Colors
    property alias armColor: _rightArm.color
    property alias handColor: _rightArm.handColor

    // ============================================================================
    // LEG PROPERTIES (symmetric)
    // ============================================================================
    // Dimension aliases
    property alias legWidth: _rightLeg.width
    property alias legHeight: _rightLeg.height
    property alias legDepth: _rightLeg.depth

    // Proportion controls
    property alias legUpperRatio: _rightLeg.upperRatio
    property alias legLowerTaper: _rightLeg.lowerTaper

    // Foot dimension aliases (accessed through leg)
    property alias footWidth: _rightLeg.footWidth
    property alias footHeight: _rightLeg.footHeight
    property alias footDepth: _rightLeg.footDepth

    // Colors
    property alias legColor: _rightLeg.color
    property alias footColor: _rightLeg.footColor

    // ============================================================================
    // BODY PART REFERENCES (for animating them)
    // ============================================================================
    // and their base (relative) positions
    readonly property Arm leftArm: _leftArm
    readonly property Arm rightArm: _rightArm
    readonly property Leg leftLeg: _leftLeg
    readonly property Leg rightLeg: _rightLeg
    readonly property Head head: _head
    readonly property BodyPart torso: _torso

    BodyPart {
        id: _torso

        width: 3.5
        height: 2.5
        depth: 1.25
        property real waistWidth: 3.0

        scaledFace: Box3DGeometry.BottomFace
        faceScale: Qt.vector2d(waistWidth/width, 1.0)
        // Position torso above legs, feet, and hip
        basePos: Qt.vector3d(0, _character.legHeight + _character.footHeight + _hip.height, 0)

        Head {
            id: _head
            basePos:  Qt.vector3d(0, (_torso.height + _character.neckHeight), 0)
        }

        // Arms (containing hands)
        // Position at shoulder level (top of torso), arms extend downward
        Arm {
            id: _rightArm
            basePos: Qt.vector3d(_character.shoulderWidth * 0.5, _torso.height, 0)
        }

        Arm {
            id: _leftArm
            basePos: Qt.vector3d(-_character.shoulderWidth * 0.5, _torso.height, 0)

            // Mirror right arm dimensions
            width: _rightArm.width
            height: _rightArm.height
            depth: _rightArm.depth

            // Mirror proportion controls
            upperRatio: _rightArm.upperRatio
            lowerTaper: _rightArm.lowerTaper

            // Mirror colors
            color: _rightArm.color
            handColor: _rightArm.handColor

            // Mirror hand dimensions
            handWidth: _rightArm.handWidth
            handHeight: _rightArm.handHeight
            handDepth: _rightArm.handDepth
        }

        // Hip (containing legs)
        BodyPart {
            id: _hip
            width: 3.0
            height: 1.167
            depth: 1.25
            color: "darkblue"

            scaledFace: Box3DGeometry.TopFace
            faceScale: Qt.vector2d(_torso.waistWidth/width, 1.0)
            basePos: Qt.vector3d(0, -_hip.height, 0)

            // Legs (containing feet)
            // Hip joint aligns with hip bottom (legs extend downward from there)
            Leg {
                id: _rightLeg
                basePos: Qt.vector3d(_hip.width * 0.4, 0, 0)
            }
            Leg {
                id: _leftLeg
                basePos: Qt.vector3d(-_hip.width * 0.4, 0, 0)

                // Mirror right leg dimensions
                width: _rightLeg.width
                height: _rightLeg.height
                depth: _rightLeg.depth

                // Mirror proportion controls
                upperRatio: _rightLeg.upperRatio
                lowerTaper: _rightLeg.lowerTaper

                // Mirror colors
                color: _rightLeg.color
                footColor: _rightLeg.footColor

                // Mirror foot dimensions
                footWidth: _rightLeg.footWidth
                footHeight: _rightLeg.footHeight
                footDepth: _rightLeg.footDepth
            }
        }
    }

    WalkAnim {
        id: _walkAnim
        entity: _character
        // Duration is calculated internally from leg geometry
        running: _character.activity === Character.Activity.Walking
        loops: Animation.Infinite
    }

    RunAnim {
        id: _runAnim
        entity: _character
        // Duration is calculated internally from leg geometry
        running: _character.activity === Character.Activity.Running
        loops: Animation.Infinite
    }

    IdleAnim {
        id: _idleAnim
        entity: _character
        duration: 200
        running: _character.activity == Character.Activity.Idle
        loops: 1
    }

}
