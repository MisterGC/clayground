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

    // Registration happens the moment the name is known, not at completion.
    // Component.onCompleted runs in creation order, so the sandbox root's own
    // handler - the one that cold-opens a scenario - fires BEFORE any of its
    // children's, and so does every binding created after this object. Waiting
    // for completion here meant a lab booted with "Lab: unknown parameter"
    // for each of its own parameters and read 0 instead of the declared value.
    Component.onCompleted: _register()
    Component.onDestruction: Lab.unregisterParameter(_param)
    onNameChanged: _register()

    // The name a Lab entry is currently filed under, so a renamed parameter
    // takes its old entry with it instead of leaving a ghost behind.
    property string _registered: ""

    function _register() {
        if (name === _registered) return
        if (_registered !== "") Lab.unregisterParameterNamed(_registered, _param)
        _registered = name
        if (name !== "") Lab.registerParameter(_param)
    }
}
