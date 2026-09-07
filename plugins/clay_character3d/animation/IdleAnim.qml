// (c) Clayground Contributors - MIT License, see "LICENSE" file
//
// IdleAnim - back to standing, from wherever the last activity left the body.
//
// It used to write sixteen zeros, and sixteen zeros is a shop dummy: arms dead
// straight, glued to the ribs, dead-parallel with the trunk. The arms now go
// to action.js's REST instead - a few degrees out, a few forward, a bent
// elbow - and everything else still goes to zero, because everything else IS
// upright when a body stands still. REST is shared with GestureAnim, which
// releases to the same pose, so a gesture that ends does not hand the joints
// over to a second, different idea of standing.

import QtQuick
import "action.js" as ActionLib

/*!
    \qmltype IdleAnim
    \inqmlmodule Clayground.Character3D
    \inherits ProceduralAnim
    \brief The resting pose: what a body holds when no activity and no gesture
           is driving it.

    \l Character runs it once whenever \l {Character::activity}{activity} is
    Idle and no gesture holds the joints. The arm angles are \c {action.js}'s
    REST; the trunk, the legs and the head go upright.

    \sa GestureAnim, ActionCycleAnim
*/
ProceduralAnim {
    id: _idleAnim

    readonly property var _rest: ActionLib.restPose()

    ParallelAnimation {
        // Reset the trunk to upright - the group, and the two spine segments
        // under it. A gait that rounded the back leaves the curve in the
        // belly and the chest, not in the group, so zeroing the group alone
        // would let a character stand still with a slump it never asked for.
        EulerAnim {
            duration: _idleAnim.duration
            target: entity.torso
            to: Qt.vector3d(0, 0, 0)
        }
        EulerAnim {
            duration: _idleAnim.duration
            target: entity.belly
            to: Qt.vector3d(0, 0, 0)
        }
        EulerAnim {
            duration: _idleAnim.duration
            target: entity.chest
            to: Qt.vector3d(0, 0, 0)
        }

        // Reset head and hip (e.g. tilted by UseAnim)
        HeadEulerAnim {
            duration: _idleAnim.duration
            target: entity.head
            to: Qt.vector3d(0, 0, 0)
        }
        EulerAnim {
            duration: _idleAnim.duration
            target: entity.hip
            to: Qt.vector3d(0, 0, 0)
        }

        // The arms. Not zero: see REST in action.js - the few degrees of
        // clearance, forward carry and elbow bend that separate a person
        // standing there from a mannequin.
        EulerAnim {
            duration: _idleAnim.duration
            target: entity.rightArm.upperArm
            to: Qt.vector3d(_idleAnim._rest.rightArm.upper[0],
                            _idleAnim._rest.rightArm.upper[1],
                            _idleAnim._rest.rightArm.upper[2])
        }
        EulerAnim {
            duration: _idleAnim.duration
            target: entity.rightArm.lowerArm
            to: Qt.vector3d(_idleAnim._rest.rightArm.lower[0],
                            _idleAnim._rest.rightArm.lower[1],
                            _idleAnim._rest.rightArm.lower[2])
        }
        // A hanging arm rests with its palm turned in to the body, standing
        // exactly as much as walking. Zero here left a character standing with
        // both palms facing backwards.
        EulerAnim {
            duration: _idleAnim.duration
            target: entity.rightArm.hand
            to: Qt.vector3d(_idleAnim._rest.rightArm.hand[0],
                            _idleAnim._rest.rightArm.hand[1] / 90 * entity.handRestRoll,
                            _idleAnim._rest.rightArm.hand[2])
        }

        EulerAnim {
            duration: _idleAnim.duration
            target: entity.leftArm.upperArm
            to: Qt.vector3d(_idleAnim._rest.leftArm.upper[0],
                            _idleAnim._rest.leftArm.upper[1],
                            _idleAnim._rest.leftArm.upper[2])
        }
        EulerAnim {
            duration: _idleAnim.duration
            target: entity.leftArm.lowerArm
            to: Qt.vector3d(_idleAnim._rest.leftArm.lower[0],
                            _idleAnim._rest.leftArm.lower[1],
                            _idleAnim._rest.leftArm.lower[2])
        }
        EulerAnim {
            duration: _idleAnim.duration
            target: entity.leftArm.hand
            to: Qt.vector3d(_idleAnim._rest.leftArm.hand[0],
                            _idleAnim._rest.leftArm.hand[1] / 90 * entity.handRestRoll,
                            _idleAnim._rest.leftArm.hand[2])
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
