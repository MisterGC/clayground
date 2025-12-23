import QtQuick
import QtQuick3D
import ".."

ProceduralAnim {
    id: _walkCycle

    // Access leg dimensions for calculations
    readonly property real totalLegHeight: entity.legHeight
    readonly property real upperLegHeight: entity.legHeight * 0.5
    readonly property real lowerLegHeight: entity.legHeight * 0.5

    // Hip (upper leg) angles - determines the visual stride
    // These angles define how far the legs swing, which determines movement speed
    readonly property real upperLegForwardAngle: 25   // Degrees forward swing
    readonly property real upperLegBackwardAngle: 20  // Degrees backward swing

    // Calculate visual stride from leg geometry (how far feet actually travel per cycle)
    // stride = legHeight * (sin(forward) + sin(backward)) per step, × 2 for full cycle
    readonly property real visualStridePerStep: totalLegHeight * (Math.sin(upperLegForwardAngle * Math.PI / 180) + Math.sin(upperLegBackwardAngle * Math.PI / 180))
    readonly property real visualStridePerCycle: visualStridePerStep * 2

    // Derive walk speed from visual stride and desired animation duration
    // This ensures movement exactly matches the leg animation
    readonly property real animCycleDuration: 800  // ms for full walk cycle (2 steps) - adjust for walk feel
    readonly property real derivedWalkSpeed: visualStridePerCycle / (animCycleDuration / 1000)

    // Duration per phase (half the cycle)
    duration: animCycleDuration / 2
    
    // Knee bend proportional to leg swing (more swing = more knee lift for clearance)
    readonly property real swingIntensity: (upperLegForwardAngle + upperLegBackwardAngle) / 45  // Normalized 0-1
    readonly property real kneeLiftAngle: 25 + swingIntensity * 20  // 25-45 degrees
    readonly property real kneeExtendAngle: 10 + swingIntensity * 5   // 10-15 degrees
    
    // Foot angles for natural heel-toe motion (more pronounced for visibility)
    readonly property real footDorsiflexion: 20    // Toe up for heel strike
    readonly property real footPlantarflexion: 25  // Toe down for push-off
    
    // Arm swing proportional to leg movement
    // Arms should swing roughly equally forward and backward
    readonly property real armSwingFactor: 0.6
    readonly property real upperArmForwardAngle: upperLegForwardAngle * armSwingFactor
    readonly property real upperArmBackwardAngle: upperLegForwardAngle * armSwingFactor * 0.9  // Nearly equal to forward
    readonly property real lowerArmBendAngle: 10
    
    // Phase 1: Right leg forward, left leg back
    ParallelAnimation {
        // Torso upright (reset from run lean)
        EulerAnim {
            target: entity.torso
            duration: _walkCycle.duration
            from: Qt.vector3d(0, 0, 0)
            to: Qt.vector3d(0, 0, 0)
        }

        // Right leg forward motion
        EulerAnim {
            target: entity.rightLeg.upperLeg
            duration: _walkCycle.duration
            from: Qt.vector3d(upperLegBackwardAngle, 0, 0)
            to: Qt.vector3d(-upperLegForwardAngle, 0, 0)
        }
        EulerAnim {
            target: entity.rightLeg.lowerLeg
            duration: _walkCycle.duration
            from: Qt.vector3d(kneeLiftAngle, 0, 0)
            to: Qt.vector3d(kneeExtendAngle, 0, 0)
        }
        EulerAnim {
            target: entity.rightLeg.foot
            duration: _walkCycle.duration
            from: Qt.vector3d(footPlantarflexion, 0, 0)
            to: Qt.vector3d(-footDorsiflexion, 0, 0)
        }
        
        // Left leg backward motion
        EulerAnim {
            target: entity.leftLeg.upperLeg
            duration: _walkCycle.duration
            from: Qt.vector3d(-upperLegForwardAngle, 0, 0)
            to: Qt.vector3d(upperLegBackwardAngle, 0, 0)
        }
        EulerAnim {
            target: entity.leftLeg.lowerLeg
            duration: _walkCycle.duration
            from: Qt.vector3d(kneeExtendAngle, 0, 0)
            to: Qt.vector3d(kneeLiftAngle, 0, 0)
        }
        EulerAnim {
            target: entity.leftLeg.foot
            duration: _walkCycle.duration
            from: Qt.vector3d(-footDorsiflexion, 0, 0)
            to: Qt.vector3d(footPlantarflexion, 0, 0)
        }
        
        // Right arm backward (opposite to right leg)
        EulerAnim {
            target: entity.rightArm.upperArm
            duration: _walkCycle.duration
            from: Qt.vector3d(-upperArmForwardAngle, 0, 0)
            to: Qt.vector3d(upperArmBackwardAngle, 0, 0)
        }
        EulerAnim {
            target: entity.rightArm.lowerArm
            duration: _walkCycle.duration
            from: Qt.vector3d(-lowerArmBendAngle, 0, 0)
            to: Qt.vector3d(-lowerArmBendAngle, 0, 0)
        }
        
        // Left arm forward (opposite to left leg)
        EulerAnim {
            target: entity.leftArm.upperArm
            duration: _walkCycle.duration
            from: Qt.vector3d(upperArmBackwardAngle, 0, 0)
            to: Qt.vector3d(-upperArmForwardAngle, 0, 0)
        }
        EulerAnim {
            target: entity.leftArm.lowerArm
            duration: _walkCycle.duration
            from: Qt.vector3d(-lowerArmBendAngle, 0, 0)
            to: Qt.vector3d(-lowerArmBendAngle, 0, 0)
        }
    }
    
    // Phase 2: Left leg forward, right leg back
    ParallelAnimation {
        // Torso upright (reset from run lean)
        EulerAnim {
            target: entity.torso
            duration: _walkCycle.duration
            from: Qt.vector3d(0, 0, 0)
            to: Qt.vector3d(0, 0, 0)
        }

        // Left leg forward motion
        EulerAnim {
            target: entity.leftLeg.upperLeg
            duration: _walkCycle.duration
            from: Qt.vector3d(upperLegBackwardAngle, 0, 0)
            to: Qt.vector3d(-upperLegForwardAngle, 0, 0)
        }
        EulerAnim {
            target: entity.leftLeg.lowerLeg
            duration: _walkCycle.duration
            from: Qt.vector3d(kneeLiftAngle, 0, 0)
            to: Qt.vector3d(kneeExtendAngle, 0, 0)
        }
        EulerAnim {
            target: entity.leftLeg.foot
            duration: _walkCycle.duration
            from: Qt.vector3d(footPlantarflexion, 0, 0)
            to: Qt.vector3d(-footDorsiflexion, 0, 0)
        }
        
        // Right leg backward motion
        EulerAnim {
            target: entity.rightLeg.upperLeg
            duration: _walkCycle.duration
            from: Qt.vector3d(-upperLegForwardAngle, 0, 0)
            to: Qt.vector3d(upperLegBackwardAngle, 0, 0)
        }
        EulerAnim {
            target: entity.rightLeg.lowerLeg
            duration: _walkCycle.duration
            from: Qt.vector3d(kneeExtendAngle, 0, 0)
            to: Qt.vector3d(kneeLiftAngle, 0, 0)
        }
        EulerAnim {
            target: entity.rightLeg.foot
            duration: _walkCycle.duration
            from: Qt.vector3d(-footDorsiflexion, 0, 0)
            to: Qt.vector3d(footPlantarflexion, 0, 0)
        }
        
        // Left arm backward (opposite to left leg)
        EulerAnim {
            target: entity.leftArm.upperArm
            duration: _walkCycle.duration
            from: Qt.vector3d(-upperArmForwardAngle, 0, 0)
            to: Qt.vector3d(upperArmBackwardAngle, 0, 0)
        }
        EulerAnim {
            target: entity.leftArm.lowerArm
            duration: _walkCycle.duration
            from: Qt.vector3d(-lowerArmBendAngle, 0, 0)
            to: Qt.vector3d(-lowerArmBendAngle, 0, 0)
        }
        
        // Right arm forward (opposite to right leg)
        EulerAnim {
            target: entity.rightArm.upperArm
            duration: _walkCycle.duration
            from: Qt.vector3d(upperArmBackwardAngle, 0, 0)
            to: Qt.vector3d(-upperArmForwardAngle, 0, 0)
        }
        EulerAnim {
            target: entity.rightArm.lowerArm
            duration: _walkCycle.duration
            from: Qt.vector3d(-lowerArmBendAngle, 0, 0)
            to: Qt.vector3d(-lowerArmBendAngle, 0, 0)
        }
    }
}