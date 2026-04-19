// (c) Clayground Contributors - MIT License, see "LICENSE" file
//
// Chunky stepped rotary encoder. Drag vertically, or scroll, to change.
//
// Usage:
//   RetroKnob {
//       label: "TUNE"
//       from: -24; to: 24; steps: 48
//       value: inst.pitchEnd
//       onValueChanged: inst.pitchEnd = value
//   }

import QtQuick

Item {
    id: root

    property string label: ""
    property real   from: 0
    property real   to:   1
    property int    steps: 16     // discrete positions
    property real   value: 0
    property color  accent: Retro.teal
    property color  tickDim: Retro.tealLo
    // Arc range (in degrees) the knob sweeps through; 270° looks retro.
    property real   arc: 270

    implicitWidth: 56
    implicitHeight: 64

    signal valueEdited(real v)

    function _quantise(v) {
        if (steps <= 1) return v
        var range = to - from
        var step = range / steps
        var q = Math.round((v - from) / step) * step + from
        return Math.max(from, Math.min(to, q))
    }

    // Normalised position 0..1 from value
    readonly property real _pos:
        (to === from) ? 0 : (value - from) / (to - from)

    // Label above the knob
    Text {
        id: lbl
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        text: root.label
        color: Retro.txtDim
        font.family: Retro.mono
        font.pixelSize: Retro.fsLabel
        font.bold: true
    }

    Item {
        id: knobBody
        anchors.top: lbl.bottom
        anchors.topMargin: 2
        anchors.horizontalCenter: parent.horizontalCenter
        width: Math.min(parent.width, parent.height - lbl.height - 2)
        height: width

        // Tick ring
        Canvas {
            id: ticks
            anchors.fill: parent
            onPaint: {
                var ctx = getContext("2d")
                ctx.reset()
                var cx = width / 2, cy = height / 2
                var rOuter = width * 0.48
                var rInner = width * 0.40
                var arcRad = root.arc * Math.PI / 180
                var start = Math.PI / 2 + (Math.PI - arcRad / 2)  // point at bottom-left
                var n = root.steps
                for (var i = 0; i <= n; ++i) {
                    var t = i / n
                    var a = start + t * arcRad
                    var x1 = cx + rInner * Math.cos(a)
                    var y1 = cy + rInner * Math.sin(a)
                    var x2 = cx + rOuter * Math.cos(a)
                    var y2 = cy + rOuter * Math.sin(a)
                    var lit = t <= root._pos + 0.0001
                    ctx.strokeStyle = lit ? root.accent : root.tickDim
                    ctx.lineWidth = lit ? 2 : 1
                    ctx.beginPath()
                    ctx.moveTo(x1, y1)
                    ctx.lineTo(x2, y2)
                    ctx.stroke()
                }
            }
            Connections {
                target: root
                function onValueChanged() { ticks.requestPaint() }
                function onAccentChanged() { ticks.requestPaint() }
                function onStepsChanged() { ticks.requestPaint() }
            }
        }

        // Knob cap
        Rectangle {
            id: cap
            anchors.centerIn: parent
            width: parent.width * 0.72
            height: width
            radius: width / 2
            color: "#0a0d18"
            border.color: Retro.bevelHi
            border.width: 1
            // inner highlight ring
            Rectangle {
                anchors.centerIn: parent
                width: parent.width - 6
                height: width
                radius: width / 2
                color: "transparent"
                border.color: Retro.bevelLo
                border.width: 1
            }
            // Indicator line pointing to current step
            Canvas {
                id: indicator
                anchors.fill: parent
                onPaint: {
                    var ctx = getContext("2d")
                    ctx.reset()
                    var cx = width / 2, cy = height / 2
                    var arcRad = root.arc * Math.PI / 180
                    var start = Math.PI / 2 + (Math.PI - arcRad / 2)
                    var a = start + root._pos * arcRad
                    var rOut = width * 0.45
                    var rIn  = width * 0.18
                    ctx.strokeStyle = root.accent
                    ctx.lineWidth = 2
                    ctx.beginPath()
                    ctx.moveTo(cx + rIn * Math.cos(a), cy + rIn * Math.sin(a))
                    ctx.lineTo(cx + rOut * Math.cos(a), cy + rOut * Math.sin(a))
                    ctx.stroke()
                }
                Connections {
                    target: root
                    function onValueChanged() { indicator.requestPaint() }
                }
            }
        }

        MouseArea {
            id: ma
            anchors.fill: parent
            property real _dragY: 0
            property real _startValue: 0
            acceptedButtons: Qt.LeftButton
            hoverEnabled: true
            onPressed: (ev) => {
                _dragY = ev.y
                _startValue = root.value
            }
            onPositionChanged: (ev) => {
                if (!pressed) return
                var range = root.to - root.from
                // Dragging 100 px covers full range; hold Shift for fine.
                var dy = _dragY - ev.y
                var scale = (ev.modifiers & Qt.ShiftModifier) ? 400 : 100
                var raw = _startValue + (dy / scale) * range
                var q = root._quantise(raw)
                if (q !== root.value) {
                    root.value = q
                    root.valueEdited(q)
                }
            }
            onWheel: (ev) => {
                var range = root.to - root.from
                var step = range / root.steps
                var direction = ev.angleDelta.y > 0 ? 1 : -1
                var q = root._quantise(root.value + step * direction)
                if (q !== root.value) {
                    root.value = q
                    root.valueEdited(q)
                }
            }
        }
    }
}
