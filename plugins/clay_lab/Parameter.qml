// (c) Clayground Contributors - MIT License, see "LICENSE" file

import QtQuick

/*!
    \qmltype Parameter
    \inqmlmodule Clayground.Lab
    \brief A named, ranged lab parameter, auto-registered with Lab.

    Declare one per tunable quantity and bind your system to \c value.
    ParamPanel builds its sliders from all registered parameters; agents
    set values via \c{Lab.set(name, value)}.

    Example usage:
    \qml
    import Clayground.Lab

    Parameter { id: pGravity; name: "gravity"; value: 9.81; from: 0; to: 30; unit: "m/s²" }
    \endqml

    \sa Lab, ParamPanel
*/
QtObject {
    id: _param

    /*!
        \qmlproperty string Parameter::name
        \brief Unique name used by Lab, ParamPanel and agents.
    */
    property string name: ""

    /*!
        \qmlproperty real Parameter::value
        \brief Current value; bind your system to this.
    */
    property real value: 0

    /*!
        \qmlproperty real Parameter::from
        \brief Lower bound of the value range.
    */
    property real from: 0

    /*!
        \qmlproperty real Parameter::to
        \brief Upper bound of the value range.
    */
    property real to: 1

    /*!
        \qmlproperty real Parameter::stepSize
        \brief Slider step (0 = continuous).
    */
    property real stepSize: 0

    /*!
        \qmlproperty string Parameter::unit
        \brief Display unit, e.g. "m/s²".
    */
    property string unit: ""

    /*!
        \qmlproperty string Parameter::description
        \brief One-line explanation shown as tooltip/annotation.
    */
    property string description: ""

    Component.onCompleted: Lab.registerParameter(_param)
    Component.onDestruction: Lab.unregisterParameter(_param)
}
