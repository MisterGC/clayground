// (c) Clayground Contributors - MIT License, see "LICENSE" file
import QtQuick

/*!
    \qmltype WalkAnim
    \inqmlmodule Clayground.Character3D
    \inherits GaitCycleAnim
    \brief The walk: \l GaitCycleAnim over the walk base.

    With neutral factors it is the walk the framework always had; what the
    entity's \l {Character::gait}{gait}, build and emotion do to it is in
    \l GaitCycleAnim and \c {gait.js}.
*/
GaitCycleAnim {
    base: "walk"

    /*! \qmlproperty real WalkAnim::derivedWalkSpeed
        \readonly
        \brief Ground speed that keeps the feet from sliding. */
    readonly property real derivedWalkSpeed: derivedSpeed
}
