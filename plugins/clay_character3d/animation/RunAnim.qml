// (c) Clayground Contributors - MIT License, see "LICENSE" file
import QtQuick

/*!
    \qmltype RunAnim
    \inqmlmodule Clayground.Character3D
    \inherits GaitCycleAnim
    \brief The run: \l GaitCycleAnim over the run base - the classic high
           knees, pumping arms and forward lean, at nearly twice the cadence.
*/
GaitCycleAnim {
    base: "run"

    /*! \qmlproperty real RunAnim::derivedRunSpeed
        \readonly
        \brief Ground speed that keeps the feet from sliding. */
    readonly property real derivedRunSpeed: derivedSpeed
}
