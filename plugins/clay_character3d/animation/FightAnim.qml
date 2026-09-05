// (c) Clayground Contributors - MIT License, see "LICENSE" file
// FightAnim.qml - Classic boxing stance with alternating punch/guard loop

import QtQuick
import QtQuick3D
import ".."

ProceduralAnim {
    id: _fightAnim

    // Configuration
    property real intensity: 0.5        // 0=relaxed, 1=aggressive

    // Guard stance angles - fists IN FRONT of face, not beside it
    readonly property real guardUpperArm: 50 + intensity * 10       // Arms forward (50-60 degrees)
    readonly property real guardElbow: 100 + intensity * 10         // Sharp elbow bend brings fists to face (100-110)
    readonly property real guardInward: 15 + intensity * 5          // Fists angled inward toward centerline

    // Attack angles - horizontal forward strike
    readonly property real punchUpperArm: 75 + intensity * 10       // Arm extends forward horizontally (75-85)
    readonly property real punchElbow: 15 + intensity * 10          // Nearly straight arm (15-25)

    // Torso rotation during punch. It is shared: the trunk group turns the
    // hips and the legs with it, the chest turns further on the waist joint.
    // A punch that came entirely from the group swung the feet round with the
    // shoulders; the shoulders arriving ahead of the hips is what a thrown
    // punch looks like, and it keeps the stance planted.
    readonly property real torsoTwist: 15 + intensity * 10          // 15-25 degrees
    readonly property real hipTwist: torsoTwist * 0.4
    readonly property real chestTwist: torsoTwist * 0.6

    // The guard is a rolled-forward chest over a level lower back: shoulders
    // up and in, chin behind them. On the chest alone, so the legs stay where
    // the stance put them.
    readonly property real guardChestLean: 8

    // Athletic stance - slight crouch
    readonly property real kneeBend: 10 + intensity * 5             // 10-15 degrees
    readonly property real hipDrop: 5                                // Slight hip counter for balance

    // Animation timing
    readonly property int punchDuration: 250 - intensity * 50       // 200-250ms per punch
    readonly property int guardDuration: 150                         // Brief guard between punches

    duration: punchDuration

    // Phase 1: Guard stance (both fists in front of face)
    ParallelAnimation {
        // Torso centered, chest rolled forward over the guard
        EulerAnim {
            target: entity.torso
            duration: guardDuration
            from: Qt.vector3d(0, -hipTwist, 0)
            to: Qt.vector3d(0, 0, 0)
        }
        EulerAnim {
            target: entity.chest
            duration: guardDuration
            from: Qt.vector3d(guardChestLean, -chestTwist, 0)
            to: Qt.vector3d(guardChestLean, 0, 0)
        }

        // Right arm in guard - fist in front of face
        EulerAnim {
            target: entity.rightArm.upperArm
            duration: guardDuration
            from: Qt.vector3d(-punchUpperArm, 0, 0)
            to: Qt.vector3d(-guardUpperArm, -guardInward, 0)
        }
        EulerAnim {
            target: entity.rightArm.lowerArm
            duration: guardDuration
            from: Qt.vector3d(-punchElbow, 0, 0)
            to: Qt.vector3d(-guardElbow, 0, 0)
        }
        EulerAnim {
            target: entity.rightArm.hand
            duration: guardDuration
            to: Qt.vector3d(0, 0, 0)
        }

        // Left arm in guard - fist in front of face
        EulerAnim {
            target: entity.leftArm.upperArm
            duration: guardDuration
            to: Qt.vector3d(-guardUpperArm, guardInward, 0)
        }
        EulerAnim {
            target: entity.leftArm.lowerArm
            duration: guardDuration
            to: Qt.vector3d(-guardElbow, 0, 0)
        }
        EulerAnim {
            target: entity.leftArm.hand
            duration: guardDuration
            to: Qt.vector3d(0, 0, 0)
        }

        // Athletic stance - slight knee bend
        EulerAnim {
            target: entity.rightLeg.upperLeg
            duration: guardDuration
            to: Qt.vector3d(-kneeBend, 0, 0)
        }
        EulerAnim {
            target: entity.rightLeg.lowerLeg
            duration: guardDuration
            to: Qt.vector3d(kneeBend * 2, 0, 0)
        }
        EulerAnim {
            target: entity.leftLeg.upperLeg
            duration: guardDuration
            to: Qt.vector3d(-kneeBend, 0, 0)
        }
        EulerAnim {
            target: entity.leftLeg.lowerLeg
            duration: guardDuration
            to: Qt.vector3d(kneeBend * 2, 0, 0)
        }
    }

    // Phase 2: Right punch - horizontal forward strike
    ParallelAnimation {
        // Torso rotates into punch - the chest leads, the hips follow
        EulerAnim {
            target: entity.torso
            duration: _fightAnim.duration
            from: Qt.vector3d(0, 0, 0)
            to: Qt.vector3d(0, hipTwist, 0)
        }
        EulerAnim {
            target: entity.chest
            duration: _fightAnim.duration
            from: Qt.vector3d(guardChestLean, 0, 0)
            to: Qt.vector3d(guardChestLean, chestTwist, 0)
        }

        // Right arm extends forward horizontally
        EulerAnim {
            target: entity.rightArm.upperArm
            duration: _fightAnim.duration
            from: Qt.vector3d(-guardUpperArm, -guardInward, 0)
            to: Qt.vector3d(-punchUpperArm, 0, 0)
        }
        EulerAnim {
            target: entity.rightArm.lowerArm
            duration: _fightAnim.duration
            from: Qt.vector3d(-guardElbow, 0, 0)
            to: Qt.vector3d(-punchElbow, 0, 0)
        }

        // Left arm stays in guard
        EulerAnim {
            target: entity.leftArm.upperArm
            duration: _fightAnim.duration
            to: Qt.vector3d(-guardUpperArm, guardInward, 0)
        }
        EulerAnim {
            target: entity.leftArm.lowerArm
            duration: _fightAnim.duration
            to: Qt.vector3d(-guardElbow, 0, 0)
        }

        // Legs maintain stance
        EulerAnim {
            target: entity.rightLeg.upperLeg
            duration: _fightAnim.duration
            to: Qt.vector3d(-kneeBend, 0, 0)
        }
        EulerAnim {
            target: entity.rightLeg.lowerLeg
            duration: _fightAnim.duration
            to: Qt.vector3d(kneeBend * 2, 0, 0)
        }
        EulerAnim {
            target: entity.leftLeg.upperLeg
            duration: _fightAnim.duration
            to: Qt.vector3d(-kneeBend, 0, 0)
        }
        EulerAnim {
            target: entity.leftLeg.lowerLeg
            duration: _fightAnim.duration
            to: Qt.vector3d(kneeBend * 2, 0, 0)
        }
    }

    // Phase 3: Return to guard
    ParallelAnimation {
        // Torso back to center
        EulerAnim {
            target: entity.torso
            duration: guardDuration
            from: Qt.vector3d(0, hipTwist, 0)
            to: Qt.vector3d(0, 0, 0)
        }
        EulerAnim {
            target: entity.chest
            duration: guardDuration
            from: Qt.vector3d(guardChestLean, chestTwist, 0)
            to: Qt.vector3d(guardChestLean, 0, 0)
        }

        // Right arm back to guard
        EulerAnim {
            target: entity.rightArm.upperArm
            duration: guardDuration
            from: Qt.vector3d(-punchUpperArm, 0, 0)
            to: Qt.vector3d(-guardUpperArm, -guardInward, 0)
        }
        EulerAnim {
            target: entity.rightArm.lowerArm
            duration: guardDuration
            from: Qt.vector3d(-punchElbow, 0, 0)
            to: Qt.vector3d(-guardElbow, 0, 0)
        }

        // Left arm stays in guard
        EulerAnim {
            target: entity.leftArm.upperArm
            duration: guardDuration
            to: Qt.vector3d(-guardUpperArm, guardInward, 0)
        }
        EulerAnim {
            target: entity.leftArm.lowerArm
            duration: guardDuration
            to: Qt.vector3d(-guardElbow, 0, 0)
        }

        // Legs maintain stance
        EulerAnim {
            target: entity.rightLeg.upperLeg
            duration: guardDuration
            to: Qt.vector3d(-kneeBend, 0, 0)
        }
        EulerAnim {
            target: entity.rightLeg.lowerLeg
            duration: guardDuration
            to: Qt.vector3d(kneeBend * 2, 0, 0)
        }
        EulerAnim {
            target: entity.leftLeg.upperLeg
            duration: guardDuration
            to: Qt.vector3d(-kneeBend, 0, 0)
        }
        EulerAnim {
            target: entity.leftLeg.lowerLeg
            duration: guardDuration
            to: Qt.vector3d(kneeBend * 2, 0, 0)
        }
    }

    // Phase 4: Left punch - horizontal forward strike
    ParallelAnimation {
        // Torso rotates into punch (opposite direction)
        EulerAnim {
            target: entity.torso
            duration: _fightAnim.duration
            from: Qt.vector3d(0, 0, 0)
            to: Qt.vector3d(0, -hipTwist, 0)
        }
        EulerAnim {
            target: entity.chest
            duration: _fightAnim.duration
            from: Qt.vector3d(guardChestLean, 0, 0)
            to: Qt.vector3d(guardChestLean, -chestTwist, 0)
        }

        // Right arm in guard
        EulerAnim {
            target: entity.rightArm.upperArm
            duration: _fightAnim.duration
            to: Qt.vector3d(-guardUpperArm, -guardInward, 0)
        }
        EulerAnim {
            target: entity.rightArm.lowerArm
            duration: _fightAnim.duration
            to: Qt.vector3d(-guardElbow, 0, 0)
        }

        // Left arm extends forward horizontally
        EulerAnim {
            target: entity.leftArm.upperArm
            duration: _fightAnim.duration
            from: Qt.vector3d(-guardUpperArm, guardInward, 0)
            to: Qt.vector3d(-punchUpperArm, 0, 0)
        }
        EulerAnim {
            target: entity.leftArm.lowerArm
            duration: _fightAnim.duration
            from: Qt.vector3d(-guardElbow, 0, 0)
            to: Qt.vector3d(-punchElbow, 0, 0)
        }

        // Legs maintain stance
        EulerAnim {
            target: entity.rightLeg.upperLeg
            duration: _fightAnim.duration
            to: Qt.vector3d(-kneeBend, 0, 0)
        }
        EulerAnim {
            target: entity.rightLeg.lowerLeg
            duration: _fightAnim.duration
            to: Qt.vector3d(kneeBend * 2, 0, 0)
        }
        EulerAnim {
            target: entity.leftLeg.upperLeg
            duration: _fightAnim.duration
            to: Qt.vector3d(-kneeBend, 0, 0)
        }
        EulerAnim {
            target: entity.leftLeg.lowerLeg
            duration: _fightAnim.duration
            to: Qt.vector3d(kneeBend * 2, 0, 0)
        }
    }
}
