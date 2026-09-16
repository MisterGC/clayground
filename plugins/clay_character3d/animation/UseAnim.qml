// (c) Clayground Contributors - MIT License, see "LICENSE" file
import QtQuick

/*!
    \qmltype UseAnim
    \inqmlmodule Clayground.Character3D
    \inherits ActionCycleAnim
    \brief Working at something - a desk, a table, a workbench.

    Every angle is in \c {action.js}; this is \l ActionCycleAnim with
    \l {ActionCycleAnim::action}{action} set.
    \l {ActionCycleAnim::workHeight}{workHeight} says how high the surface is,
    \l {ActionCycleAnim::intensity}{intensity} how hard at it the character is.

    \sa ActionCycleAnim, FightAnim
*/
ActionCycleAnim {
    action: "use"
}
