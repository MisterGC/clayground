// (c) Clayground Contributors - MIT License, see "LICENSE" file

import QtQuick
import Clayground.Lab

// The schematic symbol for a part, drawn in ink.
//
// The palette shows it next to the 3D part, which is the one place a school
// kit can teach the mapping for free: this lump on the board is that squiggle
// on the circuit diagram. Symbols follow IEC 60617 (rectangular resistor).
Canvas {
    id: root

    property string type: "resistor"
    property color ink: LabTheme.ink

    implicitWidth: 34
    implicitHeight: 24
    onTypeChanged: requestPaint()
    onInkChanged: requestPaint()

    onPaint: {
        const ctx = getContext("2d")
        ctx.reset()
        ctx.strokeStyle = ink.toString()
        ctx.fillStyle = ink.toString()
        ctx.lineWidth = 1.6
        ctx.lineCap = "round"

        const w = width, h = height, cy = h / 2
        const lead = 6

        function leads(fromX, toX) {
            ctx.beginPath()
            ctx.moveTo(0, cy); ctx.lineTo(fromX, cy)
            ctx.moveTo(toX, cy); ctx.lineTo(w, cy)
            ctx.stroke()
        }
        function circle(r) {
            ctx.beginPath(); ctx.arc(w / 2, cy, r, 0, 2 * Math.PI); ctx.stroke()
        }

        if (type === "resistor") {
            leads(lead, w - lead)
            ctx.strokeRect(lead, cy - 5, w - 2 * lead, 10)
        } else if (type === "battery") {
            leads(w / 2 - 7, w / 2 + 7)
            ctx.beginPath()
            ctx.moveTo(w / 2 - 7, cy - 8); ctx.lineTo(w / 2 - 7, cy + 8)   // long: +
            ctx.moveTo(w / 2 + 1, cy - 4); ctx.lineTo(w / 2 + 1, cy + 4)   // short: -
            ctx.moveTo(w / 2 - 2, cy - 8); ctx.lineTo(w / 2 - 2, cy + 8)
            ctx.moveTo(w / 2 + 6, cy - 4); ctx.lineTo(w / 2 + 6, cy + 4)
            ctx.stroke()
        } else if (type === "switch") {
            leads(lead, w - lead)
            ctx.beginPath()
            ctx.moveTo(lead, cy); ctx.lineTo(w - lead - 2, cy - 9)         // open blade
            ctx.stroke()
            ctx.beginPath(); ctx.arc(lead, cy, 1.8, 0, 2 * Math.PI); ctx.fill()
            ctx.beginPath(); ctx.arc(w - lead, cy, 1.8, 0, 2 * Math.PI); ctx.fill()
        } else if (type === "led") {
            leads(lead, w - lead)
            ctx.beginPath()                                                // triangle
            ctx.moveTo(lead, cy - 7); ctx.lineTo(lead, cy + 7)
            ctx.lineTo(w - lead, cy); ctx.closePath(); ctx.stroke()
            ctx.beginPath()                                                // cathode bar
            ctx.moveTo(w - lead, cy - 7); ctx.lineTo(w - lead, cy + 7); ctx.stroke()
            for (let i = 0; i < 2; ++i) {                                  // emission
                const x = w / 2 - 1 + i * 6
                ctx.beginPath()
                ctx.moveTo(x, cy - 8); ctx.lineTo(x + 4, cy - 12)
                ctx.moveTo(x + 4, cy - 12); ctx.lineTo(x + 1.5, cy - 11.5)
                ctx.moveTo(x + 4, cy - 12); ctx.lineTo(x + 3.5, cy - 9.5)
                ctx.stroke()
            }
        } else if (type === "bulb") {
            leads(w / 2 - 8, w / 2 + 8)
            circle(8)
            ctx.beginPath()                                                // the cross
            ctx.moveTo(w / 2 - 5.7, cy - 5.7); ctx.lineTo(w / 2 + 5.7, cy + 5.7)
            ctx.moveTo(w / 2 + 5.7, cy - 5.7); ctx.lineTo(w / 2 - 5.7, cy + 5.7)
            ctx.stroke()
        } else if (type === "ammeter" || type === "voltmeter") {
            leads(w / 2 - 8, w / 2 + 8)
            circle(8)
            ctx.font = "bold 11px sans-serif"
            ctx.textAlign = "center"
            ctx.textBaseline = "middle"
            ctx.fillText(type === "ammeter" ? "A" : "V", w / 2, cy + 0.5)
        } else if (type === "junction") {
            ctx.beginPath()
            ctx.moveTo(0, cy); ctx.lineTo(w, cy)
            ctx.moveTo(w / 2, cy); ctx.lineTo(w / 2, h)
            ctx.stroke()
            ctx.beginPath(); ctx.arc(w / 2, cy, 2.6, 0, 2 * Math.PI); ctx.fill()
        }
    }
}
