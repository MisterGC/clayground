// (c) Clayground Contributors - MIT License, see "LICENSE" file

import QtQuick

/*!
    \qmltype ReadoutRow
    \inqmlmodule Clayground.Lab
    \brief One line of a readout: swatch, name, live value.

    The row three labs wrote out by hand - sensor-fusion's legend entries,
    LidarMonitor's rows, street-network's stats lines. Swatch on the left in
    the colour the thing wears everywhere else, elided name in the middle,
    value hard right in mono so a column of them lines up.

    Use it inside a \l LabPanel, or let \l ReadoutPanel build a stack of them
    from data.

    \qml
    LabPanel {
        id: legend
        title: LabLang.t("legend.title")
        ReadoutRow {
            width: legend.body.width
            swatch: LabTheme.rose
            label: LabLang.t("sensor.gps")
            value: LabLang.qty(gps.sigma, "m", 1)
        }
    }
    \endqml

    \sa ReadoutPanel, LabPanel
*/
Item {
    id: root

    /*! \qmlproperty color ReadoutRow::swatch \brief The colour this thing wears elsewhere. */
    property color swatch: LabTheme.ink

    /*! \qmlproperty bool ReadoutRow::showSwatch \brief Draw the swatch (off for a plain stat line). */
    property bool showSwatch: true

    /*! \qmlproperty string ReadoutRow::label \brief What it is (already translated). */
    property string label: ""

    /*! \qmlproperty string ReadoutRow::value \brief What it reads right now. */
    property string value: ""

    /*! \qmlproperty color ReadoutRow::valueColor \brief Value colour; use \c alarm to raise it. */
    property color valueColor: LabTheme.ink

    /*!
        \qmlproperty real ReadoutRow::dim
        \brief 0..1 - fades the swatch for a stale or inactive source.

        A sensor that stopped reporting should look like it stopped reporting.
    */
    property real dim: 1.0

    /*!
        \qmlproperty real ReadoutRow::bar
        \brief 0..1 - draws a share bar under the row, or a negative to omit it.

        The gain bar sensor-fusion draws under each sensor: how much this
        reading actually moved the estimate.
    */
    property real bar: -1

    implicitWidth: LabTheme.px(200)
    implicitHeight: _label.implicitHeight + LabTheme.spaceM
                    + (bar >= 0 ? LabTheme.px(6) + LabTheme.spaceXs : 0)
    width: implicitWidth
    height: implicitHeight

    Rectangle {
        id: _dot
        visible: root.showSwatch
        width: LabTheme.px(10); height: width
        radius: width / 2
        y: (_label.implicitHeight + LabTheme.spaceM - height) / 2
        color: root.swatch
        opacity: Math.max(0, Math.min(1, root.dim))
    }

    Text {
        id: _label
        x: root.showSwatch ? _dot.width + LabTheme.spaceL : 0
        width: Math.max(0, parent.width - x - _value.width - LabTheme.spaceM)
        y: (LabTheme.spaceM) / 2
        elide: Text.ElideRight
        text: root.label
        color: LabTheme.inkSoft
        font.pixelSize: LabTheme.fontSmall
        font.family: LabTheme.monoFont
    }

    Text {
        id: _value
        anchors.right: parent.right
        y: _label.y
        text: root.value
        color: root.valueColor
        font.pixelSize: LabTheme.fontSmall; font.bold: true
        font.family: LabTheme.monoFont
    }

    Rectangle {
        visible: root.bar >= 0
        x: _label.x
        y: _label.y + _label.implicitHeight + LabTheme.spaceXs
        width: Math.max(0, parent.width - x)
        height: LabTheme.px(6)
        radius: height / 2
        color: LabTheme.paperDeep
        Rectangle {
            width: parent.width * Math.max(0, Math.min(1, root.bar))
            height: parent.height
            radius: height / 2
            color: root.swatch
            Behavior on width { NumberAnimation { duration: 180 } }
        }
    }
}
