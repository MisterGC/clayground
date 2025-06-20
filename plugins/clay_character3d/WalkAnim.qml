import QtQuick
import QtQuick3D

ProceduralAnim {
    id: _walkCycle

    // Calculate duration based on stride length and walk speed
    duration: entity.walkSpeed > 0 ? (entity.strideLength / entity.walkSpeed) * 1000 : 1000
    
    // Access leg dimensions for calculations
    readonly property real totalLegHeight: entity.legHeight
    readonly property real upperLegHeight: entity.legHeight * 0.5
    readonly property real lowerLegHeight: entity.legHeight * 0.5
    
    // Calculate angles based on stride length
    // Primary hip rotation to achieve the stride
    readonly property real halfStride: entity.strideLength * 0.5
    readonly property real maxReach: totalLegHeight * 0.7  // Comfortable walking doesn't fully extend
    readonly property real effectiveStride: Math.min(halfStride, maxReach)
    
    // Hip (upper leg) angles calculated from stride length
    readonly property real upperLegForwardAngle: Math.atan2(effectiveStride, totalLegHeight * 0.9) * 180 / Math.PI
    readonly property real upperLegBackwardAngle: upperLegForwardAngle * 0.6  // Backward swing is typically less
    
    // Knee bend proportional to stride length (more stride = more knee lift for clearance)
    readonly property real kneeLiftAngle: 25 + (effectiveStride / maxReach) * 20  // 25-45 degrees
    readonly property real kneeExtendAngle: 10 + (effectiveStride / maxReach) * 5   // 10-15 degrees
    
    // Foot angles for natural heel-toe motion
    readonly property real footDorsiflexion: 10
    readonly property real footPlantarflexion: 15
    
    // Arm swing proportional to leg movement
    readonly property real armSwingFactor: 0.6
    readonly property real upperArmForwardAngle: upperLegForwardAngle * armSwingFactor
    readonly property real upperArmBackwardAngle: upperLegBackwardAngle * armSwingFactor
    readonly property real lowerArmBendAngle: 10
    
    // Phase 1: Right leg forward, left leg back
    ParallelAnimation {
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
            from: Qt.vector3d(-kneeLiftAngle, 0, 0)
            to: Qt.vector3d(-kneeExtendAngle, 0, 0)
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
            from: Qt.vector3d(-kneeExtendAngle, 0, 0)
            to: Qt.vector3d(-kneeLiftAngle, 0, 0)
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
            from: Qt.vector3d(-kneeLiftAngle, 0, 0)
            to: Qt.vector3d(-kneeExtendAngle, 0, 0)
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
            from: Qt.vector3d(-kneeExtendAngle, 0, 0)
            to: Qt.vector3d(-kneeLiftAngle, 0, 0)
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