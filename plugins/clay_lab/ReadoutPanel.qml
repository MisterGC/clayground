// (c) Clayground Contributors - MIT License, see "LICENSE" file

import QtQuick

/*!
    \qmltype ReadoutPanel
    \inqmlmodule Clayground.Lab
    \inherits LabPanel
    \brief A titled panel of live readout rows, built from data.

    The legend/stats panel every lab grows: a row per thing, each with the
    colour it wears in the scene, its name, and what it reads right now. Three
    labs had written it out by hand before it moved here.

    Hand it \l rows and it builds them; add children as well and they stack
    underneath, which is where a caption or a \l BudgetBar goes.

    Rows are re-read whenever \l revision changes, which is the escape hatch
    for the usual trap: a simulation that mutates its state in place emits no
    change signal, so a row bound straight to it freezes at its first value.

    \qml
    ReadoutPanel {
        title: LabLang.t("legend.title")
        width: LabTheme.px(258)
        revision: root.simRev
        rows: [
            { swatch: LabTheme.secondary, label: LabLang.t("sensor.fused"),
              value: LabLang.qty(root.fusedError, "m", 1) },
            { swatch: LabTheme.rose, label: LabLang.t("sensor.gps"),
              value: LabLang.qty(root.gpsError, "m", 1), dim: gps.available ? 1 : 0.35 }
        ]
        Text {
            width: parent.width
            text: LabLang.t("legend.caption")
            color: LabTheme.inkFaint; font.pixelSize: LabTheme.fontSmall
            font.family: LabTheme.handFont
        }
    }
    \endqml

    \sa ReadoutRow, LabPanel, Gauge
*/
LabPanel {
    id: root

    /*!
        \qmlproperty var ReadoutPanel::rows
        \brief The readings, as \c {[{swatch, label, value, valueColor, dim, bar, showSwatch}]}.

        Only \c label and \c value are required.
    */
    property var rows: []

    /*!
        \qmlproperty int ReadoutPanel::revision
        \brief Bump to re-read \l rows after mutating state in place.
    */
    property int revision: 0

    Repeater {
        model: {
            root.revision           // an in-place mutation has no signal of its own
            return root.rows
        }
        ReadoutRow {
            required property var modelData
            width: root.body.width
            showSwatch: modelData.showSwatch !== undefined ? modelData.showSwatch
                                                           : modelData.swatch !== undefined
            swatch: modelData.swatch !== undefined ? modelData.swatch : LabTheme.ink
            label: modelData.label !== undefined ? modelData.label : ""
            value: modelData.value !== undefined ? String(modelData.value) : ""
            valueColor: modelData.valueColor !== undefined ? modelData.valueColor
                                                           : LabTheme.ink
            dim: modelData.dim !== undefined ? modelData.dim : 1.0
            bar: modelData.bar !== undefined ? modelData.bar : -1
        }
    }
}
