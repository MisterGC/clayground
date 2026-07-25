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
        Symbols.draw(ctx, type, width / 2, height / 2, width, height,
                     { ink: ink, on: on })
    }
}
