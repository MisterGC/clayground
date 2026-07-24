// (c) Clayground Contributors - MIT License, see "LICENSE" file

import QtQuick

/*!
    \qmltype Plot2D
    \inqmlmodule Clayground.Lab
    \brief Live time-series plot of probe samples.

    Autoscaled strip chart over a sliding sim-time window, one colored
    series per probe with a legend showing the latest values.

    Example usage:
    \qml
    import Clayground.Lab

    Plot2D {
        anchors.bottom: parent.bottom
        width: parent.width; height: 150
        probes: ["kineticEnergy", "avgHeight"]
    }
    \endqml

    \sa Probe, Lab
*/
Rectangle {
    id: _plot

    /*!
        \qmlproperty var Plot2D::probes
        \brief Probe names to draw (empty = all registered probes).
    */
    property var probes: []

    /*!
        \qmlproperty real Plot2D::windowSeconds
        \brief Width of the sliding sim-time window.
    */
    property real windowSeconds: 20

    /*!
        \qmlproperty var Plot2D::seriesColors
        \brief Colors cycled through per series (Clayground palette).
    */
    property var seriesColors: ["#00d9ff", "#ff3366", "#ffd93d", "#0f9d9a", "#b479ff", "#7dffa8"]

    color: "#e60a0f14"
    border.color: "#5500d9ff"
    border.width: 1
    radius: 6

    Connections {
        target: Lab
        function onSampled(t) { _canvas.requestPaint() }
    }

    Canvas {
        id: _canvas
        anchors.fill: parent
        anchors.margins: 8

        onPaint: {
            const ctx = getContext("2d")
            ctx.clearRect(0, 0, width, height)
            const names = _plot.probes.length ? _plot.probes : Lab.probeNames
            const tNow = Lab.clock ? Lab.clock.time : 0
            const t0 = Math.max(0, tNow - _plot.windowSeconds)
            const t1 = Math.max(tNow, t0 + 1e-6)

            let vMin = Infinity, vMax = -Infinity
            const series = []
            for (const n of names) {
                const pr = Lab.probe(n)
                if (!pr) continue
                const pts = pr.samples.filter(s => s.t >= t0)
                for (const s of pts) {
                    if (s.v < vMin) vMin = s.v
                    if (s.v > vMax) vMax = s.v
                }
                series.push({name: n, pts: pts, unit: pr.unit})
            }
            if (vMin > vMax) { vMin = 0; vMax = 1 }
            if (vMax - vMin < 1e-9) { vMax += 0.5; vMin -= 0.5 }
            const pad = (vMax - vMin) * 0.08
            vMin -= pad; vMax += pad

            ctx.strokeStyle = "#1affffff"
            ctx.lineWidth = 1
            for (let i = 1; i < 4; ++i) {
                const y = height * i / 4
                ctx.beginPath(); ctx.moveTo(0, y); ctx.lineTo(width, y); ctx.stroke()
            }

            const xOf = t => (t - t0) / (t1 - t0) * width
            const yOf = v => height - (v - vMin) / (vMax - vMin) * height

            for (let i = 0; i < series.length; ++i) {
                const s = series[i]
                if (s.pts.length < 2) continue
                ctx.strokeStyle = _plot.seriesColors[i % _plot.seriesColors.length]
                ctx.lineWidth = 1.5
                ctx.beginPath()
                ctx.moveTo(xOf(s.pts[0].t), yOf(s.pts[0].v))
                for (let k = 1; k < s.pts.length; ++k)
                    ctx.lineTo(xOf(s.pts[k].t), yOf(s.pts[k].v))
                ctx.stroke()
            }

            ctx.font = "10px sans-serif"
            ctx.fillStyle = "#889099"
            ctx.fillText(vMax.toFixed(2), 4, 12)
            ctx.fillText(vMin.toFixed(2), 4, height - 4)
            for (let i = 0; i < series.length; ++i) {
                const s = series[i]
                const last = s.pts.length ? s.pts[s.pts.length - 1].v : 0
                ctx.fillStyle = _plot.seriesColors[i % _plot.seriesColors.length]
                ctx.fillText(s.name + ": " + last.toFixed(2) + (s.unit ? " " + s.unit : ""),
                             70 + i * 150, 12)
            }
        }
    }
}
