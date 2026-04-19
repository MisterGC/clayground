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
    // How many horizontal pixels between vertices — larger values =
    // chunkier/more retro. 4 is a good default.
    property int    pixelStep: 4

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
            var columns = Math.floor(width / root.pixelStep)
            var prevY = null
            for (var c = 0; c < columns; ++c) {
                var xPx = c * root.pixelStep
                var t = c / (columns - 1)
                var y = yAt(t)
                var h = Math.max(1, y * (height - 2))
                var top = Math.round(height - h)
                ctx.fillRect(xPx, top, root.pixelStep, 2)
                if (prevY !== null && prevY !== top) {
                    var lo = Math.min(prevY, top)
                    var hi = Math.max(prevY, top)
                    ctx.fillRect(xPx, lo, 2, hi - lo + 2)
                }
                prevY = top
            }
        }
        Connections {
            target: root
            function onPointsChanged() { trace.requestPaint() }
            function onTraceColorChanged() { trace.requestPaint() }
            function onPixelStepChanged() { trace.requestPaint() }
        }
    }
}
