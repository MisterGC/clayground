// (c) Clayground Contributors - MIT License, see "LICENSE" file

import QtQuick

/*!
    \qmltype Tour
    \inqmlmodule Clayground.Lab
    \brief Guided walkthrough overlay: an ordered set of TourSteps with narration.

    Anchor it like any panel; call start() (or bind a key). Each step may
    apply a scenario and run a script (e.g. camera moves) when activated.

    Example usage:
    \qml
    import Clayground.Lab

    Tour {
        id: tour
        scenarioSet: scenarioSet
        TourStep { title: "Noise"; say: "GPS is honest but noisy."; scenario: "open-sky" }
        TourStep { title: "Fusion"; say: "The filter weighs both by uncertainty." }
    }
    \endqml

    \sa TourStep, ScenarioSet
*/
Rectangle {
    id: _tour

    /*!
        \qmlproperty list<TourStep> Tour::steps
        \brief The steps (default property).
    */
    default property list<TourStep> steps

    /*!
        \qmlproperty ScenarioSet Tour::scenarioSet
        \brief Set used to resolve steps' scenario names.
    */
    property var scenarioSet: null

    /*!
        \qmlproperty int Tour::index
        \readonly
        \brief Active step index (-1 = tour inactive).
    */
    property int index: -1

    /*!
        \qmlmethod void Tour::start()
        \brief Starts the tour at the first step.
    */
    function start() { goTo(0) }

    /*!
        \qmlmethod void Tour::stop()
        \brief Ends the tour.
    */
    function stop() { index = -1 }

    /*!
        \qmlmethod void Tour::next()
        \brief Advances one step; past the last step the tour ends.
    */
    function next() { goTo(index + 1) }

    /*!
        \qmlmethod void Tour::prev()
        \brief Goes back one step.
    */
    function prev() { if (index > 0) goTo(index - 1) }

    function goTo(i) {
        if (i < 0 || i >= steps.length) { index = -1; return }
        index = i
        const s = steps[i]
        if (s.scenario && scenarioSet) scenarioSet.apply(s.scenario)
        if (s.script) s.script()
    }

    visible: index >= 0
    width: 420
    height: _col.height + 20
    // Predates the paper theme and was the last kernel widget still painting
    // its own colours; it now follows LabTheme like everything else.
    color: LabTheme.panel
    border.color: LabTheme.panelEdge
    border.width: LabTheme.borderWidth
    radius: LabTheme.radius

    Column {
        id: _col
        x: 14; y: 10
        width: parent.width - 28
        spacing: 6
        Text {
            width: parent.width
            text: _tour.index >= 0
                  ? (_tour.index + 1) + "/" + _tour.steps.length + " — " + _tour.steps[_tour.index].title
                  : ""
            color: LabTheme.primary; font.pixelSize: LabTheme.fontLabel; font.bold: true
            font.family: LabTheme.monoFont
        }
        Text {
            width: parent.width
            text: _tour.index >= 0 ? _tour.steps[_tour.index].say : ""
            color: LabTheme.inkSoft; font.pixelSize: LabTheme.fontBody
            wrapMode: Text.WordWrap
        }
        Row {
            spacing: 16
            Text {
                text: "‹ prev"; color: LabTheme.inkFaint; font.pixelSize: LabTheme.fontBody
                TapHandler { onTapped: _tour.prev() }
            }
            Text {
                text: "next ›"; color: LabTheme.secondary; font.pixelSize: LabTheme.fontBody; font.bold: true
                TapHandler { onTapped: _tour.next() }
            }
            Text {
                text: "✕ end"; color: LabTheme.inkFaint; font.pixelSize: LabTheme.fontBody
                TapHandler { onTapped: _tour.stop() }
            }
        }
    }
}
