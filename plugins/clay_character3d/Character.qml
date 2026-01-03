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

/*!
    \qmltype Character
    \inqmlmodule Clayground.Character3D
    \inherits BodyPartsGroup
    \brief A fully animated 3D humanoid character with modular body parts.

    Character is the main component for creating 3D characters with procedural
    animations. It provides extensive customization through body part dimensions,
    colors, and automatic walk/run/idle animations.

    The character's origin is at ground level (Y=0 at bottom of feet), centered
    horizontally. Movement speeds are derived from animation geometry to ensure
    foot movement matches character movement.

    Example usage:
    \qml
    import Clayground.Character3D

    Character {
        name: "hero"
        activity: Character.Activity.Walking
        skinColor: "#d38d5f"
        torsoColor: "#4169e1"
    }
    \endqml

    \sa BodyPartsGroup, ParametricCharacter
*/
BodyPartsGroup {
    id: _character

    // Character origin is at ground level, center of body
    // Y=0 is at the bottom of the feet

    /*!
        \qmlproperty string Character::name
        \brief Character identifier name.
    */
    property string name: "unknown"

    /*!
        \qmlproperty real Character::walkSpeed
        \brief Walking speed derived from animation geometry.
    */
    readonly property real walkSpeed: _walkAnim.derivedWalkSpeed

    /*!
        \qmlproperty real Character::runSpeed
        \brief Running speed derived from animation geometry.
    */
    readonly property real runSpeed: _runAnim.derivedRunSpeed

    /*!
        \qmlproperty int Character::idleCycleDuration
        \brief Duration of the idle animation cycle in milliseconds.
    */
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
        Running,
        Using,
        Fighting
    }
    /*! Current activity state. Use Character.Activity enum: Idle, Walking, Running, Using, Fighting. */
    property int activity: Character.Activity.Idle

    /*! Current movement speed based on activity. */
    readonly property real currentSpeed: {
        if (activity === Character.Activity.Running) return _runAnim.derivedRunSpeed;
        if (activity === Character.Activity.Walking) return _walkAnim.derivedWalkSpeed;
        return 0;
    }
    /*! Current facial expression activity. */
    property alias faceActivity: _head.activity

    // ============================================================================
    // HEAD PROPERTIES
    // ============================================================================
    /*! Height of the neck section. */
    property real neckHeight: 0.333
    /*! Total head height (upper + lower). */
    readonly property real headHeight: upperHeadHeight + lowerHeadHeight

    /*! Width of the upper head. */
    property alias upperHeadWidth: _head.upperHeadWidth
    /*! Height of the upper head. */
    property alias upperHeadHeight: _head.upperHeadHeight
    /*! Depth of the upper head. */
    property alias upperHeadDepth: _head.upperHeadDepth
    /*! Width of the lower head/jaw. */
    property alias lowerHeadWidth: _head.lowerHeadWidth
    /*! Height of the lower head/jaw. */
    property alias lowerHeadHeight: _head.lowerHeadHeight
    /*! Depth of the lower head/jaw. */
    property alias lowerHeadDepth: _head.lowerHeadDepth
    /*! How pointed the chin is (0-1). */
    property alias chinPointiness: _head.chinPointiness

    /*! Eye size multiplier. */
    property alias eyeSize: _head.eyeSize
    /*! Nose size multiplier. */
    property alias noseSize: _head.noseSize
    /*! Mouth size multiplier. */
    property alias mouthSize: _head.mouthSize
    /*! Hair volume multiplier. */
    property alias hairVolume: _head.hairVolume

    /*! Skin color for head, hands, and feet. */
    property alias skinColor: _head.skinColor
    /*! Hair color. */
    property alias hairColor: _head.hairColor
    /*! Eye color. */
    property alias eyeColor: _head.eyeColor

    // ============================================================================
    // TORSO PROPERTIES
    // ============================================================================
    /*! Width at the shoulders. */
    property alias shoulderWidth: _torso.width
    /*! Height of the torso. */
    property alias torsoHeight: _torso.height
    /*! Depth of the torso. */
    property alias torsoDepth: _torso.depth
    /*! Width at the waist. */
    property alias waistWidth: _torso.waistWidth

    /*! Torso/shirt color. */
    property alias torsoColor: _torso.color

    // ============================================================================
    // HIP PROPERTIES
    // ============================================================================
    /*! Width of the hips. */
    property alias hipWidth: _hip.width
    /*! Height of the hip section. */
    property alias hipHeight: _hip.height
    /*! Depth of the hip section. */
    property alias hipDepth: _hip.depth

    /*! Hip/pants color. */
    property alias hipColor: _hip.color

    // ============================================================================
    // ARM PROPERTIES (symmetric - right arm drives both)
    // ============================================================================
    /*! Width of the arms. */
    property alias armWidth: _rightArm.width
    /*! Total arm length. */
    property alias armHeight: _rightArm.height
    /*! Depth of the arms. */
    property alias armDepth: _rightArm.depth

    /*! Upper arm proportion of total arm. */
    property alias armUpperRatio: _rightArm.upperRatio
    /*! How much the forearm tapers. */
    property alias armLowerTaper: _rightArm.lowerTaper

    /*! Width of the hands. */
    property alias handWidth: _rightArm.handWidth
    /*! Height of the hands. */
    property alias handHeight: _rightArm.handHeight
    /*! Depth of the hands. */
    property alias handDepth: _rightArm.handDepth

    /*! Arm/sleeve color. */
    property alias armColor: _rightArm.color
    /*! Hand color. */
    property alias handColor: _rightArm.handColor

    // ============================================================================
    // LEG PROPERTIES (symmetric)
    // ============================================================================
    /*! Width of the legs. */
    property alias legWidth: _rightLeg.width
    /*! Total leg length. */
    property alias legHeight: _rightLeg.height
    /*! Depth of the legs. */
    property alias legDepth: _rightLeg.depth

    /*! Upper leg proportion of total leg. */
    property alias legUpperRatio: _rightLeg.upperRatio
    /*! How much the lower leg tapers. */
    property alias legLowerTaper: _rightLeg.lowerTaper

    /*! Width of the feet. */
    property alias footWidth: _rightLeg.footWidth
    /*! Height of the feet. */
    property alias footHeight: _rightLeg.footHeight
    /*! Depth of the feet. */
    property alias footDepth: _rightLeg.footDepth

    /*! Leg/pants color. */
    property alias legColor: _rightLeg.color
    /*! Foot/shoe color. */
    property alias footColor: _rightLeg.footColor

    // ============================================================================
    // BODY PART REFERENCES (for animating them)
    // ============================================================================
    /*! Reference to the left arm for animation. */
    readonly property Arm leftArm: _leftArm
    /*! Reference to the right arm for animation. */
    readonly property Arm rightArm: _rightArm
    /*! Reference to the left leg for animation. */
    readonly property Leg leftLeg: _leftLeg
    /*! Reference to the right leg for animation. */
    readonly property Leg rightLeg: _rightLeg
    /*! Reference to the head for animation. */
    readonly property Head head: _head
    /*! Reference to the torso. */
    readonly property BodyPart torso: _torso
    /*! Reference to the hip. */
    readonly property BodyPart hip: _hip

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

    UseAnim {
        id: _useAnim
        entity: _character
        running: _character.activity === Character.Activity.Using
        loops: Animation.Infinite
    }

    FightAnim {
        id: _fightAnim
        entity: _character
        running: _character.activity === Character.Activity.Fighting
        loops: Animation.Infinite
    }

}
