// (c) Clayground Contributors - MIT License, see "LICENSE" file

import QtQuick

/*!
    \qmltype Scenario
    \inqmlmodule Clayground.Lab
    \brief A named, scripted lab situation, used inside a ScenarioSet.

    The script sets up entity state imperatively (initial QML property
    values don't fire change handlers, so physics coordinates only sync
    on post-creation writes).

    \sa ScenarioSet
*/
QtObject {
    /*!
        \qmlproperty string Scenario::name
        \brief Name used with applyScenario()/the inspector reload action.
    */
    property string name: ""

    /*!
        \qmlproperty string Scenario::description
        \brief One-line explanation of the situation.
    */
    property string description: ""

    /*!
        \qmlproperty var Scenario::script
        \brief Function that sets up the situation imperatively.
    */
    property var script: null
}
