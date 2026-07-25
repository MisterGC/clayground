// (c) Clayground Contributors - MIT License, see "LICENSE" file

import QtQuick

/*!
    \qmltype BudgetBar
    \inqmlmodule Clayground.Lab
    \brief Shows how one total splits into its parts.

    A stacked bar plus a legend, for the question every lab eventually asks:
    \e {where does it all go?} Volts around a loop, current at a junction,
    power in a machine, time in a frame budget - anything conserved that
    divides into shares. Seeing a share swallow the whole bar explains a
    fault faster than any number does.

    Example usage:
    \qml
    import Clayground.Lab

    BudgetBar {
        width: 200
        unit: "V"
        segments: [
            { label: "lost in the cell", value: 4.4, color: "#c05621" },
            { label: "reaches the parts", value: 0.1, color: "#3e9b92" }
        ]
    }
    \endqml

    \sa Plot2D, ParamPanel
*/
Item {
    id: root

    /*!
        \qmlproperty var BudgetBar::segments
        \brief The shares, as \c{[{label, value, color}]}.

        Values are absolute amounts; the bar normalizes them against their
        sum (or \l total, when the whole is known and larger).
    */
    property var segments: []

    /*!
        \qmlproperty string BudgetBar::unit
        \brief Unit appended to every value in the legend.
    */
    property string unit: ""

    /*!
        \qmlproperty int BudgetBar::decimals
        \brief Digits shown per value. Defaults to 2.
    */
    property int decimals: 2

    /*!
        \qmlproperty real BudgetBar::total
        \brief The whole the shares are measured against.

        Defaults to the sum of the segment values; set it explicitly when
        part of the total is unaccounted for (the remainder is left blank).
    */
    property real total: {
        let sum = 0
        for (const s of segments) sum += Math.max(0, s.value)
        return sum
    }

    implicitWidth: 180
    implicitHeight: _bar.height + _legend.height + 6

    Rectangle {
        id: _bar
        width: parent.width
        height: 10
        radius: 5
        clip: true
        color: LabTheme.panelEdge

        Row {
            anchors.fill: parent
            Repeater {
                model: root.segments
                Rectangle {
                    height: parent.height
                    width: root.total > 0
                        ? parent.width * Math.max(0, modelData.value) / root.total : 0
                    color: modelData.color
                    Behavior on width { NumberAnimation { duration: 160 } }
                }
            }
        }
    }

    Column {
        id: _legend
        anchors.top: _bar.bottom
        anchors.topMargin: 6
        width: parent.width
        spacing: 2

        Repeater {
            model: root.segments
            Item {
                width: _legend.width
                height: 13
                Rectangle {
                    id: _dot
                    y: 4; width: 7; height: 7; radius: 2
                    color: modelData.color
                }
                Text {
                    x: 13
                    text: modelData.label
                    color: LabTheme.inkSoft
                    font.pixelSize: 10
                    font.family: LabTheme.monoFont
                }
                Text {
                    anchors.right: parent.right
                    text: modelData.value.toFixed(root.decimals)
                          + (root.unit ? " " + root.unit : "")
                    color: LabTheme.ink
                    font.pixelSize: 10; font.bold: true
                    font.family: LabTheme.monoFont
                }
            }
        }
    }
}
