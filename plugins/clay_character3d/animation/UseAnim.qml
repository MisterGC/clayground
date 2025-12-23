// (c) Clayground Contributors - MIT License, see "LICENSE" file
// UseAnim.qml - Generic "using something" animation for desks, tables, workbenches

import QtQuick
import QtQuick3D
import ".."

ProceduralAnim {
    id: _useAnim

    // Configuration
    property real workHeight: 0.6       // 0=waist level, 1=shoulder level
    property real intensity: 0.5        // 0=subtle, 1=vigorous movements

    // Derived angles based on workHeight
    // Upper body lean (hip counter-rotates to keep legs upright)
    readonly property real torsoLean: 10 + intensity * 5                    // 10-15 degrees forward
    readonly property real headTilt: 15 + intensity * 10                    // 15-25 degrees down

    // Upper arm angles: forward reach + downward angle based on work height
    // workHeight 0 (waist) = more downward, workHeight 1 (shoulder) = more forward
    readonly property real upperArmForward: 45 + (1 - workHeight) * 20      // 45-65 degrees forward
    readonly property real upperArmOutward: 15                               // Slight outward angle

    // Elbow bend - more bent for lower work surfaces
    readonly property real elbowBend: 60 + (1 - workHeight) * 20            // 60-80 degrees

    // Elbow rotation for working motion (rotate outward/inward)
    readonly property real elbowRotation: 8 + intensity * 7                  // 8-15 degrees

    // Hand movement amplitude for the working motion
    readonly property real handMovement: 8 + intensity * 12                  // 8-20 degrees

    // Animation timing
    readonly property int cycleDuration: 800 - intensity * 200               // 600-800ms per hand cycle

    duration: cycleDuration

    // Phase 1: Right hand down, left hand up (working motion)
    ParallelAnimation {
        // Torso leaning forward (upper body only)
        EulerAnim {
            target: entity.torso
            duration: _useAnim.duration
            from: Qt.vector3d(torsoLean, 0, 0)
            to: Qt.vector3d(torsoLean, 0, 0)
        }

        // Hip counter-rotates to keep legs upright
        EulerAnim {
            target: entity.hip
            duration: _useAnim.duration
            from: Qt.vector3d(-torsoLean, 0, 0)
            to: Qt.vector3d(-torsoLean, 0, 0)
        }

        // Head looking down at work
        EulerAnim {
            target: entity.head
            duration: _useAnim.duration
            from: Qt.vector3d(headTilt, 0, 0)
            to: Qt.vector3d(headTilt, 0, 0)
        }

        // Right arm - reaching forward, elbow rotating outward, hand moving down
        EulerAnim {
            target: entity.rightArm.upperArm
            duration: _useAnim.duration
            from: Qt.vector3d(-upperArmForward, -upperArmOutward, 0)
            to: Qt.vector3d(-upperArmForward, -upperArmOutward, 0)
        }
        EulerAnim {
            target: entity.rightArm.lowerArm
            duration: _useAnim.duration
            from: Qt.vector3d(-elbowBend, -elbowRotation, 0)
            to: Qt.vector3d(-elbowBend, elbowRotation, 0)
        }
        EulerAnim {
            target: entity.rightArm.hand
            duration: _useAnim.duration
            from: Qt.vector3d(handMovement, 0, 0)
            to: Qt.vector3d(-handMovement, 0, 0)
        }

        // Left arm - reaching forward, elbow rotating inward, hand moving up
        EulerAnim {
            target: entity.leftArm.upperArm
            duration: _useAnim.duration
            from: Qt.vector3d(-upperArmForward, upperArmOutward, 0)
            to: Qt.vector3d(-upperArmForward, upperArmOutward, 0)
        }
        EulerAnim {
            target: entity.leftArm.lowerArm
            duration: _useAnim.duration
            from: Qt.vector3d(-elbowBend, elbowRotation, 0)
            to: Qt.vector3d(-elbowBend, -elbowRotation, 0)
        }
        EulerAnim {
            target: entity.leftArm.hand
            duration: _useAnim.duration
            from: Qt.vector3d(-handMovement, 0, 0)
            to: Qt.vector3d(handMovement, 0, 0)
        }

        // Legs stay in place (standing upright)
        EulerAnim {
            target: entity.rightLeg.upperLeg
            duration: _useAnim.duration
            to: Qt.vector3d(0, 0, 0)
        }
        EulerAnim {
            target: entity.rightLeg.lowerLeg
            duration: _useAnim.duration
            to: Qt.vector3d(0, 0, 0)
        }
        EulerAnim {
            target: entity.leftLeg.upperLeg
            duration: _useAnim.duration
            to: Qt.vector3d(0, 0, 0)
        }
        EulerAnim {
            target: entity.leftLeg.lowerLeg
            duration: _useAnim.duration
            to: Qt.vector3d(0, 0, 0)
        }
    }

    // Phase 2: Right hand up, left hand down (reverse)
    ParallelAnimation {
        // Torso stays leaning
        EulerAnim {
            target: entity.torso
            duration: _useAnim.duration
            from: Qt.vector3d(torsoLean, 0, 0)
            to: Qt.vector3d(torsoLean, 0, 0)
        }

        // Hip stays counter-rotated
        EulerAnim {
            target: entity.hip
            duration: _useAnim.duration
            from: Qt.vector3d(-torsoLean, 0, 0)
            to: Qt.vector3d(-torsoLean, 0, 0)
        }

        // Head stays looking down
        EulerAnim {
            target: entity.head
            duration: _useAnim.duration
            from: Qt.vector3d(headTilt, 0, 0)
            to: Qt.vector3d(headTilt, 0, 0)
        }

        // Right arm - elbow rotating inward, hand moving up
        EulerAnim {
            target: entity.rightArm.upperArm
            duration: _useAnim.duration
            from: Qt.vector3d(-upperArmForward, -upperArmOutward, 0)
            to: Qt.vector3d(-upperArmForward, -upperArmOutward, 0)
        }
        EulerAnim {
            target: entity.rightArm.lowerArm
            duration: _useAnim.duration
            from: Qt.vector3d(-elbowBend, elbowRotation, 0)
            to: Qt.vector3d(-elbowBend, -elbowRotation, 0)
        }
        EulerAnim {
            target: entity.rightArm.hand
            duration: _useAnim.duration
            from: Qt.vector3d(-handMovement, 0, 0)
            to: Qt.vector3d(handMovement, 0, 0)
        }

        // Left arm - elbow rotating outward, hand moving down
        EulerAnim {
            target: entity.leftArm.upperArm
            duration: _useAnim.duration
            from: Qt.vector3d(-upperArmForward, upperArmOutward, 0)
            to: Qt.vector3d(-upperArmForward, upperArmOutward, 0)
        }
        EulerAnim {
            target: entity.leftArm.lowerArm
            duration: _useAnim.duration
            from: Qt.vector3d(-elbowBend, -elbowRotation, 0)
            to: Qt.vector3d(-elbowBend, elbowRotation, 0)
        }
        EulerAnim {
            target: entity.leftArm.hand
            duration: _useAnim.duration
            from: Qt.vector3d(handMovement, 0, 0)
            to: Qt.vector3d(-handMovement, 0, 0)
        }

        // Legs stay in place
        EulerAnim {
            target: entity.rightLeg.upperLeg
            duration: _useAnim.duration
            to: Qt.vector3d(0, 0, 0)
        }
        EulerAnim {
            target: entity.rightLeg.lowerLeg
            duration: _useAnim.duration
            to: Qt.vector3d(0, 0, 0)
        }
        EulerAnim {
            target: entity.leftLeg.upperLeg
            duration: _useAnim.duration
            to: Qt.vector3d(0, 0, 0)
        }
        EulerAnim {
            target: entity.leftLeg.lowerLeg
            duration: _useAnim.duration
            to: Qt.vector3d(0, 0, 0)
        }
    }
}
