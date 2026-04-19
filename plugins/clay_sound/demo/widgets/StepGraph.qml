// (c) Clayground Contributors - MIT License, see "LICENSE" file
//
// Stepped polyline editor / display. Used by ADSR and pitch envelope
// panels. For v1 it's read-only — just renders the envelope as a
// pixel-stepped trace. Editing happens via the knobs + per-envelope
// parameters on the SynthInstrument.
//
// Usage:
//   StepGraph {
//       label: "ADSR"
//       points: [[0, 0], [0.1, 1], [0.2, 0.6], [0.8, 0.6], [1, 0]]
//       traceColor: Retro.txt
//   }

import QtQuick

Item {
    id: root

    property string label: ""
    // Array of [x, y] pairs, each in 0..1 (both axes).
    property var    points: []
    property color  traceColor: Retro.txt
    property color  gridColor:  "#1a2234"
    property color  bg:         Retro.inset
    // Horizontal block width — bigger = chunkier/more retro.
    property int    pixelStep: 6
    // Gap between horizontal blocks.
    property int    pixelGap:  1
    // Vertical quantization — value snaps to this many bands (0 = off).
    property int    vSteps:    10

    implicitHeight: 56

    Rectangle {
        anchors.fill: parent
        color: root.bg
        border.color: Retro.bevelLo
        border.width: 1
        radius: 2
    }

    Text {
        text: root.label
        color: Retro.txtDim
        font.family: Retro.mono
        font.pixelSize: Retro.fsLabel
        font.bold: true
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.margins: 4
    }

    Canvas {
        id: trace
        anchors.fill: parent
        anchors.margins: 4
        anchors.topMargin: 16
        onPaint: {
            var ctx = getContext("2d")
            ctx.reset()
            // grid
            ctx.strokeStyle = root.gridColor
            ctx.lineWidth = 1
            for (var y of [0.25, 0.5, 0.75]) {
                ctx.beginPath()
                ctx.moveTo(0, height * y)
                ctx.lineTo(width, height * y)
                ctx.stroke()
            }
            for (var x of [0.25, 0.5, 0.75]) {
                ctx.beginPath()
                ctx.moveTo(width * x, 0)
                ctx.lineTo(width * x, height)
                ctx.stroke()
            }

            if (!root.points || root.points.length === 0) return

            // Sort by x
            var pts = root.points.slice().sort(function(a, b) { return a[0] - b[0] })

            function yAt(t) {
                if (t <= pts[0][0]) return pts[0][1]
                for (var i = 1; i < pts.length; ++i) {
                    if (t <= pts[i][0]) {
                        var x0 = pts[i - 1][0], y0 = pts[i - 1][1]
                        var x1 = pts[i][0],     y1 = pts[i][1]
                        var u = (t - x0) / Math.max(0.0001, x1 - x0)
                        return y0 + (y1 - y0) * u
                    }
                }
                return pts[pts.length - 1][1]
            }

            // Draw pixel-stepped rectangles for a clearly digital look
            ctx.fillStyle = root.traceColor
            var blockW = Math.max(1, root.pixelStep)
            var gap    = Math.max(0, root.pixelGap)
            var stride = blockW + gap
            var columns = Math.max(1, Math.floor(width / stride))
            var prevTop = null
            for (var c = 0; c < columns; ++c) {
                var xPx = c * stride
                var t = columns > 1 ? c / (columns - 1) : 0
                var y = yAt(t)
                if (root.vSteps > 0) y = Math.round(y * root.vSteps) / root.vSteps
                var h = Math.max(2, y * (height - 2))
                var top = Math.round(height - h)
                ctx.fillRect(xPx, top, blockW, 2)
                if (prevTop !== null && prevTop !== top) {
                    var lo = Math.min(prevTop, top)
                    var hi = Math.max(prevTop, top)
                    ctx.fillRect(xPx, lo, Math.max(1, Math.floor(blockW / 2)), hi - lo + 2)
                }
                prevTop = top
            }
        }
        Connections {
            target: root
            function onPointsChanged()     { trace.requestPaint() }
            function onTraceColorChanged() { trace.requestPaint() }
            function onPixelStepChanged()  { trace.requestPaint() }
            function onPixelGapChanged()   { trace.requestPaint() }
            function onVStepsChanged()     { trace.requestPaint() }
        }
    }
}
