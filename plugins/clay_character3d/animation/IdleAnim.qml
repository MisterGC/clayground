import QtQuick

ProceduralAnim {
    id: _idleAnim

    ParallelAnimation {
        // Reset torso to upright
        EulerAnim {
            duration: _idleAnim.duration
            target: entity.torso
            to: Qt.vector3d(0, 0, 0)
        }

        // Reset right arm joints
        EulerAnim {
            duration: _idleAnim.duration
            target: entity.rightArm.upperArm
            to: Qt.vector3d(0, 0, 0)
        }
        EulerAnim {
            duration: _idleAnim.duration
            target: entity.rightArm.lowerArm
            to: Qt.vector3d(0, 0, 0)
        }
        EulerAnim {
            duration: _idleAnim.duration
            target: entity.rightArm.hand
            to: Qt.vector3d(0, 0, 0)
        }
        
        // Reset left arm joints
        EulerAnim {
            duration: _idleAnim.duration
            target: entity.leftArm.upperArm
            to: Qt.vector3d(0, 0, 0)
        }
        EulerAnim {
            duration: _idleAnim.duration
            target: entity.leftArm.lowerArm
            to: Qt.vector3d(0, 0, 0)
        }
        EulerAnim {
            duration: _idleAnim.duration
            target: entity.leftArm.hand
            to: Qt.vector3d(0, 0, 0)
        }
        
        // Reset right leg joints
        EulerAnim {
            duration: _idleAnim.duration
            target: entity.rightLeg.upperLeg
            to: Qt.vector3d(0, 0, 0)
        }
        EulerAnim {
            duration: _idleAnim.duration
            target: entity.rightLeg.lowerLeg
            to: Qt.vector3d(0, 0, 0)
        }
        EulerAnim {
            duration: _idleAnim.duration
            target: entity.rightLeg.foot
            to: Qt.vector3d(0, 0, 0)
        }
        
        // Reset left leg joints
        EulerAnim {
            duration: _idleAnim.duration
            target: entity.leftLeg.upperLeg
            to: Qt.vector3d(0, 0, 0)
        }
        EulerAnim {
            duration: _idleAnim.duration
            target: entity.leftLeg.lowerLeg
            to: Qt.vector3d(0, 0, 0)
        }
        EulerAnim {
            duration: _idleAnim.duration
            target: entity.leftLeg.foot
            to: Qt.vector3d(0, 0, 0)
        }
    }
}