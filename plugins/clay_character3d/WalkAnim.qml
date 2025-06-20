import QtQuick
import QtQuick3D

ProceduralAnim {
    id: _walkCycle

    // Maximum rotation angles for natural walk cycle
    property real upperLegForwardRotation: 25
    property real upperLegBackwardRotation: 15
    property real lowerLegBendRotation: 40
    property real lowerLegExtendRotation: 15
    property real footDorsiflexion: 10
    property real footPlantarflexion: 15
    
    property real upperArmForwardRotation: 20
    property real upperArmBackwardRotation: 15
    property real lowerArmBendRotation: 10
    
    // Phase 1: Right leg forward, left leg back
    ParallelAnimation {
        // Right leg forward motion
        EulerAnim {
            target: entity.rightLeg.upperLeg
            duration: _walkCycle.duration
            from: Qt.vector3d(upperLegBackwardRotation, 0, 0)
            to: Qt.vector3d(-upperLegForwardRotation, 0, 0)
        }
        EulerAnim {
            target: entity.rightLeg.lowerLeg
            duration: _walkCycle.duration
            from: Qt.vector3d(-lowerLegBendRotation, 0, 0)
            to: Qt.vector3d(-lowerLegExtendRotation, 0, 0)
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
            from: Qt.vector3d(-upperLegForwardRotation, 0, 0)
            to: Qt.vector3d(upperLegBackwardRotation, 0, 0)
        }
        EulerAnim {
            target: entity.leftLeg.lowerLeg
            duration: _walkCycle.duration
            from: Qt.vector3d(-lowerLegExtendRotation, 0, 0)
            to: Qt.vector3d(-lowerLegBendRotation, 0, 0)
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
            from: Qt.vector3d(-upperArmForwardRotation, 0, 0)
            to: Qt.vector3d(upperArmBackwardRotation, 0, 0)
        }
        EulerAnim {
            target: entity.rightArm.lowerArm
            duration: _walkCycle.duration
            from: Qt.vector3d(-lowerArmBendRotation, 0, 0)
            to: Qt.vector3d(-lowerArmBendRotation, 0, 0)
        }
        
        // Left arm forward (opposite to left leg)
        EulerAnim {
            target: entity.leftArm.upperArm
            duration: _walkCycle.duration
            from: Qt.vector3d(upperArmBackwardRotation, 0, 0)
            to: Qt.vector3d(-upperArmForwardRotation, 0, 0)
        }
        EulerAnim {
            target: entity.leftArm.lowerArm
            duration: _walkCycle.duration
            from: Qt.vector3d(-lowerArmBendRotation, 0, 0)
            to: Qt.vector3d(-lowerArmBendRotation, 0, 0)
        }
    }
    
    // Phase 2: Left leg forward, right leg back
    ParallelAnimation {
        // Left leg forward motion
        EulerAnim {
            target: entity.leftLeg.upperLeg
            duration: _walkCycle.duration
            from: Qt.vector3d(upperLegBackwardRotation, 0, 0)
            to: Qt.vector3d(-upperLegForwardRotation, 0, 0)
        }
        EulerAnim {
            target: entity.leftLeg.lowerLeg
            duration: _walkCycle.duration
            from: Qt.vector3d(-lowerLegBendRotation, 0, 0)
            to: Qt.vector3d(-lowerLegExtendRotation, 0, 0)
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
            from: Qt.vector3d(-upperLegForwardRotation, 0, 0)
            to: Qt.vector3d(upperLegBackwardRotation, 0, 0)
        }
        EulerAnim {
            target: entity.rightLeg.lowerLeg
            duration: _walkCycle.duration
            from: Qt.vector3d(-lowerLegExtendRotation, 0, 0)
            to: Qt.vector3d(-lowerLegBendRotation, 0, 0)
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
            from: Qt.vector3d(-upperArmForwardRotation, 0, 0)
            to: Qt.vector3d(upperArmBackwardRotation, 0, 0)
        }
        EulerAnim {
            target: entity.leftArm.lowerArm
            duration: _walkCycle.duration
            from: Qt.vector3d(-lowerArmBendRotation, 0, 0)
            to: Qt.vector3d(-lowerArmBendRotation, 0, 0)
        }
        
        // Right arm forward (opposite to right leg)
        EulerAnim {
            target: entity.rightArm.upperArm
            duration: _walkCycle.duration
            from: Qt.vector3d(upperArmBackwardRotation, 0, 0)
            to: Qt.vector3d(-upperArmForwardRotation, 0, 0)
        }
        EulerAnim {
            target: entity.rightArm.lowerArm
            duration: _walkCycle.duration
            from: Qt.vector3d(-lowerArmBendRotation, 0, 0)
            to: Qt.vector3d(-lowerArmBendRotation, 0, 0)
        }
    }
}