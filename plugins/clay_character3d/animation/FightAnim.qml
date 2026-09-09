// (c) Clayground Contributors - MIT License, see "LICENSE" file
import QtQuick

/*!
    \qmltype FightAnim
    \inqmlmodule Clayground.Character3D
    \inherits ActionCycleAnim
    \brief Boxing: a bladed stance, a guard, and alternating straights.

    Every angle is in \c {action.js}; this is \l ActionCycleAnim with
    \l {ActionCycleAnim::action}{action} set. \l Character runs it while
    \l {Character::activity}{activity} is \c Fighting, and takes
    \l {ActionCycleAnim::handPose}{handPose} from it - which is how a punch
    gets thrown with a closed hand.

    \sa ActionCycleAnim, UseAnim
*/
ActionCycleAnim {
    action: "fight"
}
