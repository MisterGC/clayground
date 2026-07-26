// (c) Clayground Contributors - MIT License, see "LICENSE" file

import QtQuick

/*!
    \qmltype TourStep
    \inqmlmodule Clayground.Lab
    \brief One stop of a guided lab Tour.

    \sa Tour
*/
QtObject {
    /*!
        \qmlproperty string TourStep::title
        \brief Short headline of the step.
    */
    property string title: ""

    /*!
        \qmlproperty string TourStep::say
        \brief The explanation shown while the step is active.
    */
    property string say: ""

    /*!
        \qmlproperty string TourStep::scenario
        \brief Optional scenario applied when the step activates.
    */
    property string scenario: ""

    /*!
        \qmlproperty var TourStep::script
        \brief Optional function run when the step activates (camera, presets).
    */
    property var script: null
}
