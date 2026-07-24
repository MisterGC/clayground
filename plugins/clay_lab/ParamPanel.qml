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
    color: "#e60a0f14"
    border.color: "#5500d9ff"
    border.width: 1
    radius: 6

    Column {
        id: _content
        x: 12; y: 8
        width: parent.width - 24
        spacing: 8

        Item {
            width: parent.width; height: 20
            Text {
                text: (_panel.expanded ? "▾ " : "▸ ") + "PARAMETERS"
                color: "#00d9ff"; font.pixelSize: 12; font.bold: true
                font.letterSpacing: 1.5
            }
            Text {
                anchors.right: parent.right
                visible: Lab.scenario !== ""
                text: Lab.scenario
                color: "#ffd93d"; font.pixelSize: 11; font.italic: true
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
                        text: _row.par ? _row.par.name : ""
                        color: "#e8ecf2"; font.pixelSize: 11
                    }
                    Text {
                        anchors.right: parent.right
                        text: _row.par
                              ? _row.par.value.toFixed(2) + (_row.par.unit ? " " + _row.par.unit : "")
                              : ""
                        color: "#00d9ff"; font.pixelSize: 11; font.bold: true
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
                        color: "#22ffffff"
                    }
                    Rectangle {
                        anchors.verticalCenter: parent.verticalCenter
                        width: Math.max(0, Math.min(1, _slider.ratio)) * parent.width
                        height: 4; radius: 2
                        color: "#00d9ff"
                    }
                    Rectangle {
                        anchors.verticalCenter: parent.verticalCenter
                        x: Math.max(0, Math.min(1, _slider.ratio)) * (parent.width - width)
                        width: 12; height: 12; radius: 6
                        color: "#0a0f14"; border.color: "#00d9ff"; border.width: 2
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
