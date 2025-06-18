import QtQuick

ProceduralAnim {
    id: _idleAnim

    // Access body parts through arm/leg hierarchy
    readonly property alias rightFoot: entity.rightLeg.foot
    readonly property alias leftFoot: entity.leftLeg.foot
    readonly property alias rightHand: entity.rightArm.hand
    readonly property alias leftHand: entity.leftArm.hand

    ParallelAnimation {
        PosAndEulerAnim {
            duration: _idleAnim.duration
            target: _idleAnim.rightFoot
            toPos: target.basePos
            toEuler: Qt.vector3d(0,0,0)
        }
        PosAndEulerAnim {
            duration: _idleAnim.duration
            target: _idleAnim.leftFoot
            toPos: target.basePos
            toEuler: Qt.vector3d(0,0,0)
        }
        PosAndEulerAnim {
            duration: _idleAnim.duration
            target: _idleAnim.rightHand
            toPos: target.basePos
            toEuler: Qt.vector3d(0,0,0)
        }
        PosAndEulerAnim {
            duration: _idleAnim.duration
            target: _idleAnim.leftHand
            toPos: target.basePos
            toEuler: Qt.vector3d(0,0,0)
        }
    }
}
