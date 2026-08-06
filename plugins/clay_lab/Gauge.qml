// (c) Clayground Contributors - MIT License, see "LICENSE" file

import QtQuick

/*!
    \qmltype Gauge
    \inqmlmodule Clayground.Lab
    \brief A needle dial that picks its own range - the instrument, not a number.

    A reading printed as text says what the value is; a dial says what it is
    \e relative to what the instrument can take, which is the thing a learner
    actually needs. It came out of the circuit kit's meters, where a printed
    dial made an ammeter unmistakably an ammeter from across the board in a way
    a coloured ring never did.

    Ranges work the way a real multimeter's do: give it the ranges the
    instrument has and it selects the smallest one the reading still fits,
    printing which range it settled on. That is a lesson in itself - the needle
    jumping back to a third of scale as the range switches is exactly what a
    bench meter does.

    Everything is laid out in fractions of the item's own size, so the same
    component serves a 90-pixel HUD dial and a 260x200 item baked into a
    \c Texture for a 3D part.

    Example usage:
    \qml
    import Clayground.Lab

    Gauge {
        width: 120; height: 96
        symbol: "A"
        unit: "A"
        ranges: [0.01, 0.1, 1, 10]
        value: circuit.current
        accent: LabTheme.forest
    }
    \endqml

    \sa ReadoutPanel, Plot2D, LabTheme
*/
Item {
    id: root

    /*! \qmlproperty real Gauge::value \brief The reading. Its magnitude drives the needle. */
    property real value: 0

    /*! \qmlproperty string Gauge::unit \brief SI unit of \l value, e.g. \c "A". */
    property string unit: ""

    /*!
        \qmlproperty string Gauge::symbol
        \brief The large glyph in the corner - what this instrument measures.

        Defaults to the unit. Set it when the two differ (a tachometer reading
        \c "/min" is still an \c "n").
    */
    property string symbol: unit

    /*!
        \qmlproperty var Gauge::ranges
        \brief Full-scale values on offer, ascending.

        The smallest one that still contains the reading is selected. With a
        single entry the dial is fixed-range.
    */
    property var ranges: [1]

    /*! \qmlproperty color Gauge::accent \brief Ring/symbol colour - use it to say what this is. */
    property color accent: LabTheme.primary

    /*! \qmlproperty color Gauge::needleColor \brief The needle. */
    property color needleColor: LabTheme.clay

    /*! \qmlproperty color Gauge::face \brief The dial face. */
    property color face: LabTheme.panel

    /*! \qmlproperty int Gauge::ticks \brief Tick marks across the sweep. */
    property int ticks: 11

    /*! \qmlproperty int Gauge::majorEvery \brief Every n-th tick is a long one. */
    property int majorEvery: 5

    /*! \qmlproperty real Gauge::sweep \brief Angular travel of the needle, in degrees. */
    property real sweep: 150

    /*!
        \qmlproperty int Gauge::settleTime
        \brief Milliseconds the needle takes to swing to a new reading.

        A real movement has inertia and the swing is worth showing when the
        value changes on an action - a switch closing, a resistor swapped. Set
        it to 0 for a continuously changing signal: an animation restarted
        every frame never arrives, and the needle then visibly disagrees with
        the number printed under it.
    */
    property int settleTime: 260

    /*!
        \qmlproperty bool Gauge::showValue
        \brief Print the reading under the dial as well.

        Off by default: on a part in a 3D scene the number belongs on a chip
        beside it, not on the face. On a HUD dial, turn it on.
    */
    property bool showValue: false

    /*! \qmlproperty bool Gauge::showFrame \brief Draw the panel background and border. */
    property bool showFrame: true

    /*!
        \qmlproperty real Gauge::frameRadius
        \brief Corner radius of the face.

        Set it to 0 when the gauge is baked into a \c Texture: a rounded corner
        there is a transparent hole in the printed plate rather than a rounded
        panel.
    */
    property real frameRadius: LabTheme.radius

    /*!
        \qmlproperty real Gauge::fullScale
        \readonly
        \brief The selected range - the smallest one the reading fits in.
    */
    readonly property real fullScale: {
        const rs = ranges && ranges.length ? ranges : [1]
        const r = Math.abs(value)
        for (const s of rs) if (r <= s) return s
        return rs[rs.length - 1]
    }

    /*!
        \qmlproperty string Gauge::rangeText
        \readonly
        \brief The selected range as a quantity, e.g. \c "10 mA".
    */
    // Deliberately NOT forced to whole numbers: a 0.5 V range rounded to no
    // decimals prints "1 V", and a dial that names a range twice the one its
    // needle is actually using is worse than one that names none.
    readonly property string rangeText: LabLang.qty(fullScale, unit)

    /*! \qmlproperty string Gauge::valueText \readonly \brief The reading as a quantity. */
    readonly property string valueText: LabLang.qty(value, unit)

    implicitWidth: LabTheme.px(130)
    implicitHeight: LabTheme.px(104)

    readonly property real _fraction: fullScale > 0
        ? Math.max(0, Math.min(1, Math.abs(value) / fullScale)) : 0
    // the needle pivots low and centred, the way a moving-coil movement does
    readonly property real _pivotX: width / 2
    // the printed reading, when it is shown, takes the bottom fifth of the
    // face - so the movement moves up rather than being drawn over it
    readonly property real _pivotY: height * (showValue ? 0.80 : 0.88)
    // the arc has to clear the printed range in the top corner, or the two
    // collide on a short, wide face
    readonly property real _radius: Math.min(width * 0.42,
                                             height * (showValue ? 0.53 : 0.62))

    Rectangle {
        anchors.fill: parent
        visible: root.showFrame
        radius: root.frameRadius
        color: root.face
        border.color: LabTheme.panelEdge
        border.width: root.frameRadius > 0 ? LabTheme.borderWidth : 0
    }

    Text {   // what it measures
        x: root.width * 0.06
        y: root.height * 0.05
        text: root.symbol
        color: root.accent
        font.pixelSize: Math.round(root.height * 0.22)
        font.bold: true
        font.family: LabTheme.monoFont
    }

    Text {   // the range this dial is currently showing
        anchors.right: parent.right
        anchors.rightMargin: root.width * 0.06
        y: root.height * 0.11
        text: "0 – " + root.rangeText
        color: LabTheme.inkFaint
        font.pixelSize: Math.round(root.height * 0.11)
        font.family: LabTheme.monoFont
    }

    Item {
        id: _pivot
        x: root._pivotX
        y: root._pivotY

        Repeater {
            model: Math.max(2, root.ticks)
            Item {
                required property int index
                transformOrigin: Item.TopLeft
                rotation: -root.sweep / 2
                          + index * root.sweep / (Math.max(2, root.ticks) - 1)
                readonly property bool major: index % Math.max(1, root.majorEvery) === 0
                Rectangle {
                    width: Math.max(1, root._radius * 0.032)
                    height: root._radius * (parent.major ? 0.17 : 0.09)
                    x: -width / 2
                    y: -root._radius
                    color: parent.major ? LabTheme.ink : LabTheme.inkFaint
                }
            }
        }

        Item {
            transformOrigin: Item.TopLeft
            rotation: -root.sweep / 2 + root.sweep * root._fraction
            Behavior on rotation {
                enabled: root.settleTime > 0
                NumberAnimation { duration: root.settleTime }
            }
            Rectangle {
                width: Math.max(2, root._radius * 0.048)
                height: root._radius * 0.95
                x: -width / 2
                y: -height
                radius: width / 2
                color: root.needleColor
            }
        }

        Rectangle {   // the hub
            width: Math.max(4, root._radius * 0.17)
            height: width
            x: -width / 2; y: -height / 2
            radius: width / 2
            color: LabTheme.ink
        }
    }

    Text {
        visible: root.showValue
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: root.height * 0.02
        text: root.valueText
        color: LabTheme.ink
        font.pixelSize: Math.round(root.height * 0.13)
        font.bold: true
        font.family: LabTheme.monoFont
    }
}
