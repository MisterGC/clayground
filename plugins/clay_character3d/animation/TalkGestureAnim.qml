// (c) Clayground Contributors - MIT License, see "LICENSE" file
//
// TalkGestureAnim - emotional body language while a character speaks.
// Two alternating phases sway/pump the upper body; amplitudes and pace
// derive from the emotion. Legs are untouched so the gesture can overlay
// a standing pose without affecting the character's footing.

import QtQuick
import QtQuick3D
import ".."

ProceduralAnim {
    id: _gesture

    // "happy", "sad" or "angry" - anything else means neutral chatter
    property string emotion: ""

    readonly property bool _happy: emotion === "happy"
    readonly property bool _sad: emotion === "sad"
    readonly property bool _angry: emotion === "angry"

    // Pace: sad drags, angry is agitated
    duration: _sad ? 1400 : _angry ? 400 : 650

    // Posture. The lean is shared over the waist joint the same way a gait's
    // is: the two segments add up to torsoLean, and the curve between them is
    // what makes a sad speaker read as slumped rather than tipped. The twist
    // is shared too - the chest turns further than the hips, which is what a
    // person talking with their hands actually does.
    readonly property real torsoLean: _sad ? 9 : _angry ? 5 : -2
    readonly property real spineCurve: _sad ? 13 : _angry ? 5 : _happy ? -7 : -3
    readonly property real bellyLean: torsoLean * 0.4 - spineCurve * 0.5
    readonly property real chestLean: torsoLean * 0.6 + spineCurve * 0.5
    readonly property real torsoTwist: _angry ? 5 : _happy ? 2 : 1
    readonly property real hipTwist: torsoTwist * 0.35
    readonly property real chestTwist: torsoTwist * 0.65
    readonly property real headTilt: _sad ? 15 : _angry ? 6 : -2
    readonly property real headSway: _happy ? 7 : _sad ? 2 : 0

    // Arm gesticulation
    readonly property real armLift: _angry ? 35 : _happy ? 14 : 4
    readonly property real armLiftRelax: _angry ? 15 : _happy ? 6 : 2
    readonly property real armOut: _happy ? 14 : 4
    readonly property real elbowBend: _angry ? 70 : _happy ? 30 : 12
    readonly property real elbowRelax: _angry ? 40 : _happy ? 18 : 8

    // Phase A
    ParallelAnimation {
        EulerAnim {
            target: entity.torso
            duration: _gesture.duration
            to: Qt.vector3d(0, hipTwist, 0)
        }
        EulerAnim {
            target: entity.belly
            duration: _gesture.duration
            to: Qt.vector3d(bellyLean, 0, 0)
        }
        EulerAnim {
            target: entity.chest
            duration: _gesture.duration
            to: Qt.vector3d(chestLean, chestTwist, 0)
        }
        HeadEulerAnim {
            target: entity.head
            duration: _gesture.duration
            to: Qt.vector3d(headTilt, 0, headSway)
        }
        EulerAnim {
            target: entity.rightArm.upperArm
            duration: _gesture.duration
            to: Qt.vector3d(-armLift, 0, armOut)
        }
        EulerAnim {
            target: entity.rightArm.lowerArm
            duration: _gesture.duration
            to: Qt.vector3d(-elbowBend, 0, 0)
        }
        EulerAnim {
            target: entity.leftArm.upperArm
            duration: _gesture.duration
            to: Qt.vector3d(-armLiftRelax, 0, -armOut)
        }
        EulerAnim {
            target: entity.leftArm.lowerArm
            duration: _gesture.duration
            to: Qt.vector3d(-elbowRelax, 0, 0)
        }
    }

    // Phase B: mirrored accents
    ParallelAnimation {
        EulerAnim {
            target: entity.torso
            duration: _gesture.duration
            to: Qt.vector3d(0, -hipTwist, 0)
        }
        EulerAnim {
            target: entity.belly
            duration: _gesture.duration
            to: Qt.vector3d(bellyLean, 0, 0)
        }
        EulerAnim {
            target: entity.chest
            duration: _gesture.duration
            to: Qt.vector3d(chestLean, -chestTwist, 0)
        }
        HeadEulerAnim {
            target: entity.head
            duration: _gesture.duration
            to: Qt.vector3d(headTilt, 0, -headSway)
        }
        EulerAnim {
            target: entity.rightArm.upperArm
            duration: _gesture.duration
            to: Qt.vector3d(-armLiftRelax, 0, armOut)
        }
        EulerAnim {
            target: entity.rightArm.lowerArm
            duration: _gesture.duration
            to: Qt.vector3d(-elbowRelax, 0, 0)
        }
        EulerAnim {
            target: entity.leftArm.upperArm
            duration: _gesture.duration
            to: Qt.vector3d(-armLift, 0, -armOut)
        }
        EulerAnim {
            target: entity.leftArm.lowerArm
            duration: _gesture.duration
            to: Qt.vector3d(-elbowBend, 0, 0)
        }
    }
}
