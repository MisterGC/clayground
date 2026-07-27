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
        \qmlproperty var Plot2D::series
        \brief Explicit series as \c {[{probe, label, color}]}, overriding \l probes.

        Use this when the plotted set is built at runtime and the lab owns the
        naming and colouring - a probe name like \c "part7" then still reads as
        "BULB 2" in the legend, in the same colour the lab marks that part with
        elsewhere. \c label and \c color are optional (probe name and the
        cycled \l seriesColors are the fallbacks). With series set, legend
        entries become clickable and emit \l seriesClicked.

        Null (the default) hands control back to \l probes. An \e empty array
        is not the same thing: it means the lab has nothing to plot right now,
        and \l placeholder is drawn instead of falling back to every probe.
    */
    property var series: null

    /*!
        \qmlproperty string Plot2D::placeholder
        \brief Text drawn centred while there is nothing to plot.
    */
    property string placeholder: ""

    /*!
        \qmlsignal Plot2D::seriesClicked(string probe)
        \brief A legend entry was clicked (only with \l series set).

        Labs use this to let the user drop a curve straight from the legend.
    */
    signal seriesClicked(string probe)

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

    // legend hit boxes, filled while painting: {probe, x, w}
    property var _legendHits: []
    property int _hoverIndex: -1

    onSeriesChanged: _canvas.requestPaint()
    onProbesChanged: _canvas.requestPaint()
    onPlaceholderChanged: _canvas.requestPaint()

    color: LabTheme.panel
    border.color: LabTheme.panelEdge
    border.width: LabTheme.borderWidth
    radius: LabTheme.radius

    Connections {
        target: Lab
        function onSampled(t) { _canvas.requestPaint() }
    }
    Connections {
        target: LabLang
        function onLangChanged() { _canvas.requestPaint() }
    }

    Canvas {
        id: _canvas
        anchors.fill: parent
        anchors.margins: 8
        clip: true      // a long placeholder or legend must stay in the panel

        onPaint: {
            const ctx = getContext("2d")
            ctx.clearRect(0, 0, width, height)
            // explicit series win: the lab then owns label and colour, and the
            // legend becomes a set of remove buttons
            const driven = _plot.series !== null && _plot.series !== undefined
            const entries = driven ? _plot.series
                : (_plot.probes.length ? _plot.probes : Lab.probeNames)
                    .map(n => ({ probe: n }))
            const tNow = Lab.clock ? Lab.clock.time : 0
            const t0 = Math.max(0, tNow - _plot.windowSeconds)
            const t1 = Math.max(tNow, t0 + 1e-6)

            let vMin = Infinity, vMax = -Infinity
            const series = []
            for (let ei = 0; ei < entries.length; ++ei) {
                const en = entries[ei]
                const pr = Lab.probe(en.probe)
                if (!pr) continue
                const pts = pr.samples.filter(s => s.t >= t0)
                for (const s of pts) {
                    if (s.v < vMin) vMin = s.v
                    if (s.v > vMax) vMax = s.v
                }
                series.push({probe: en.probe, name: en.label ? en.label : en.probe,
                             pts: pts, unit: pr.unit,
                             color: en.color ? String(en.color)
                                  : _plot.seriesColors[series.length % _plot.seriesColors.length]})
            }
            _plot._legendHits = []
            if (series.length === 0 && _plot.placeholder !== "") {
                ctx.fillStyle = LabTheme.inkFaint.toString()
                // quoted: a family with a space in it ("Patrick Hand",
                // "DejaVu Sans Mono") is not a valid CSS font shorthand
                // unquoted, and Context2D rejects the whole declaration
                ctx.font = '13px "' + LabTheme.handFont + '"'
                ctx.textAlign = "center"
                ctx.fillText(_plot.placeholder, width / 2, height / 2 + 4)
                ctx.textAlign = "left"
                return
            }
            if (vMin > vMax) { vMin = 0; vMax = 1 }
            if (vMax - vMin < 1e-9) { vMax += 0.5; vMin -= 0.5 }
            const pad = (vMax - vMin) * 0.08
            vMin -= pad; vMax += pad

            // Legend band on top, axis gutter on the left: the curves get a
            // rect of their own so a spike can never run through a label.
            ctx.font = '10px "' + LabTheme.monoFont + '"'
            // a flat-zero series must not read as "-0.00", and the decimal
            // separator follows the lab's language
            const fmt = v => LabLang.num(Math.abs(v) < 5e-3 ? 0 : v, 2)
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
                ctx.strokeStyle = s.color
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

            const clickable = driven
            const hits = []
            let lx = gutter
            for (let i = 0; i < series.length; ++i) {
                const s = series[i]
                const last = s.pts.length ? s.pts[s.pts.length - 1].v : 0
                let txt = s.name + ": " + LabLang.num(last, 2) + (s.unit ? " " + s.unit : "")
                if (clickable && _plot._hoverIndex === i) txt += " ×"
                const w = ctx.measureText(txt).width
                if (lx + w > width - padR) break
                ctx.fillStyle = s.color
                ctx.fillText(txt, lx, 11)
                if (clickable) hits.push({ probe: s.probe, x: lx - 4, w: w + 8 })
                lx += w + 16
            }
            _plot._legendHits = hits
        }
    }

    // The legend doubles as the remove control: a curve is dropped where it is
    // named, so no extra list UI is needed to manage what is being watched.
    MouseArea {
        id: _legendArea
        x: _canvas.x; y: _canvas.y
        width: _canvas.width; height: 20
        enabled: _plot.series !== null && _plot.series !== undefined
        hoverEnabled: enabled
        cursorShape: _plot._hoverIndex >= 0 ? Qt.PointingHandCursor : Qt.ArrowCursor

        function indexAt(mx) {
            const hits = _plot._legendHits
            for (let i = 0; i < hits.length; ++i)
                if (mx >= hits[i].x && mx <= hits[i].x + hits[i].w) return i
            return -1
        }
        function setHover(i) {
            if (_plot._hoverIndex === i) return
            _plot._hoverIndex = i
            _canvas.requestPaint()
        }
        onPositionChanged: (m) => setHover(indexAt(m.x))
        onExited: setHover(-1)
        onClicked: (m) => {
            const i = indexAt(m.x)
            if (i >= 0) _plot.seriesClicked(_plot._legendHits[i].probe)
        }
    }
}
