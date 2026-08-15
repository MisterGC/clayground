// (c) Clayground Contributors - MIT License, see "LICENSE" file

import QtQuick

/*!
    \qmltype ColumnFace
    \inqmlmodule Clayground.Lab
    \brief A thermometer column on an \l InstrumentScale - every gradation labelled.

    The face for a quantity that has a natural bottom and is read \e off the
    scale rather than as a proportion: a temperature, a wind speed, a water
    level, a tank. It is the vertical sibling of \l BarFace, and the difference
    is what it is for: a bar answers "how full", a column answers "how much" -
    so every major gradation carries its number, and the reading is capped by a
    line you can sight along.

    Flat: an ink-edged column, a fill in the colour the reading has earned, the
    severity bands tinted behind it, a bulb at the foot because that is what
    makes the shape read as an instrument rather than as a progress bar. No
    glass, no mercury shine.

    Example usage:
    \qml
    import Clayground.Lab

    InstrumentScale {
        id: wind
        probe: "windSpeed"
        unit: "m/s"; min: 0; max: 30
        okUntil: 12; warnUntil: 20
        damping: 0.5
    }

    ColumnFace { height: panel.body.height; scale: wind; label: "WIND" }
    \endqml

    \sa InstrumentScale, BarFace, DigitFace, Gauge
*/
Item {
    id: root

    /*!
        \qmlproperty InstrumentScale ColumnFace::scale
        \brief The measurement model this face draws.
    */
    property InstrumentScale scale: null

    /*!
        \qmlproperty string ColumnFace::label
        \brief Caption above the column; empty hides the row.
    */
    property string label: ""

    /*!
        \qmlproperty bool ColumnFace::showValue
        \brief Print the reading above the column.
    */
    property bool showValue: true

    /*!
        \qmlproperty bool ColumnFace::showZones
        \brief Tint the severity bands into the column.
    */
    property bool showZones: true

    /*!
        \qmlproperty bool ColumnFace::showBulb
        \brief Draw the reservoir at the foot.
    */
    property bool showBulb: true

    /*!
        \qmlproperty bool ColumnFace::showPeak
        \brief Mark the held peak. Follows \c {scale.peakHold} by default.
    */
    property bool showPeak: scale ? scale.peakHold : false

    /*!
        \qmlproperty real ColumnFace::thickness
        \brief Width of the column.
    */
    property real thickness: LabTheme.px(16)

    /*!
        \qmlproperty bool ColumnFace::showFrame
        \brief Draw the panel background and border behind the face.
    */
    property bool showFrame: false

    /*!
        \qmlproperty real ColumnFace::frameRadius
        \brief Corner radius of the frame - 0 when baked into a \c Texture.
    */
    property real frameRadius: LabTheme.radius

    readonly property real _fraction: scale ? scale.fraction : 0
    readonly property color _fill: scale ? scale.severityColor : LabTheme.primary
    readonly property real _pad: showFrame ? LabTheme.px(10) : 0

    readonly property real _bulb: showBulb ? Math.round(thickness * 1.7) : 0
    readonly property real _headerH: _header.visible
        ? _header.implicitHeight + LabTheme.spaceS : 0
    readonly property real _labelW: _tickMetric.implicitWidth + LabTheme.spaceM
    readonly property string _widestTick: {
        if (!scale) return ""
        let s = ""
        for (const t of scale.ticks) if (t.text.length > s.length) s = t.text
        return s
    }

    // Deliberately NOT widened to fit the caption: the header is width-capped
    // and elides against the face instead, because taking the caption's width
    // into the face's own would make the face's width depend on an item that
    // is laid out inside it.
    implicitWidth: Math.ceil(thickness + LabTheme.px(5) + _labelW) + 2 * _pad
    implicitHeight: LabTheme.px(190)

    Text {
        id: _tickMetric
        visible: false
        text: root._widestTick
        font.pixelSize: LabTheme.fontMicro
        font.family: LabTheme.monoFont
    }

    Rectangle {
        anchors.fill: parent
        visible: root.showFrame
        radius: root.frameRadius
        color: LabTheme.panel
        border.color: LabTheme.panelEdge
        border.width: root.frameRadius > 0 ? LabTheme.borderWidth : 0
    }

    // --- header ------------------------------------------------------------

    Column {
        id: _header
        x: root._pad
        y: root._pad
        width: root.width - 2 * root._pad
        visible: root.label !== "" || root.showValue
        spacing: LabTheme.spaceXs
        Text {
            width: parent.width
            visible: root.label !== ""
            elide: Text.ElideRight
            text: root.label
            color: LabTheme.inkFaint
            font.pixelSize: LabTheme.fontSmall
            font.letterSpacing: 1.0
            font.family: LabTheme.monoFont
        }
        Text {
            visible: root.showValue
            text: root.scale ? root.scale.valueText : ""
            color: root.scale && root.scale.graded ? root._fill : LabTheme.ink
            font.pixelSize: LabTheme.fontBody
            font.bold: true
            font.family: LabTheme.monoFont
        }
    }

    // --- the column --------------------------------------------------------

    Rectangle {
        id: _stem
        x: root._pad
        y: root._pad + root._headerH
        width: root.thickness
        height: Math.max(0, root.height - 2 * root._pad - root._headerH - root._bulb)
        color: LabTheme.paperDeep
        border.color: LabTheme.panelEdge
        border.width: LabTheme.borderWidth
        clip: true

        Repeater {
            model: root.showZones && root.scale ? root.scale.zoneList : []
            Rectangle {
                required property var modelData
                readonly property real f0: root.scale.fractionOf(modelData.from)
                readonly property real f1: root.scale.fractionOf(modelData.to)
                y: _stem.height * (1 - Math.max(f0, f1))
                width: _stem.width
                height: _stem.height * Math.abs(f1 - f0)
                color: root.scale.colorFor(modelData.severity)
                opacity: 0.16
            }
        }

        Rectangle {   // the reading
            y: _stem.height - height
            width: _stem.width
            height: _stem.height * root._fraction
            color: root._fill
        }

        Rectangle {   // the line you sight along
            visible: root._fraction > 0.001
            y: Math.min(_stem.height - height,
                        Math.max(0, _stem.height * (1 - root._fraction) - height / 2))
            width: _stem.width
            height: Math.max(1, LabTheme.px(1.5))
            color: LabTheme.ink
        }

        Rectangle {   // the held peak
            visible: root.showPeak && root.scale && root.scale.peakFraction > 0.001
            readonly property real f: root.scale ? root.scale.peakFraction : 0
            y: Math.min(_stem.height - height,
                        Math.max(0, _stem.height * (1 - f) - height / 2))
            width: _stem.width
            height: Math.max(2, LabTheme.px(2))
            color: LabTheme.ink
        }
    }

    // The reservoir. It is always full - a thermometer's bulb is where the
    // column comes FROM, not part of the reading, and drawing it in the ink of
    // the fill is what makes the whole shape read as one instrument.
    Rectangle {
        visible: root.showBulb
        x: root._pad + (root.thickness - width) / 2
        y: _stem.y + _stem.height - LabTheme.borderWidth
        width: root._bulb
        height: root._bulb
        radius: width / 2
        color: root._fill
        border.color: LabTheme.panelEdge
        border.width: LabTheme.borderWidth
    }

    // --- gradations --------------------------------------------------------

    Item {
        id: _ticks
        visible: root.scale
        x: _stem.x + _stem.width
        y: _stem.y
        width: LabTheme.px(5) + root._labelW
        height: _stem.height

        Repeater {
            model: root.scale ? root.scale.ticks : []
            Rectangle {
                required property var modelData
                y: Math.round(_stem.height * (1 - modelData.fraction))
                width: modelData.major ? LabTheme.px(5) : LabTheme.px(3)
                height: Math.max(1, LabTheme.px(1))
                color: modelData.major ? LabTheme.ink : LabTheme.inkFaint
            }
        }

        Repeater {
            model: root.scale ? root.scale.ticks.filter(t => t.major) : []
            Text {
                required property var modelData
                x: LabTheme.px(5) + LabTheme.spaceXs
                y: Math.max(0, Math.min(_ticks.height - implicitHeight,
                                        _stem.height * (1 - modelData.fraction)
                                        - implicitHeight / 2))
                text: modelData.text
                color: LabTheme.inkFaint
                font.pixelSize: LabTheme.fontMicro
                font.family: LabTheme.monoFont
            }
        }
    }
}
