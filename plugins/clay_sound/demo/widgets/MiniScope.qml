// (c) Clayground Contributors - MIT License, see "LICENSE" file
//
// Oscilloscope readout for a synth slot.
//
// Normally driven by a source array of floats (the patch's canonical
// response rendered offline). Draws pixel columns mirrored around the
// vertical centre, so positive peaks go up in `trace` colour and
// negative peaks go down in `traceDim`.
//
// Usage:
//   MiniScope {
//       samples: synthInst.renderOffline(0.25)
//       traceColor: Retro.amber
//       trigger: slot.activeVoices > 0     // flashes briefly
//   }

import QtQuick

Item {
    id: root

    property var   samples: []
    property color traceColor:  Retro.amber
    property color traceDim:    Retro.amberDim
    property color bg:          Retro.inset
    property color gridColor:   "#1a2234"
    // True briefly after a trigger — scope flashes for feedback.
    property bool  trigger: false

    implicitHeight: 48

    Rectangle {
        anchors.fill: parent
        color: root.bg
        border.color: Retro.bevelLo
        border.width: 1
        radius: 2
    }

    // Grid lines
    Canvas {
        anchors.fill: parent
        anchors.margins: 2
        onPaint: {
            var ctx = getContext("2d")
            ctx.reset()
            ctx.strokeStyle = root.gridColor
            ctx.lineWidth = 1
            // centre line + quarter lines
            for (var y of [0.25, 0.5, 0.75]) {
                ctx.beginPath()
                ctx.moveTo(0, height * y)
                ctx.lineTo(width, height * y)
                ctx.stroke()
            }
            for (var i = 1; i < 4; ++i) {
                var x = (width * i) / 4
                ctx.beginPath()
                ctx.moveTo(x, 0)
                ctx.lineTo(x, height)
                ctx.stroke()
            }
        }
    }

    Canvas {
        id: trace
        anchors.fill: parent
        anchors.margins: 2
        onPaint: {
            var ctx = getContext("2d")
            ctx.reset()
            var n = root.samples ? root.samples.length : 0
            if (n === 0) return
            var cy = height / 2
            var step = n / width
            ctx.fillStyle = root.traceColor
            ctx.strokeStyle = root.traceColor
            for (var x = 0; x < width; ++x) {
                // Take the peak absolute value in this pixel's sample
                // slice — pixelated readout that still shows dynamics.
                var start = Math.floor(x * step)
                var end   = Math.min(n, Math.floor((x + 1) * step))
                if (end <= start) end = start + 1
                var peak = 0
                for (var i = start; i < end; ++i) {
                    var v = root.samples[i]
                    if (Math.abs(v) > Math.abs(peak)) peak = v
                }
                // Scale: -1..1 → pixel height
                var amp = peak * (cy - 2)
                var top = cy - Math.max(0, amp)
                var bot = cy - Math.min(0, amp)
                if (top < cy) {
                    ctx.fillStyle = root.traceColor
                    ctx.fillRect(x, Math.round(top), 1, Math.round(cy - top))
                }
                if (bot > cy) {
                    ctx.fillStyle = root.traceDim
                    ctx.fillRect(x, Math.round(cy), 1, Math.round(bot - cy))
                }
            }
        }
        Connections {
            target: root
            function onSamplesChanged() { trace.requestPaint() }
        }
    }

    // Flash overlay on trigger
    Rectangle {
        id: flash
        anchors.fill: parent
        color: root.traceColor
        opacity: 0
        Behavior on opacity { NumberAnimation { duration: 180 } }
    }
    onTriggerChanged: {
        if (trigger) {
            flash.opacity = 0.18
            flashReset.restart()
        }
    }
    Timer {
        id: flashReset
        interval: 60
        onTriggered: flash.opacity = 0
    }
}
