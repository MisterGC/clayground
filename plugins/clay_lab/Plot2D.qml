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
        \brief Colors cycled through per series (LabTheme paper set).
    */
    property var seriesColors: LabTheme.seriesColors

    color: LabTheme.panel
    border.color: LabTheme.panelEdge
    border.width: LabTheme.borderWidth
    radius: LabTheme.radius

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

            // Legend band on top, axis gutter on the left: the curves get a
            // rect of their own so a spike can never run through a label.
            ctx.font = "10px " + LabTheme.monoFont
            // a flat-zero series must not read as "-0.00"
            const fmt = v => (Math.abs(v) < 5e-3 ? 0 : v).toFixed(2)
            const ticks = [vMax, (vMax + vMin) / 2, vMin].map(fmt)
            let gutter = 0
            for (const tk of ticks) gutter = Math.max(gutter, ctx.measureText(tk).width)
            gutter += 8

            const padT = 16, padB = 6, padR = 4
            const pw = Math.max(1, width - gutter - padR)
            const ph = Math.max(1, height - padT - padB)

            ctx.strokeStyle = LabTheme.grid.toString()
            ctx.lineWidth = 1
            for (let i = 0; i <= 2; ++i) {
                const y = Math.round(padT + ph * i / 2) + 0.5
                ctx.beginPath(); ctx.moveTo(gutter, y); ctx.lineTo(gutter + pw, y); ctx.stroke()
            }

            const xOf = t => gutter + (t - t0) / (t1 - t0) * pw
            const yOf = v => padT + ph - (v - vMin) / (vMax - vMin) * ph

            ctx.save()
            ctx.beginPath(); ctx.rect(gutter, padT, pw, ph); ctx.clip()
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
            ctx.restore()

            ctx.fillStyle = LabTheme.inkFaint.toString()
            for (let i = 0; i <= 2; ++i) {
                const y = padT + ph * i / 2
                ctx.fillText(ticks[i], gutter - 6 - ctx.measureText(ticks[i]).width,
                             y + (i === 0 ? 8 : (i === 2 ? 0 : 4)))
            }

            let lx = gutter
            for (let i = 0; i < series.length; ++i) {
                const s = series[i]
                const last = s.pts.length ? s.pts[s.pts.length - 1].v : 0
                const txt = s.name + ": " + last.toFixed(2) + (s.unit ? " " + s.unit : "")
                const w = ctx.measureText(txt).width
                if (lx + w > width - padR) break
                ctx.fillStyle = _plot.seriesColors[i % _plot.seriesColors.length]
                ctx.fillText(txt, lx, 11)
                lx += w + 16
            }
        }
    }
}
