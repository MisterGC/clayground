// (c) Clayground Contributors - MIT License, see "LICENSE" file

import QtQuick
import Clayground.Lab
import "symbols.js" as Symbols

// One schematic symbol, for lists and legends. The board-wide diagram uses the
// same drawing code (see symbols.js), so a part looks the same in both.
Canvas {
    id: root

    property string type: "resistor"
    property color ink: LabTheme.ink
    property bool on: false

    implicitWidth: 34
    implicitHeight: 24
    onTypeChanged: requestPaint()
    onInkChanged: requestPaint()
    onOnChanged: requestPaint()

    onPaint: {
        const ctx = getContext("2d")
        ctx.reset()
        // the widest box of the symbol's own proportions that still fits: a
        // transistor is square and would otherwise reach past the icon
        const a = Symbols.aspect(type)
        const bw = Math.min(width, height / a)
        Symbols.draw(ctx, type, width / 2, height / 2, bw, bw * a,
                     { ink: ink, on: on })
    }
}
