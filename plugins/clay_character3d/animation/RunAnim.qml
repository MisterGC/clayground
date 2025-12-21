// (c) Clayground Contributors - MIT License, see "LICENSE" file
import QtQuick
import QtQuick3D
import ".."

ProceduralAnim {
    id: _runCycle

    // Access leg dimensions for calculations
    readonly property real totalLegHeight: entity.legHeight
    readonly property real upperLegHeight: entity.legHeight * 0.5
    readonly property real lowerLegHeight: entity.legHeight * 0.5

    // Hip (upper leg) angles - larger than walk for running stride
    readonly property real upperLegForwardAngle: 40   // Degrees forward swing (larger than walk)
    readonly property real upperLegBackwardAngle: 30  // Degrees backward swing

    // Calculate visual stride from leg geometry
    readonly property real visualStridePerStep: totalLegHeight * (Math.sin(upperLegForwardAngle * Math.PI / 180) + Math.sin(upperLegBackwardAngle * Math.PI / 180))
    readonly property real visualStridePerCycle: visualStridePerStep * 2

    // Derive run speed from visual stride and animation duration
    readonly property real animCycleDuration: 450  // ms - faster than walk (800ms)
    readonly property real derivedRunSpeed: visualStridePerCycle / (animCycleDuration / 1000)

    // Duration per phase (half the cycle)
    duration: animCycleDuration / 2

    // Knee bend - more pronounced for running (higher knee lift)
    readonly property real swingIntensity: (upperLegForwardAngle + upperLegBackwardAngle) / 70
    readonly property real kneeLiftAngle: 50 + swingIntensity * 30   // Higher lift for running
    readonly property real kneeExtendAngle: 15 + swingIntensity * 10

    // Foot angles - more aggressive for running
    readonly property real footDorsiflexion: 25
    readonly property real footPlantarflexion: 35

    // Arm swing - more vigorous for running
    readonly property real armSwingFactor: 0.8  // Higher than walk (0.6)
    readonly property real upperArmForwardAngle: upperLegForwardAngle * armSwingFactor
    readonly property real upperArmBackwardAngle: upperLegForwardAngle * armSwingFactor * 0.85
    readonly property real lowerArmBendAngle: 45  // Arms bent at elbow while running

    // Phase 1: Right leg forward, left leg back
    ParallelAnimation {
        // Right leg forward motion
        EulerAnim {
            target: entity.rightLeg.upperLeg
            duration: _runCycle.duration
            from: Qt.vector3d(upperLegBackwardAngle, 0, 0)
            to: Qt.vector3d(-upperLegForwardAngle, 0, 0)
        }
        EulerAnim {
            target: entity.rightLeg.lowerLeg
            duration: _runCycle.duration
            from: Qt.vector3d(kneeLiftAngle, 0, 0)
            to: Qt.vector3d(kneeExtendAngle, 0, 0)
        }
        EulerAnim {
            target: entity.rightLeg.foot
            duration: _runCycle.duration
            from: Qt.vector3d(footPlantarflexion, 0, 0)
            to: Qt.vector3d(-footDorsiflexion, 0, 0)
        }

        // Left leg backward motion
        EulerAnim {
            target: entity.leftLeg.upperLeg
            duration: _runCycle.duration
            from: Qt.vector3d(-upperLegForwardAngle, 0, 0)
            to: Qt.vector3d(upperLegBackwardAngle, 0, 0)
        }
        EulerAnim {
            target: entity.leftLeg.lowerLeg
            duration: _runCycle.duration
            from: Qt.vector3d(kneeExtendAngle, 0, 0)
            to: Qt.vector3d(kneeLiftAngle, 0, 0)
        }
        EulerAnim {
            target: entity.leftLeg.foot
            duration: _runCycle.duration
            from: Qt.vector3d(-footDorsiflexion, 0, 0)
            to: Qt.vector3d(footPlantarflexion, 0, 0)
        }

        // Right arm backward (opposite to right leg)
        EulerAnim {
            target: entity.rightArm.upperArm
            duration: _runCycle.duration
            from: Qt.vector3d(-upperArmForwardAngle, 0, 0)
            to: Qt.vector3d(upperArmBackwardAngle, 0, 0)
        }
        EulerAnim {
            target: entity.rightArm.lowerArm
            duration: _runCycle.duration
            from: Qt.vector3d(-lowerArmBendAngle, 0, 0)
            to: Qt.vector3d(-lowerArmBendAngle, 0, 0)
        }

        // Left arm forward (opposite to left leg)
        EulerAnim {
            target: entity.leftArm.upperArm
            duration: _runCycle.duration
            from: Qt.vector3d(upperArmBackwardAngle, 0, 0)
            to: Qt.vector3d(-upperArmForwardAngle, 0, 0)
        }
        EulerAnim {
            target: entity.leftArm.lowerArm
            duration: _runCycle.duration
            from: Qt.vector3d(-lowerArmBendAngle, 0, 0)
            to: Qt.vector3d(-lowerArmBendAngle, 0, 0)
        }
    }

    // Phase 2: Left leg forward, right leg back
    ParallelAnimation {
        // Left leg forward motion
        EulerAnim {
            target: entity.leftLeg.upperLeg
            duration: _runCycle.duration
            from: Qt.vector3d(upperLegBackwardAngle, 0, 0)
            to: Qt.vector3d(-upperLegForwardAngle, 0, 0)
        }
        EulerAnim {
            target: entity.leftLeg.lowerLeg
            duration: _runCycle.duration
            from: Qt.vector3d(kneeLiftAngle, 0, 0)
            to: Qt.vector3d(kneeExtendAngle, 0, 0)
        }
        EulerAnim {
            target: entity.leftLeg.foot
            duration: _runCycle.duration
            from: Qt.vector3d(footPlantarflexion, 0, 0)
            to: Qt.vector3d(-footDorsiflexion, 0, 0)
        }

        // Right leg backward motion
        EulerAnim {
            target: entity.rightLeg.upperLeg
            duration: _runCycle.duration
            from: Qt.vector3d(-upperLegForwardAngle, 0, 0)
            to: Qt.vector3d(upperLegBackwardAngle, 0, 0)
        }
        EulerAnim {
            target: entity.rightLeg.lowerLeg
            duration: _runCycle.duration
            from: Qt.vector3d(kneeExtendAngle, 0, 0)
            to: Qt.vector3d(kneeLiftAngle, 0, 0)
        }
        EulerAnim {
            target: entity.rightLeg.foot
            duration: _runCycle.duration
            from: Qt.vector3d(-footDorsiflexion, 0, 0)
            to: Qt.vector3d(footPlantarflexion, 0, 0)
        }

        // Left arm backward (opposite to left leg)
        EulerAnim {
            target: entity.leftArm.upperArm
            duration: _runCycle.duration
            from: Qt.vector3d(-upperArmForwardAngle, 0, 0)
            to: Qt.vector3d(upperArmBackwardAngle, 0, 0)
        }
        EulerAnim {
            target: entity.leftArm.lowerArm
            duration: _runCycle.duration
            from: Qt.vector3d(-lowerArmBendAngle, 0, 0)
            to: Qt.vector3d(-lowerArmBendAngle, 0, 0)
        }

        // Right arm forward (opposite to right leg)
        EulerAnim {
            target: entity.rightArm.upperArm
            duration: _runCycle.duration
            from: Qt.vector3d(upperArmBackwardAngle, 0, 0)
            to: Qt.vector3d(-upperArmForwardAngle, 0, 0)
        }
        EulerAnim {
            target: entity.rightArm.lowerArm
            duration: _runCycle.duration
            from: Qt.vector3d(-lowerArmBendAngle, 0, 0)
            to: Qt.vector3d(-lowerArmBendAngle, 0, 0)
        }
    }
}
