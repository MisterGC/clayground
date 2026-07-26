// (c) Clayground Contributors - MIT License, see "LICENSE" file

import QtQuick

/*!
    \qmltype ParamPanel
    \inqmlmodule Clayground.Lab
    \brief Auto-generated slider panel for all registered parameters.

    Drop one into any lab; it builds a slider row per Parameter with
    name, value and unit. Collapsible via the header. Uses plain items
    (no Controls styles) so it renders identically everywhere.

    Example usage:
    \qml
    import Clayground.Lab

    ParamPanel { anchors.top: parent.top; anchors.right: parent.right; anchors.margins: 10 }
    \endqml

    \sa Parameter, Lab
*/
Rectangle {
    id: _panel

    /*!
        \qmlproperty bool ParamPanel::expanded
        \brief Whether the slider rows are shown.
    */
    property bool expanded: true

    width: 280
    height: _content.height + 16
    color: LabTheme.panel
    border.color: LabTheme.panelEdge
    border.width: LabTheme.borderWidth
    radius: LabTheme.radius

    Column {
        id: _content
        x: 12; y: 8
        width: parent.width - 24
        spacing: 8

        Item {
            width: parent.width; height: 20
            Text {
                text: (_panel.expanded ? "▾ " : "▸ ") + LabLang.t("lab.parameters")
                color: LabTheme.primary; font.pixelSize: 12; font.bold: true
                font.letterSpacing: 1.5; font.family: LabTheme.monoFont
            }
            Text {
                anchors.right: parent.right
                visible: Lab.scenario !== ""
                text: Lab.scenario
                color: LabTheme.accent; font.pixelSize: 13
                font.family: LabTheme.handFont
            }
            TapHandler { onTapped: _panel.expanded = !_panel.expanded }
        }

        Repeater {
            model: _panel.expanded ? Lab.paramNames : []

            delegate: Column {
                id: _row
                required property var modelData
                property var par: Lab.parameter(modelData)
                width: _content.width
                spacing: 3

                Item {
                    width: parent.width; height: 14
                    Text {
                        // A lab may localize a parameter by registering
                        // "param.<name>"; with nothing registered LabLang
                        // hands the key straight back, and we fall back to the
                        // bare name - so a lab that has not been translated
                        // looks exactly as it did before.
                        text: {
                            if (!_row.par) return ""
                            const key = "param." + _row.par.name
                            const label = LabLang.t(key)
                            return label === key ? _row.par.name : label
                        }
                        color: LabTheme.inkSoft; font.pixelSize: 11
                        font.family: LabTheme.monoFont
                    }
                    Text {
                        anchors.right: parent.right
                        text: _row.par
                              ? LabLang.num(_row.par.value, 2) + (_row.par.unit ? " " + _row.par.unit : "")
                              : ""
                        color: LabTheme.primary; font.pixelSize: 11; font.bold: true
                        font.family: LabTheme.monoFont
                    }
                }

                Item {
                    id: _slider
                    width: parent.width; height: 16
                    property real ratio: !_row.par || _row.par.to === _row.par.from
                                         ? 0
                                         : (_row.par.value - _row.par.from) / (_row.par.to - _row.par.from)

                    Rectangle {
                        anchors.verticalCenter: parent.verticalCenter
                        width: parent.width; height: 4; radius: 2
                        color: LabTheme.panelEdge
                    }
                    Rectangle {
                        anchors.verticalCenter: parent.verticalCenter
                        width: Math.max(0, Math.min(1, _slider.ratio)) * parent.width
                        height: 4; radius: 2
                        color: LabTheme.secondary
                    }
                    Rectangle {
                        anchors.verticalCenter: parent.verticalCenter
                        x: Math.max(0, Math.min(1, _slider.ratio)) * (parent.width - width)
                        width: 12; height: 12; radius: 6
                        color: LabTheme.panel; border.color: LabTheme.ink; border.width: 2
                    }
                    MouseArea {
                        anchors.fill: parent
                        function applyAt(mx) {
                            if (!_row.par) return
                            const p = _row.par
                            let v = p.from + (p.to - p.from) * Math.max(0, Math.min(1, mx / width))
                            if (p.stepSize > 0) v = p.from + Math.round((v - p.from) / p.stepSize) * p.stepSize
                            Lab.set(p.name, v)
                        }
                        onPressed: (mouse) => applyAt(mouse.x)
                        onPositionChanged: (mouse) => { if (pressed) applyAt(mouse.x) }
                    }
                }
            }
        }
    }
}
