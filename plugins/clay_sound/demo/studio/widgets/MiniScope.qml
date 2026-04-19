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
    // Horizontal block width — chunky low-res look. 1 = smooth.
    property int   pixelStep: 3
    // Gap between horizontal blocks (adds the CRT "pixel grid" feel).
    property int   pixelGap: 1
    // Vertical quantization: amplitudes snap to N discrete steps per
    // half-height. 0 = no snap.
    property int   vSteps: 14
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
            var cy = Math.round(height / 2)
            var blockW = Math.max(1, root.pixelStep)
            var gap    = Math.max(0, root.pixelGap)
            var stride = blockW + gap
            var cols   = Math.max(1, Math.floor(width / stride))
            var span   = n / cols
            var halfH  = cy - 2
            var vSnap  = root.vSteps > 0 ? root.vSteps : 0

            for (var c = 0; c < cols; ++c) {
                var start = Math.floor(c * span)
                var end   = Math.max(start + 1, Math.floor((c + 1) * span))
                if (end > n) end = n
                var peak = 0
                for (var i = start; i < end; ++i) {
                    var v = root.samples[i]
                    if (Math.abs(v) > Math.abs(peak)) peak = v
                }
                // Vertical quantise: snap peak to N discrete levels per half.
                if (vSnap > 0) {
                    var sign = peak >= 0 ? 1 : -1
                    var q = Math.round(Math.abs(peak) * vSnap) / vSnap
                    peak = sign * q
                }
                var amp = peak * halfH
                var top = cy - Math.max(0, amp)
                var bot = cy - Math.min(0, amp)
                var xPx = c * stride
                if (top < cy) {
                    ctx.fillStyle = root.traceColor
                    ctx.fillRect(xPx, Math.round(top), blockW, Math.max(2, Math.round(cy - top)))
                }
                if (bot > cy) {
                    ctx.fillStyle = root.traceDim
                    ctx.fillRect(xPx, Math.round(cy), blockW, Math.max(2, Math.round(bot - cy)))
                }
            }
        }
        Connections {
            target: root
            function onSamplesChanged()   { trace.requestPaint() }
            function onPixelStepChanged() { trace.requestPaint() }
            function onPixelGapChanged()  { trace.requestPaint() }
            function onVStepsChanged()    { trace.requestPaint() }
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
