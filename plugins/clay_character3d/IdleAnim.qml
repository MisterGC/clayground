import QtQuick

ProceduralAnim {
    id: _idleAnim

    ParallelAnimation {
        PosAndEulerAnim {
            duration: _idleAnim.duration
            target: entity.rightFoot
            toPos: target.basePos
            toEuler: Qt.vector3d(0,0,0)
        }
        PosAndEulerAnim {
            duration: _idleAnim.duration
            target: entity.leftFoot
            toPos: target.basePos
            toEuler: Qt.vector3d(0,0,0)
        }
        PosAndEulerAnim {
            duration: _idleAnim.duration
            target: entity.rightHand
            toPos: target.basePos
            toEuler: Qt.vector3d(0,0,0)
        }
        PosAndEulerAnim {
            duration: _idleAnim.duration
            target: entity.leftHand
            toPos: target.basePos
            toEuler: Qt.vector3d(0,0,0)
        }
    }
}
