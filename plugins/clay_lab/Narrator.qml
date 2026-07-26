// (c) Clayground Contributors - MIT License, see "LICENSE" file
// SPIKE (lab-flows groundwork, awaiting review): shape may still change.

import QtQuick

/*!
    \qmltype Narrator
    \inqmlmodule Clayground.Lab
    \brief The learner-facing surface of a \l Flow: what is being said and where we are.

    A strip sized for a classroom projector: title, the step's narration,
    clickable progress dots and the controls. Anchor it where the lab has
    room (bottom centre is the intended slot) and hide the lab's own hint
    bar while a flow runs.

    \sa Flow
*/
Rectangle {
    id: _nar

    /*!
        \qmlproperty var Narrator::flow
        \brief The \l Flow to present.
    */
    property var flow: null

    visible: flow !== null && flow.running
    implicitWidth: 640
    implicitHeight: _col.implicitHeight + 26
    width: implicitWidth
    height: implicitHeight
    radius: LabTheme.radius
    color: LabTheme.panel
    border.color: LabTheme.secondary
    border.width: LabTheme.borderWidth

    Column {
        id: _col
        x: 16; y: 12
        width: parent.width - 32
        spacing: 7

        Row {
            spacing: 10
            Text {
                text: _nar.flow ? _nar.flow.title : ""
                color: LabTheme.primary
                font.pixelSize: 12; font.bold: true; font.letterSpacing: 1.2
                font.family: LabTheme.monoFont
            }
            Text {
                visible: _nar.flow && _nar.flow.paused
                text: LabLang.t("flow.paused")
                color: LabTheme.accent; font.pixelSize: 12
                font.family: LabTheme.monoFont
            }
        }

        Text {  // the narration itself: big enough to read from the back row
            width: parent.width
            text: _nar.flow ? _nar.flow.narration : ""
            color: LabTheme.ink
            font.pixelSize: 18
            font.family: LabTheme.handFont
            wrapMode: Text.WordWrap
            lineHeight: 1.15
        }

        Text {  // a task's hint, once the learner has had a moment
            width: parent.width
            visible: text !== ""
            text: {
                if (!_nar.flow || !_nar.flow.hintShown) return ""
                const s = _nar.flow.step
                return s && s.task && s.task.hint ? LabLang.t(s.task.hint) : ""
            }
            color: LabTheme.accent
            font.pixelSize: 15
            font.family: LabTheme.handFont
            wrapMode: Text.WordWrap
        }

        Item {
            width: parent.width
            height: 22

            Row {  // progress dots, clickable: the flow is scrubbable
                anchors.verticalCenter: parent.verticalCenter
                spacing: 6
                Repeater {
                    model: _nar.flow ? _nar.flow.steps.length : 0
                    Rectangle {
                        id: _dot
                        required property int index
                        width: 9; height: 9; radius: 5
                        anchors.verticalCenter: parent.verticalCenter
                        readonly property bool done: _nar.flow && index < _nar.flow.index
                        readonly property bool here: _nar.flow && index === _nar.flow.index
                        color: _dot.here ? LabTheme.secondary
                             : (_dot.done ? LabTheme.inkFaint : LabTheme.panelEdge)
                        MouseArea {
                            anchors.fill: parent
                            anchors.margins: -4
                            cursorShape: Qt.PointingHandCursor
                            onClicked: if (_nar.flow) _nar.flow.goTo(_dot.index)
                        }
                    }
                }
            }

            Row {  // controls
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                spacing: 14
                component Action: Text {
                    property bool strong: false
                    color: strong ? LabTheme.secondary : LabTheme.inkFaint
                    font.pixelSize: 14; font.bold: strong
                    font.family: LabTheme.handFont
                }
                Action {
                    visible: _nar.flow && _nar.flow.step && _nar.flow.step.task
                    text: LabLang.t("flow.showme")
                    TapHandler { onTapped: _nar.flow.solve() }
                }
                Action {
                    text: LabLang.t("flow.back")
                    TapHandler { onTapped: _nar.flow.prev() }
                }
                Action {
                    visible: _nar.flow && _nar.flow.paused
                    strong: true
                    text: LabLang.t("flow.resume")
                    TapHandler { onTapped: _nar.flow.paused = false }
                }
                // Next is ALWAYS clickable - a learner who already knows this
                // step must never be held back. What changes is how loudly it
                // asks to be pressed: quiet with a filling bar while the
                // estimated reading time runs, prominent once it has.
                Action {
                    visible: _nar.flow && _nar.flow.step && _nar.flow.step.watch
                    text: LabLang.t("flow.watching")
                }
                Item {
                    width: _next.width; height: 20
                    anchors.verticalCenter: parent.verticalCenter
                    Text {
                        id: _next
                        readonly property bool ripe: !_nar.flow || _nar.flow.ripe
                        text: LabLang.t("flow.next")
                              + (ripe ? "" : "  " + Math.ceil(
                                    (1 - _nar.flow.readyProgress) * _nar.flow.dwellTarget))
                        color: ripe ? LabTheme.secondary : LabTheme.inkFaint
                        font.pixelSize: 14; font.bold: ripe
                        font.family: LabTheme.handFont
                        Behavior on color { ColorAnimation { duration: 250 } }
                    }
                    Rectangle {  // the countdown, as a filling underline
                        visible: !_next.ripe
                        anchors.bottom: parent.bottom
                        width: _next.width * (_nar.flow ? _nar.flow.readyProgress : 0)
                        height: 2; radius: 1
                        color: LabTheme.panelEdge
                    }
                    SequentialAnimation on scale {  // one nudge when it ripens
                        running: _next.ripe && _nar.visible
                        NumberAnimation { to: 1.12; duration: 140 }
                        NumberAnimation { to: 1.0; duration: 220 }
                    }
                    TapHandler { onTapped: _nar.flow.next() }
                }
                Action {
                    text: LabLang.t("flow.leave")
                    TapHandler { onTapped: _nar.flow.stop() }
                }
            }
        }
    }
}
