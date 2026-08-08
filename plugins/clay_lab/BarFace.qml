// (c) Clayground Contributors - MIT License, see "LICENSE" file

import QtQuick

/*!
    \qmltype BarFace
    \inqmlmodule Clayground.Lab
    \brief A level bar on an \l InstrumentScale - horizontal or vertical, with peak-hold.

    The face for a quantity read as "how far along" rather than as a number: a
    level, a load, a share of capacity, an audio meter. It draws whatever
    \l InstrumentScale it is given, so a music VU meter is this face on a log
    scale with \c peakHold on - not a component of its own.

    Flat by construction: an ink-edged track, a fill in the colour the reading
    has earned, the severity bands tinted into the track behind it and the held
    peak as a single line. No bezel, no gloss, no gradient - the same paper and
    ink as the rest of the lab.

    \l segments turns the continuous fill into the LED ladder a level meter
    has, which is worth having when the lesson is "which band am I in" rather
    than "what is the number".

    Example usage:
    \qml
    import Clayground.Lab

    InstrumentScale {
        id: level
        value: mixer.amplitude
        unit: "dB"; min: -48; max: 6
        okUntil: -6; warnUntil: 0
        peakHold: true
    }

    BarFace {
        width: panel.body.width
        scale: level
        label: "MASTER"
        segments: 24
    }
    \endqml

    \sa InstrumentScale, ColumnFace, DigitFace, Gauge
*/
Item {
    id: root

    /*! \qmlproperty InstrumentScale BarFace::scale \brief The measurement model this face draws. */
    property InstrumentScale scale: null

    /*!
        \qmlproperty int BarFace::orientation
        \brief \c Qt.Horizontal (default) or \c Qt.Vertical.
    */
    property int orientation: Qt.Horizontal

    /*! \qmlproperty string BarFace::label \brief Caption above the bar; empty hides the row. */
    property string label: ""

    /*! \qmlproperty bool BarFace::showValue \brief Print the reading beside the label. */
    property bool showValue: true

    /*! \qmlproperty bool BarFace::showTicks \brief Draw the scale's gradations along the bar. */
    property bool showTicks: true

    /*! \qmlproperty bool BarFace::showZones \brief Tint the severity bands into the track. */
    property bool showZones: true

    /*!
        \qmlproperty bool BarFace::showPeak
        \brief Mark the held peak. Follows \c {scale.peakHold} by default.
    */
    property bool showPeak: scale ? scale.peakHold : false

    /*!
        \qmlproperty int BarFace::segments
        \brief Split the fill into this many cells - 0 (default) is a continuous bar.
    */
    property int segments: 0

    /*! \qmlproperty real BarFace::thickness \brief Across-the-bar size of the track. */
    property real thickness: LabTheme.px(14)

    /*! \qmlproperty bool BarFace::showFrame \brief Draw the panel background and border behind the face. */
    property bool showFrame: false

    /*! \qmlproperty real BarFace::frameRadius \brief Corner radius of the frame - 0 when baked into a \c Texture. */
    property real frameRadius: LabTheme.radius

    /*! \qmlproperty bool BarFace::horizontal \readonly \brief True while the bar runs left to right. */
    readonly property bool horizontal: orientation === Qt.Horizontal

    readonly property real _fraction: scale ? scale.fraction : 0
    readonly property color _fill: scale ? scale.severityColor : LabTheme.primary
    readonly property real _pad: showFrame ? LabTheme.spaceM : 0

    readonly property bool _hasHeader: label !== "" || showValue
    // A vertical bar is narrower than its own caption, so its header stacks
    // instead of running along one line - side by side, the two texts of three
    // bars in a row overlap each other's neighbours.
    readonly property real _headerH: {
        if (!_hasHeader) return 0
        if (horizontal)
            return Math.max(_label.implicitHeight, _value.implicitHeight)
                   + LabTheme.spaceXs
        return (_label.visible ? _label.implicitHeight : 0)
               + (_value.visible ? _value.implicitHeight : 0) + LabTheme.spaceXs
    }
    // the gradations need room for a mark and the number under (or beside) it
    readonly property real _tickH: (showTicks && horizontal)
        ? LabTheme.px(4) + _tickFontH + LabTheme.spaceXs : 0
    readonly property real _tickFontH: Math.round(LabTheme.fontMicro * 1.3)
    readonly property real _tickW: (showTicks && !horizontal)
        ? LabTheme.px(4) + _tickLabelW : 0
    // A vertical bar puts its numbers beside the track, so the widest of them
    // is part of the face's width rather than something that overhangs it.
    // Measured off a hidden Text rather than off the live delegates: reading
    // the repeater's children back would make the width depend on items whose
    // own layout depends on it.
    readonly property real _tickLabelW: _tickMetric.implicitWidth + LabTheme.spaceXs
    readonly property string _widestTick: {
        if (!scale) return ""
        let s = ""
        for (const t of scale.ticks) if (t.text.length > s.length) s = t.text
        return s
    }

    Text {
        id: _tickMetric
        visible: false
        text: root._widestTick
        font.pixelSize: LabTheme.fontMicro
        font.family: LabTheme.monoFont
    }

    implicitWidth: horizontal ? LabTheme.px(200)
                              : Math.ceil(thickness + _tickW) + 2 * _pad
    implicitHeight: horizontal ? Math.ceil(_headerH + thickness + _tickH) + 2 * _pad
                               : LabTheme.px(150)

    Rectangle {
        anchors.fill: parent
        visible: root.showFrame
        radius: root.frameRadius
        color: LabTheme.panel
        border.color: LabTheme.panelEdge
        border.width: root.frameRadius > 0 ? LabTheme.borderWidth : 0
    }

    // --- header ------------------------------------------------------------

    Text {
        id: _label
        x: root._pad
        y: root._pad
        visible: root._hasHeader && root.label !== ""
        width: Math.max(0, root.width - 2 * root._pad
                           - (root.horizontal && _value.visible
                              ? _value.implicitWidth + LabTheme.spaceM : 0))
        elide: Text.ElideRight
        text: root.label
        color: LabTheme.inkFaint
        font.pixelSize: LabTheme.fontSmall
        font.letterSpacing: 1.0
        font.family: LabTheme.monoFont
    }

    Text {
        id: _value
        x: root.horizontal
           ? Math.max(root._pad, root.width - root._pad - implicitWidth)
           : root._pad
        y: root.horizontal ? root._pad
                           : root._pad + (_label.visible ? _label.implicitHeight : 0)
        visible: root._hasHeader && root.showValue
        width: root.horizontal ? implicitWidth
                               : Math.max(0, root.width - 2 * root._pad)
        elide: Text.ElideRight
        text: root.scale ? root.scale.valueText : ""
        color: root.scale && root.scale.graded ? root._fill : LabTheme.ink
        font.pixelSize: LabTheme.fontBody
        font.bold: true
        font.family: LabTheme.monoFont
    }

    // --- the track ---------------------------------------------------------

    Rectangle {
        id: _track
        x: root._pad
        y: root._pad + root._headerH
        width: root.horizontal ? root.width - 2 * root._pad - root._tickW
                               : root.thickness
        height: root.horizontal ? root.thickness
                                : root.height - 2 * root._pad - root._headerH - root._tickH
        color: LabTheme.paperDeep
        border.color: LabTheme.panelEdge
        border.width: LabTheme.borderWidth
        clip: true

        readonly property real span: root.horizontal ? width : height

        // The severity bands, tinted into the track. Quiet on purpose: they
        // say where the reading IS relative to the bands, and a band loud
        // enough to compete with the fill would answer a question nobody asked.
        Repeater {
            model: root.showZones && root.scale ? root.scale.zoneList : []
            Rectangle {
                required property var modelData
                readonly property real f0: root.scale.fractionOf(modelData.from)
                readonly property real f1: root.scale.fractionOf(modelData.to)
                x: root.horizontal ? _track.span * Math.min(f0, f1) : 0
                y: root.horizontal ? 0 : _track.span * (1 - Math.max(f0, f1))
                width: root.horizontal ? _track.span * Math.abs(f1 - f0) : _track.width
                height: root.horizontal ? _track.height : _track.span * Math.abs(f1 - f0)
                color: root.scale.colorFor(modelData.severity)
                opacity: 0.16
            }
        }

        // The reading, as one fill...
        Rectangle {
            visible: root.segments <= 0
            x: 0
            y: root.horizontal ? 0 : _track.height - height
            width: root.horizontal ? _track.span * root._fraction : _track.width
            height: root.horizontal ? _track.height : _track.span * root._fraction
            color: root._fill
        }

        // ...or as the ladder of cells a level meter has. Each cell wears the
        // colour of the part of the scale it stands on, so the ladder itself
        // teaches where the bands are before the reading ever reaches them.
        Repeater {
            model: root.segments > 0 ? root.segments : 0
            Rectangle {
                required property int index
                readonly property real cell: _track.span / Math.max(1, root.segments)
                readonly property real f0: index / Math.max(1, root.segments)
                readonly property real gap: Math.max(1, LabTheme.px(1.5))
                x: root.horizontal ? index * cell : 0
                y: root.horizontal ? 0 : _track.height - (index + 1) * cell
                width: root.horizontal ? Math.max(1, cell - gap) : _track.width
                height: root.horizontal ? _track.height : Math.max(1, cell - gap)
                visible: root._fraction > f0
                color: root.scale && root.scale.graded
                       ? root.scale.colorAt(root.scale.valueAt(f0 + 0.5 / Math.max(1, root.segments)))
                       : root._fill
            }
        }

        // The held peak. A line rather than a block: it is a memory of a
        // reading, not a reading.
        Rectangle {
            visible: root.showPeak && root.scale && root.scale.peakFraction > 0.001
            readonly property real f: root.scale ? root.scale.peakFraction : 0
            x: root.horizontal
               ? Math.min(_track.span - width, Math.max(0, _track.span * f - width / 2))
               : 0
            y: root.horizontal
               ? 0
               : Math.min(_track.height - height,
                          Math.max(0, _track.height - _track.span * f - height / 2))
            width: root.horizontal ? Math.max(2, LabTheme.px(2)) : _track.width
            height: root.horizontal ? _track.height : Math.max(2, LabTheme.px(2))
            color: LabTheme.ink
        }
    }

    // --- gradations --------------------------------------------------------

    Item {
        id: _ticks
        visible: root.showTicks && root.scale
        x: root.horizontal ? _track.x : _track.x + _track.width
        y: root.horizontal ? _track.y + _track.height : _track.y
        width: root.horizontal ? _track.width : root._tickW
        height: root.horizontal ? root._tickH : _track.height

        Repeater {
            model: root.scale ? root.scale.ticks : []
            Rectangle {
                required property var modelData
                readonly property real f: modelData.fraction
                x: root.horizontal ? Math.round(_track.span * f) : 0
                y: root.horizontal ? 0
                                   : Math.round(_track.span * (1 - f))
                width: root.horizontal ? Math.max(1, LabTheme.px(1))
                                       : (modelData.major ? LabTheme.px(4) : LabTheme.px(2))
                height: root.horizontal ? (modelData.major ? LabTheme.px(4) : LabTheme.px(2))
                                        : Math.max(1, LabTheme.px(1))
                color: modelData.major ? LabTheme.ink : LabTheme.inkFaint
            }
        }
    }

    // The numbers under (horizontal) or beside (vertical) the gradations. A
    // separate repeater from the marks because only the majors carry one, and
    // an empty Text still claims a row's worth of height.
    Item {
        id: _tickTexts
        visible: root.showTicks && root.scale
        x: _ticks.x
        y: root.horizontal ? _ticks.y + LabTheme.px(4) + LabTheme.spaceXs : _ticks.y
        width: _ticks.width
        height: _ticks.height

        Repeater {
            model: root.scale ? root.scale.ticks.filter(t => t.major) : []
            Text {
                required property var modelData
                readonly property real f: modelData.fraction
                // clamped inside the face, so the first and last number do not
                // hang off the ends of a panel that is exactly the bar's width
                x: root.horizontal
                   ? Math.max(0, Math.min(_tickTexts.width - implicitWidth,
                                          _track.span * f - implicitWidth / 2))
                   : LabTheme.px(4) + LabTheme.spaceXs
                y: root.horizontal
                   ? 0
                   : Math.max(0, Math.min(_tickTexts.height - implicitHeight,
                                          _track.span * (1 - f) - implicitHeight / 2))
                text: modelData.text
                color: LabTheme.inkFaint
                font.pixelSize: LabTheme.fontMicro
                font.family: LabTheme.monoFont
            }
        }
    }
}
