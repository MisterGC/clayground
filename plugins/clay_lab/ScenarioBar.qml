// (c) Clayground Contributors - MIT License, see "LICENSE" file

import QtQuick

/*!
    \qmltype ScenarioBar
    \inqmlmodule Clayground.Lab
    \brief Clickable preset chips, each carrying what it is worth noticing.

    A lab's scenarios used to be reachable only by pressing \c 1..4, and the
    only thing on screen was the name of the active one. That hides the labs'
    best teaching material behind undocumented keys: a preset is a prepared
    situation, and the reason it was prepared belongs next to it.

    Each chip shows its digit and its name (\c {<namePrefix><name>}); the
    active preset also shows a one-line note (\c {<notePrefix><name>}) if the
    dictionary has one, which is where "series: one current, the volts
    divide" goes.

    \qml
    ScenarioBar { lab: root; width: parent.width }
    \endqml

    \sa Scenario, ScenarioSet, LabKeys
*/
Column {
    id: root

    /*!
        \qmlproperty var ScenarioBar::lab
        \brief The sandbox root (scenarios/applyScenario).
    */
    property var lab: null

    /*!
        \qmlproperty var ScenarioBar::names
        \brief Presets to offer; defaults to the lab's.
    */
    property var names: lab && lab.scenarios ? lab.scenarios() : []

    /*!
        \qmlproperty string ScenarioBar::namePrefix
        \brief Dictionary prefix for chip labels.
    */
    property string namePrefix: "scenario."

    /*!
        \qmlproperty string ScenarioBar::notePrefix
        \brief Dictionary prefix for the active note.
    */
    property string notePrefix: "scenario.note."

    /*!
        \qmlproperty bool ScenarioBar::showNote
        \brief Show the active preset's one-liner.
    */
    property bool showNote: true

    spacing: LabTheme.spaceS

    Flow {
        width: root.width
        spacing: LabTheme.spaceS

        Repeater {
            model: root.names
            Rectangle {
                required property var modelData
                required property int index
                readonly property bool active: Lab.scenario === modelData
                height: LabTheme.px(24); radius: LabTheme.radius
                width: _label.implicitWidth + LabTheme.px(22)
                color: active ? LabTheme.secondary : LabTheme.paper
                border.color: active ? LabTheme.secondary : LabTheme.panelEdge
                border.width: LabTheme.borderWidth

                Text {
                    id: _label
                    anchors.centerIn: parent
                    // the digit that also works: the chip teaches its own key
                    text: (index < 9 ? (index + 1) + " " : "")
                          + LabLang.t(root.namePrefix + modelData)
                    color: LabTheme.inkOn(parent.color)
                    font.pixelSize: LabTheme.fontSmall
                    font.family: LabTheme.monoFont
                }
                MouseArea {
                    anchors.fill: parent
                    onClicked: if (root.lab && root.lab.applyScenario)
                                   root.lab.applyScenario(modelData)
                }
            }
        }
    }

    Text {
        width: root.width
        wrapMode: Text.WordWrap
        visible: root.showNote && text !== "" && Lab.scenario !== ""
        // no note in the dictionary -> t() hands back the key, which is not
        // something a learner should ever read
        text: {
            if (Lab.scenario === "") return ""
            const key = root.notePrefix + Lab.scenario
            const s = LabLang.t(key)
            return s === key ? "" : s
        }
        color: LabTheme.accent
        font.pixelSize: LabTheme.fontLabel
        font.family: LabTheme.handFont
    }
}
