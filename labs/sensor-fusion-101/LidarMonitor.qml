// (c) Clayground Contributors - MIT License, see "LICENSE" file

import QtQuick
import Clayground.Lab

// Top-down, heading-up scan monitor: rays cast against the world's boxes,
// points classified by what they hit (building teal, tunnel wall pink).
// Jitter is hash-based, not RNG-stream-based, so the monitor never
// disturbs the lab's determinism contract.
Rectangle {
    id: _mon

    property var carPose: ({x: 0, y: 0, heading: 0})
    property var lidar: null
    property var buildings: []
    property bool tunnelOn: false
    property int rays: 120

    width: 240
    height: 264
    color: "#e60a0f14"
    border.color: "#5500d9ff"
    border.width: 1
    radius: 6

    Text {
        x: 12; y: 8
        text: "LIDAR SCAN"
        color: "#00d9ff"; font.pixelSize: 12; font.bold: true; font.letterSpacing: 1.5
    }
    Text {
        anchors.right: parent.right; anchors.rightMargin: 12; y: 8
        text: _mon.lidar && _mon.lidar.enabled ? _mon.lidar.range.toFixed(0) + " m" : "OFFLINE"
        color: _mon.lidar && _mon.lidar.enabled ? "#889099" : "#ff3366"
        font.pixelSize: 11
    }

    Connections {
        target: Lab
        function onSampled(t) { _canvas.requestPaint() }
    }

    function _rayBox(ox, oy, dx, dy, minx, miny, maxx, maxy) {
        let tmin = -Infinity, tmax = Infinity
        if (Math.abs(dx) < 1e-9) {
            if (ox < minx || ox > maxx) return -1
        } else {
            let t1 = (minx - ox) / dx, t2 = (maxx - ox) / dx
            if (t1 > t2) { const s = t1; t1 = t2; t2 = s }
            tmin = Math.max(tmin, t1); tmax = Math.min(tmax, t2)
        }
        if (Math.abs(dy) < 1e-9) {
            if (oy < miny || oy > maxy) return -1
        } else {
            let t1 = (miny - oy) / dy, t2 = (maxy - oy) / dy
            if (t1 > t2) { const s = t1; t1 = t2; t2 = s }
            tmin = Math.max(tmin, t1); tmax = Math.min(tmax, t2)
        }
        if (tmax < Math.max(tmin, 0)) return -1
        return tmin > 0 ? tmin : -1
    }

    Canvas {
        id: _canvas
        anchors.fill: parent
        anchors.topMargin: 28
        anchors.margins: 10

        onPaint: {
            const ctx = getContext("2d")
            ctx.clearRect(0, 0, width, height)
            const cx = width / 2, cy = height / 2
            const range = _mon.lidar ? _mon.lidar.range : 20
            const k = Math.min(cx, cy) / range

            ctx.strokeStyle = "#1e2c3d"
            ctx.lineWidth = 1
            for (const rr of [0.5, 1.0]) {
                ctx.beginPath()
                ctx.arc(cx, cy, k * range * rr, 0, 2 * Math.PI)
                ctx.stroke()
            }

            // car marker, forward = up
            ctx.fillStyle = "#ffd93d"
            ctx.beginPath()
            ctx.moveTo(cx, cy - 6); ctx.lineTo(cx - 4, cy + 4); ctx.lineTo(cx + 4, cy + 4)
            ctx.closePath(); ctx.fill()

            if (!_mon.lidar || !_mon.lidar.enabled) return

            const pose = _mon.carPose
            const sigma = _mon.lidar.sigmaM
            const scanIdx = Lab.clock ? Math.floor(Lab.clock.time * _mon.lidar.rateHz) : 0
            const boxes = []
            for (const b of _mon.buildings)
                boxes.push({minx: b.x - 2, miny: b.y - 2, maxx: b.x + 2, maxy: b.y + 2, cls: "building"})
            if (_mon.tunnelOn)
                boxes.push({minx: -11, miny: -17.5, maxx: 11, maxy: -10.5, cls: "tunnel"})

            for (let i = 0; i < _mon.rays; ++i) {
                const local = i / _mon.rays * 2 * Math.PI
                const world = pose.heading + local
                const dx = Math.cos(world), dy = Math.sin(world)
                let best = -1, cls = ""
                for (const b of boxes) {
                    const t = _mon._rayBox(pose.x, pose.y, dx, dy, b.minx, b.miny, b.maxx, b.maxy)
                    if (t > 0 && (best < 0 || t < best)) { best = t; cls = b.cls }
                }
                const sx = s => cx + k * s * Math.sin(local)
                const sy = s => cy - k * s * Math.cos(local)
                if (best > 0 && best <= range) {
                    // deterministic hash jitter (no shared-RNG consumption)
                    const h = Math.sin(i * 127.1 + scanIdx * 311.7) * 43758.5453
                    const r = best + (h - Math.floor(h) - 0.5) * 2 * sigma
                    ctx.fillStyle = cls === "tunnel" ? "#ff3366" : "#0f9d9a"
                    ctx.fillRect(sx(r) - 1.5, sy(r) - 1.5, 3, 3)
                } else {
                    ctx.fillStyle = "#14ffffff"
                    ctx.fillRect(sx(range) - 0.5, sy(range) - 0.5, 1, 1)
                }
            }
        }
    }

    Row {
        anchors.bottom: parent.bottom; anchors.bottomMargin: 6
        anchors.horizontalCenter: parent.horizontalCenter
        spacing: 12
        Row { spacing: 4
            Rectangle { width: 8; height: 8; radius: 2; color: "#0f9d9a"; anchors.verticalCenter: parent.verticalCenter }
            Text { text: "building"; color: "#889099"; font.pixelSize: 10 }
        }
        Row { spacing: 4
            Rectangle { width: 8; height: 8; radius: 2; color: "#ff3366"; anchors.verticalCenter: parent.verticalCenter }
            Text { text: "tunnel"; color: "#889099"; font.pixelSize: 10 }
        }
    }
}
