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

    // Hip (upper leg) angles - pronounced stride like classic animation
    readonly property real upperLegForwardAngle: 55   // Degrees forward swing (extended reach)
    readonly property real upperLegBackwardAngle: 45  // Degrees backward swing (full push-off)

    // Calculate visual stride from leg geometry
    readonly property real visualStridePerStep: totalLegHeight * (Math.sin(upperLegForwardAngle * Math.PI / 180) + Math.sin(upperLegBackwardAngle * Math.PI / 180))
    readonly property real visualStridePerCycle: visualStridePerStep * 2

    // Derive run speed from visual stride and animation duration
    readonly property real animCycleDuration: 450  // ms - faster than walk (800ms)
    readonly property real derivedRunSpeed: visualStridePerCycle / (animCycleDuration / 1000)

    // Duration per phase (half the cycle)
    duration: animCycleDuration / 2

    // Knee bend - high lift like "pass position" in classic run cycle
    readonly property real swingIntensity: (upperLegForwardAngle + upperLegBackwardAngle) / 70
    readonly property real kneeLiftAngle: 70 + swingIntensity * 40   // High knee lift (~110°)
    readonly property real kneeExtendAngle: 10 + swingIntensity * 5  // Nearly straight on contact

    // Foot angles - more aggressive for running
    readonly property real footDorsiflexion: 25
    readonly property real footPlantarflexion: 35

    // Arm swing - vigorous pumping motion like classic animation
    readonly property real armSwingFactor: 1.0  // Full swing matching leg motion
    readonly property real upperArmForwardAngle: upperLegForwardAngle * armSwingFactor
    readonly property real upperArmBackwardAngle: upperLegBackwardAngle * armSwingFactor
    readonly property real lowerArmBendAngle: 70  // Pronounced elbow bend (~90° total)

    // Torso lean - forward tilt for dynamic running posture
    readonly property real torsoLeanAngle: 12  // Degrees forward lean

    // Phase 1: Right leg forward, left leg back
    ParallelAnimation {
        // Torso lean forward
        EulerAnim {
            target: entity.torso
            duration: _runCycle.duration
            from: Qt.vector3d(torsoLeanAngle, 0, 0)
            to: Qt.vector3d(torsoLeanAngle, 0, 0)
        }

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
        // Torso lean forward
        EulerAnim {
            target: entity.torso
            duration: _runCycle.duration
            from: Qt.vector3d(torsoLeanAngle, 0, 0)
            to: Qt.vector3d(torsoLeanAngle, 0, 0)
        }

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
