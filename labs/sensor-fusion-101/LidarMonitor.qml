// (c) Clayground Contributors - MIT License, see "LICENSE" file

import QtQuick
import Clayground.Lab

// The lidar argument in one panel, top-down and heading-up, in three reads:
//
//   1. the raw scan      - a silhouette of nearby surfaces. Relative geometry
//                          only: it says what is around the car, never where
//                          the car is.
//   2. the map           - surveyed landmarks as hollow markers. A marker fills
//                          in when a detection was associated with it; a marker
//                          greys out when it is in range but hidden.
//   3. the derived fix   - the crosshair. It only exists because 1 was matched
//                          against 2, and its offset from the car is the live
//                          error (magnified, or it would be a sub-pixel).
//
// Everything drawn here comes from the sensor itself - the same scan, the same
// map, the same associations that produce the fix - so the picture cannot drift
// away from the computation.
LabPanel {
    id: _mon

    property var carPose: ({x: 0, y: 0, heading: 0})
    property var lidar: null
    // dense enough that the near faces read as surfaces rather than specks:
    // a lidar sees the FAÇADE, while the map entry is the building's centre,
    // and that offset is a thing worth being able to see
    property int rays: 360
    /*! Error magnification for the derived-position crosshair. */
    property real errorMag: 10

    readonly property bool live: lidar && lidar.enabled
    readonly property bool fixing: lidar && lidar.available

    width: 250
    title: LabLang.t("monitor.title")
    tag: "M"
    spacing: 6

    Connections {
        target: Lab
        function onSampled(t) { _canvas.requestPaint() }
    }

    Canvas {
        id: _canvas
        // the panel's body, by id: `parent` here is the panel's stacking
        // column, which is a generation too deep to anchor across
        width: _mon.body.width
        height: 210

        onPaint: {
            const ctx = getContext("2d")
            ctx.clearRect(0, 0, width, height)
            const cx = width / 2, cy = height / 2
            const range = _mon.lidar ? _mon.lidar.range : 20
            const k = Math.min(cx, cy) / range
            const teal = LabTheme.teal.toString()

            // heading-up projection: forward is up the panel
            const pose = _mon.carPose
            const sh = Math.sin(pose.heading), ch = Math.cos(pose.heading)
            function toScreen(wx, wy, mag) {
                const dx = (wx - pose.x) * (mag || 1), dz = (wy - pose.y) * (mag || 1)
                return { x: cx + k * (dx * ch - dz * sh),
                         y: cy - k * (dx * sh + dz * ch) }
            }
            function polar(r, bearing) {
                return { x: cx + k * r * Math.sin(bearing),
                         y: cy - k * r * Math.cos(bearing) }
            }

            ctx.strokeStyle = LabTheme.grid.toString()
            ctx.lineWidth = 1
            for (const rr of [0.5, 1.0]) {
                ctx.beginPath()
                ctx.arc(cx, cy, k * range * rr, 0, 2 * Math.PI)
                ctx.stroke()
            }

            // car marker, forward = up
            ctx.fillStyle = LabTheme.highlight.toString()
            ctx.beginPath()
            ctx.moveTo(cx, cy - 6); ctx.lineTo(cx - 4, cy + 4); ctx.lineTo(cx + 4, cy + 4)
            ctx.closePath(); ctx.fill()

            if (!_mon.live) return

            // --- read 1: the raw scan, faint. Shape without meaning. --------
            ctx.globalAlpha = 0.7
            ctx.fillStyle = LabTheme.inkSoft.toString()
            for (const p of _mon.lidar.scan(_mon.rays)) {
                const s = polar(p.range, p.bearing)
                ctx.fillRect(s.x - 1.25, s.y - 1.25, 2.5, 2.5)
            }
            ctx.globalAlpha = 1

            // --- read 2: the map, and which of it is usable ------------------
            // in range but occluded: known, and deliberately not used
            ctx.strokeStyle = LabTheme.muted.toString()
            ctx.lineWidth = 1
            for (const lm of _mon.lidar.hidden) {
                const s = toScreen(lm.x, lm.y)
                ctx.strokeRect(s.x - 4, s.y - 4, 8, 8)
            }
            // associated: the map entry, the detection, and the link between
            for (const d of _mon.lidar.detections) {
                const m = toScreen(d.x, d.y)
                const h = polar(d.range, d.bearing)
                ctx.strokeStyle = teal
                ctx.lineWidth = 1.5
                ctx.strokeRect(m.x - 5, m.y - 5, 10, 10)

                ctx.globalAlpha = 0.55
                ctx.beginPath()
                ctx.moveTo(cx, cy); ctx.lineTo(h.x, h.y)
                ctx.stroke()
                ctx.globalAlpha = 1

                ctx.fillStyle = teal
                ctx.beginPath()
                ctx.arc(h.x, h.y, 2.5, 0, 2 * Math.PI)
                ctx.fill()
            }

            // --- read 3: the position that falls out of the matching ---------
            const fix = _mon.lidar.lastFix
            if (!_mon.fixing || !fix) return
            const f = toScreen(fix.x, fix.y, _mon.errorMag)
            const arm = 7
            ctx.strokeStyle = teal
            ctx.lineWidth = 1.5
            ctx.beginPath()
            ctx.moveTo(f.x - arm, f.y); ctx.lineTo(f.x + arm, f.y)
            ctx.moveTo(f.x, f.y - arm); ctx.lineTo(f.x, f.y + arm)
            ctx.stroke()
            ctx.globalAlpha = 0.6
            ctx.beginPath()
            ctx.arc(f.x, f.y, 3.5, 0, 2 * Math.PI)
            ctx.stroke()
            ctx.globalAlpha = 1
        }
    }

    // the three reads, named
    Row {
        spacing: 10
        Row {
            spacing: 4
            Rectangle {
                width: 9; height: 9; color: "transparent"
                border.color: LabTheme.teal; border.width: 1.5
                anchors.verticalCenter: parent.verticalCenter
            }
            Text {
                text: LabLang.t("sensor.map"); color: LabTheme.inkFaint
                font.pixelSize: 10; font.family: LabTheme.monoFont
            }
        }
        Row {
            spacing: 4
            Rectangle {
                width: 7; height: 7; radius: 4; color: LabTheme.teal
                anchors.verticalCenter: parent.verticalCenter
            }
            Text {
                text: LabLang.t("sensor.detected"); color: LabTheme.inkFaint
                font.pixelSize: 10; font.family: LabTheme.monoFont
            }
        }
        Row {
            spacing: 4
            Text {
                text: "✛"; color: LabTheme.teal
                font.pixelSize: 11; font.family: LabTheme.monoFont
                anchors.verticalCenter: parent.verticalCenter
            }
            Text {
                text: LabLang.tf("monitor.errorMag", _mon.errorMag.toFixed(0))
                color: LabTheme.inkFaint
                font.pixelSize: 10; font.family: LabTheme.monoFont
            }
        }
    }

    Rectangle { width: _mon.body.width; height: 1; color: LabTheme.panelEdge }

    // the causal chain, mirroring the GPS line in the legend
    Text {
        width: _mon.body.width
        text: _mon.fixing
              ? LabLang.tf("monitor.chain", _mon.lidar.usedCount,
                           LabLang.num(_mon.lidar.dop, 1),
                           LabLang.num(_mon.lidar.posSigma, 2))
              : (_mon.live ? LabLang.t("sensor.noFix")
                           : LabLang.t("sensor.lidar") + " " + LabLang.t("sensor.off"))
        color: _mon.fixing ? LabTheme.ink : LabTheme.alarm
        font.pixelSize: 11; font.bold: true
        font.family: LabTheme.monoFont
    }
    Text {
        width: _mon.body.width
        wrapMode: Text.WordWrap
        text: _mon.fixing
              ? LabLang.t("monitor.why")
              : (_mon.live ? LabLang.tf("monitor.none",
                                        _mon.lidar ? _mon.lidar.minLandmarks : 2)
                           : LabLang.t("monitor.off"))
        color: LabTheme.inkFaint; font.pixelSize: 11
        font.family: LabTheme.handFont
    }
}
