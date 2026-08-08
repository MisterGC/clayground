// (c) Clayground Contributors - MIT License, see "LICENSE" file

import QtQuick

/*!
    \qmltype DigitFace
    \inqmlmodule Clayground.Lab
    \brief The reading as mono digits - the numeric face of an \l InstrumentScale.

    When the question is "what is the number", not "how far along". Digits
    large, the unit small beside them, an optional caption above and, when the
    scale is self-ranging, the range it settled on underneath - so a digital
    readout still says what it is reading against, which is the one thing a
    bare number never does.

    The number comes from \c {LabLang.qty()}, so it carries its SI prefix and
    the language's decimal separator: 0.05 A prints as \c "50.0 mA" here for
    the same reason it does in the readout beside it.

    Flat and unlit - no seven-segment skeuomorphism, no glow. It is print on
    paper, like everything else in a lab.

    Example usage:
    \qml
    import Clayground.Lab

    InstrumentScale { id: volts; probe: "supply"; unit: "V"; min: 0; max: 12 }

    DigitFace {
        width: panel.body.width
        scale: volts
        label: "SUPPLY"
    }
    \endqml

    \sa InstrumentScale, Gauge, BarFace, ColumnFace
*/
Item {
    id: root

    /*! \qmlproperty InstrumentScale DigitFace::scale \brief The measurement model this face draws. */
    property InstrumentScale scale: null

    /*! \qmlproperty string DigitFace::label \brief Caption above the digits; empty hides the row. */
    property string label: ""

    /*! \qmlproperty bool DigitFace::showUnit \brief Print the unit beside the number. */
    property bool showUnit: true

    /*!
        \qmlproperty bool DigitFace::showRange
        \brief Print the scale in force under the digits.

        Defaults to on for a self-ranging scale, where the selected range is
        part of the reading, and off for a fixed one.
    */
    property bool showRange: scale ? scale.autoRange : false

    /*! \qmlproperty real DigitFace::digitSize \brief Pixel size of the number. */
    property real digitSize: LabTheme.px(30)

    /*! \qmlproperty int DigitFace::alignment \brief \c Qt.AlignLeft (default), \c Qt.AlignHCenter or \c Qt.AlignRight. */
    property int alignment: Qt.AlignLeft

    /*! \qmlproperty bool DigitFace::showFrame \brief Draw the panel background and border behind the face. */
    property bool showFrame: false

    /*! \qmlproperty real DigitFace::frameRadius \brief Corner radius of the frame - 0 when baked into a \c Texture. */
    property real frameRadius: LabTheme.radius

    readonly property var _parts: scale
        ? LabLang.qtyParts(scale.reading, scale.unit,
                           scale.digits < 0 ? undefined : scale.digits)
        : ({ number: "", fullUnit: "" })

    readonly property color _ink: scale && scale.graded ? scale.severityColor
                                                        : LabTheme.ink
    readonly property real _pad: showFrame ? LabTheme.px(10) : 0

    implicitWidth: Math.ceil(Math.max(_label.implicitWidth, _rowBox.lineWidth,
                                      _range.implicitWidth)) + 2 * _pad
    implicitHeight: Math.ceil(_col.height) + 2 * _pad

    Rectangle {
        anchors.fill: parent
        visible: root.showFrame
        radius: root.frameRadius
        color: LabTheme.panel
        border.color: LabTheme.panelEdge
        border.width: root.frameRadius > 0 ? LabTheme.borderWidth : 0
    }

    Column {
        id: _col
        x: root._pad
        y: root._pad
        width: root.width - 2 * root._pad
        spacing: LabTheme.spaceXs

        Text {
            id: _label
            width: parent.width
            visible: root.label !== ""
            elide: Text.ElideRight
            horizontalAlignment: root.alignment
            text: root.label
            color: LabTheme.inkFaint
            font.pixelSize: LabTheme.fontSmall
            font.letterSpacing: 1.0
            font.family: LabTheme.monoFont
        }

        // The number and its unit are one line but two sizes, which is why
        // this takes qtyParts() rather than re-splitting a formatted string.
        // Anchored rather than put in a Row: the unit belongs on the number's
        // BASELINE, and a positioner has no alignment that says so.
        Item {
            id: _rowBox
            width: parent.width
            height: _number.implicitHeight

            readonly property real lineWidth: _number.implicitWidth
                + (_unitText.visible ? LabTheme.spaceXs + _unitText.implicitWidth : 0)

            Text {
                id: _number
                x: root.alignment === Qt.AlignRight ? _rowBox.width - _rowBox.lineWidth
                   : root.alignment === Qt.AlignHCenter
                     ? (_rowBox.width - _rowBox.lineWidth) / 2 : 0
                text: root._parts.number
                color: root._ink
                font.pixelSize: root.digitSize
                font.bold: true
                // digits that change width as they change value make a live
                // readout jitter; a mono face is the whole point
                font.family: LabTheme.monoFont
            }
            Text {
                id: _unitText
                anchors.left: _number.right
                anchors.leftMargin: LabTheme.spaceXs
                anchors.baseline: _number.baseline
                visible: root.showUnit && root._parts.fullUnit !== ""
                text: root._parts.fullUnit
                color: LabTheme.inkFaint
                font.pixelSize: Math.max(LabTheme.fontMicro,
                                         Math.round(root.digitSize * 0.45))
                font.family: LabTheme.monoFont
            }
        }

        Text {
            id: _range
            width: parent.width
            visible: root.showRange && root.scale
            horizontalAlignment: root.alignment
            text: root.scale ? root.scale.rangeText : ""
            color: LabTheme.inkFaint
            font.pixelSize: LabTheme.fontMicro
            font.family: LabTheme.monoFont
        }
    }
}
