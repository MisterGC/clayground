// (c) Clayground Contributors - MIT License, see "LICENSE" file

/*!
    \qmltype Character
    \inqmlmodule Clayground.Character3D
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

    \qmlproperty string Character::name
    \brief Character identifier name.

    \qmlproperty int Character::activity
    \brief Current activity state. Use Character.Activity enum values:
    Idle, Walking, Running, Using, Fighting.

    \qmlproperty real Character::walkSpeed
    \readonly
    \brief Walking speed derived from animation geometry.

    \qmlproperty real Character::runSpeed
    \readonly
    \brief Running speed derived from animation geometry.

    \qmlproperty real Character::currentSpeed
    \readonly
    \brief Current movement speed based on activity.

    \qmlproperty int Character::idleCycleDuration
    \brief Duration of the idle animation cycle in milliseconds.

    \qmlproperty int Character::faceActivity
    \brief Current facial expression activity.

    \qmlproperty real Character::neckHeight
    \brief Height of the neck section.

    \qmlproperty real Character::upperHeadWidth
    \brief Width of the upper head.

    \qmlproperty real Character::upperHeadHeight
    \brief Height of the upper head.

    \qmlproperty real Character::upperHeadDepth
    \brief Depth of the upper head.

    \qmlproperty real Character::lowerHeadWidth
    \brief Width of the lower head/jaw.

    \qmlproperty real Character::lowerHeadHeight
    \brief Height of the lower head/jaw.

    \qmlproperty real Character::lowerHeadDepth
    \brief Depth of the lower head/jaw.

    \qmlproperty real Character::chinPointiness
    \brief How pointed the chin is (0-1).

    \qmlproperty real Character::eyeSize
    \brief Eye size multiplier.

    \qmlproperty real Character::noseSize
    \brief Nose size multiplier.

    \qmlproperty real Character::mouthSize
    \brief Mouth size multiplier.

    \qmlproperty real Character::hairVolume
    \brief Hair volume multiplier.

    \qmlproperty color Character::skinColor
    \brief Skin color for head, hands, and feet.

    \qmlproperty color Character::hairColor
    \brief Hair color.

    \qmlproperty color Character::eyeColor
    \brief Eye color.

    \qmlproperty real Character::shoulderWidth
    \brief Width at the shoulders.

    \qmlproperty real Character::torsoHeight
    \brief Height of the torso.

    \qmlproperty real Character::torsoDepth
    \brief Depth of the torso.

    \qmlproperty real Character::waistWidth
    \brief Width at the waist.

    \qmlproperty color Character::torsoColor
    \brief Torso/shirt color.

    \qmlproperty real Character::hipWidth
    \brief Width of the hips.

    \qmlproperty real Character::hipHeight
    \brief Height of the hip section.

    \qmlproperty real Character::hipDepth
    \brief Depth of the hip section.

    \qmlproperty color Character::hipColor
    \brief Hip/pants color.

    \qmlproperty real Character::armWidth
    \brief Width of the arms.

    \qmlproperty real Character::armHeight
    \brief Total arm length.

    \qmlproperty real Character::armDepth
    \brief Depth of the arms.

    \qmlproperty real Character::armUpperRatio
    \brief Upper arm proportion of total arm.

    \qmlproperty real Character::armLowerTaper
    \brief How much the forearm tapers.

    \qmlproperty real Character::handWidth
    \brief Width of the hands.

    \qmlproperty real Character::handHeight
    \brief Height of the hands.

    \qmlproperty real Character::handDepth
    \brief Depth of the hands.

    \qmlproperty color Character::armColor
    \brief Arm/sleeve color.

    \qmlproperty color Character::handColor
    \brief Hand color.

    \qmlproperty real Character::legWidth
    \brief Width of the legs.

    \qmlproperty real Character::legHeight
    \brief Total leg length.

    \qmlproperty real Character::legDepth
    \brief Depth of the legs.

    \qmlproperty real Character::legUpperRatio
    \brief Upper leg proportion of total leg.

    \qmlproperty real Character::legLowerTaper
    \brief How much the lower leg tapers.

    \qmlproperty real Character::footWidth
    \brief Width of the feet.

    \qmlproperty real Character::footHeight
    \brief Height of the feet.

    \qmlproperty real Character::footDepth
    \brief Depth of the feet.

    \qmlproperty color Character::legColor
    \brief Leg/pants color.

    \qmlproperty color Character::footColor
    \brief Foot/shoe color.

    \qmlproperty Arm Character::leftArm
    \readonly
    \brief Reference to the left arm for animation.

    \qmlproperty Arm Character::rightArm
    \readonly
    \brief Reference to the right arm for animation.

    \qmlproperty Leg Character::leftLeg
    \readonly
    \brief Reference to the left leg for animation.

    \qmlproperty Leg Character::rightLeg
    \readonly
    \brief Reference to the right leg for animation.

    \qmlproperty Head Character::head
    \readonly
    \brief Reference to the head for animation.

    \qmlproperty BodyPart Character::torso
    \readonly
    \brief Reference to the torso.

    \qmlproperty BodyPart Character::hip
    \readonly
    \brief Reference to the hip.
*/

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
        Running,
        Using,
        Fighting
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
