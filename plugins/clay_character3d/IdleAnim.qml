import QtQuick

ProceduralAnim {
    id: _idleAnim

    // Access body parts through arm/leg hierarchy
    readonly property Foot _rightFoot: entity.rightLeg.foot
    readonly property Foot _leftFoot: entity.leftLeg.foot
    readonly property Hand _rightHand: entity.rightArm.hand
    readonly property Hand _leftHand: entity.leftArm.hand

    ParallelAnimation {
        PosAndEulerAnim {
            duration: _idleAnim.duration
            target: _idleAnim._rightFoot
            toPos: target.basePos
            toEuler: Qt.vector3d(0,0,0)
        }
        PosAndEulerAnim {
            duration: _idleAnim.duration
            target: _idleAnim._leftFoot
            toPos: target.basePos
            toEuler: Qt.vector3d(0,0,0)
        }
        PosAndEulerAnim {
            duration: _idleAnim.duration
            target: _idleAnim._rightHand
            toPos: target.basePos
            toEuler: Qt.vector3d(0,0,0)
        }
        PosAndEulerAnim {
            duration: _idleAnim.duration
            target: _idleAnim._leftHand
            toPos: target.basePos
            toEuler: Qt.vector3d(0,0,0)
        }
    }
}
