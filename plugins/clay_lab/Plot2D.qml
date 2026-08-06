// (c) Clayground Contributors - MIT License, see "LICENSE" file

import QtQuick

/*!
    \qmltype Plot2D
    \inqmlmodule Clayground.Lab
    \brief Live time-series plot of probe samples: lines, scatter, uncertainty bands.

    Autoscaled strip chart over a sliding sim-time window, one colored
    series per probe with a legend showing the latest values. Hover the chart
    and it reads back every visible series at the sample nearest the cursor,
    which is the difference between "the curves crossed somewhere here" and a
    number you can write down.

    Example usage:
    \qml
    import Clayground.Lab

    Plot2D {
        anchors.bottom: parent.bottom
        width: parent.width; height: 150
        probes: ["kineticEnergy", "avgHeight"]
    }

    Plot2D {                                     // a fix and what it is worth
        series: [{ probe: "estimate", label: "fused", color: LabTheme.secondary,
                   sigmaProbe: "estimateSigma" },
                 { probe: "gpsFix", label: "GPS", color: LabTheme.rose,
                   style: "scatter" }]
    }
    \endqml

    \sa Probe, Lab, WatchMonitor
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
        \brief Explicit series as \c {[{probe, label, color, style, sigmaProbe}]},
        overriding \l probes.

        Use this when the plotted set is built at runtime and the lab owns the
        naming and colouring - a probe name like \c "part7" then still reads as
        "BULB 2" in the legend, in the same colour the lab marks that part with
        elsewhere. \c label and \c color are optional (probe name and the
        cycled \l seriesColors are the fallbacks). With series set, legend
        entries become clickable and emit \l seriesClicked.

        Two optional keys change how a series is drawn:

        \list
        \li \c style - \c "line" (the default) or \c "scatter". A quantity that
            arrives in discrete events - a GPS fix, a measurement, a spawn -
            is not a curve, and joining its samples with a line invents values
            between them that were never measured.
        \li \c sigmaProbe - the name of a probe carrying this series'
            uncertainty. The band \c {value ± sigma} is filled translucently
            behind the curve, so "the estimate is here" and "the estimate is
            worth this much" are one picture instead of two panels.
        \endlist

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

    /*!
        \qmlproperty bool Plot2D::cursorReadout
        \brief Read every series back at the hovered sample.
    */
    property bool cursorReadout: true

    // legend hit boxes, filled while painting: {probe, x, w}
    property var _legendHits: []
    property int _hoverIndex: -1
    // cursor position in canvas pixels, or -1 while the pointer is away
    property real _cursorX: -1
    property real _cursorY: -1

    onSeriesChanged: _canvas.requestPaint()
    onProbesChanged: _canvas.requestPaint()
    onPlaceholderChanged: _canvas.requestPaint()
    on_CursorXChanged: _canvas.requestPaint()

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
    Connections {
        target: LabTheme
        function onModeChanged() { _canvas.requestPaint() }
        function onUiScaleChanged() { _canvas.requestPaint() }
    }

    Canvas {
        id: _canvas
        anchors.fill: parent
        anchors.margins: LabTheme.spaceL
        clip: true      // a long placeholder or legend must stay in the panel

        // the legend band's height, so the two hit areas agree on where the
        // legend stops and the chart starts
        readonly property real bandHeight: LabTheme.fontMicro + LabTheme.spaceL

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
                // an uncertainty band widens the axis: a curve that leaves its
                // own band would be a plot lying about what it shows
                const sigPr = en.sigmaProbe ? Lab.probe(en.sigmaProbe) : null
                const sig = sigPr ? sigPr.samples.filter(s => s.t >= t0) : null
                for (let k = 0; k < pts.length; ++k) {
                    const s = pts[k]
                    const w = sig ? _sigmaAt(sig, s.t) : 0
                    if (s.v - w < vMin) vMin = s.v - w
                    if (s.v + w > vMax) vMax = s.v + w
                }
                series.push({probe: en.probe, name: en.label ? en.label : en.probe,
                             pts: pts, unit: pr.unit, sig: sig,
                             scatter: en.style === "scatter",
                             color: en.color ? String(en.color)
                                  : _plot.seriesColors[series.length % _plot.seriesColors.length]})
            }
            _plot._legendHits = []
            if (series.length === 0 && _plot.placeholder !== "") {
                ctx.fillStyle = LabTheme.inkFaint.toString()
                // quoted: a family with a space in it ("Patrick Hand",
                // "DejaVu Sans Mono") is not a valid CSS font shorthand
                // unquoted, and Context2D rejects the whole declaration
                ctx.font = LabTheme.fontLabel + 'px "' + LabTheme.handFont + '"'
                ctx.textAlign = "center"
                ctx.fillText(_plot.placeholder, width / 2, height / 2 + LabTheme.spaceS)
                ctx.textAlign = "left"
                return
            }
            if (vMin > vMax) { vMin = 0; vMax = 1 }
            if (vMax - vMin < 1e-9) { vMax += 0.5; vMin -= 0.5 }
            const pad = (vMax - vMin) * 0.08
            vMin -= pad; vMax += pad

            // Legend band on top, axis gutter on the left: the curves get a
            // rect of their own so a spike can never run through a label.
            ctx.font = LabTheme.fontMicro + 'px "' + LabTheme.monoFont + '"'
            // a flat-zero series must not read as "-0.00", and the decimal
            // separator follows the lab's language
            const fmt = v => LabLang.num(Math.abs(v) < 5e-3 ? 0 : v, 2)
            const ticks = [vMax, (vMax + vMin) / 2, vMin].map(fmt)
            let gutter = 0
            for (const tk of ticks) gutter = Math.max(gutter, ctx.measureText(tk).width)
            gutter += LabTheme.spaceL

            const padT = _canvas.bandHeight
            const padB = LabTheme.spaceM, padR = LabTheme.spaceS
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

            // bands first, behind every curve: the uncertainty is the ground
            // the estimates are drawn on, not something layered over them
            for (let i = 0; i < series.length; ++i) {
                const s = series[i]
                if (!s.sig || s.pts.length < 2) continue
                ctx.fillStyle = _plot._translucent(s.color, 0.22)
                ctx.beginPath()
                for (let k = 0; k < s.pts.length; ++k) {
                    const p = s.pts[k], w = _sigmaAt(s.sig, p.t)
                    const x = xOf(p.t), y = yOf(p.v + w)
                    if (k === 0) ctx.moveTo(x, y); else ctx.lineTo(x, y)
                }
                for (let k = s.pts.length - 1; k >= 0; --k) {
                    const p = s.pts[k], w = _sigmaAt(s.sig, p.t)
                    ctx.lineTo(xOf(p.t), yOf(p.v - w))
                }
                ctx.closePath()
                ctx.fill()
            }

            const dot = Math.max(1.5, LabTheme.px(2.2))
            for (let i = 0; i < series.length; ++i) {
                const s = series[i]
                if (s.scatter) {
                    // discrete events stay discrete: no line is drawn between
                    // two fixes, because nothing was measured in between
                    ctx.fillStyle = s.color
                    for (let k = 0; k < s.pts.length; ++k) {
                        ctx.beginPath()
                        ctx.arc(xOf(s.pts[k].t), yOf(s.pts[k].v), dot, 0, 2 * Math.PI)
                        ctx.fill()
                    }
                    continue
                }
                if (s.pts.length < 2) continue
                ctx.strokeStyle = s.color
                ctx.lineWidth = Math.max(1, LabTheme.px(1.5))
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
                ctx.fillText(ticks[i], gutter - LabTheme.spaceM - ctx.measureText(ticks[i]).width,
                             y + (i === 0 ? LabTheme.fontMicro * 0.8
                                : (i === 2 ? 0 : LabTheme.fontMicro * 0.4)))
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
                ctx.fillText(txt, lx, LabTheme.fontMicro + 1)
                if (clickable) hits.push({ probe: s.probe, x: lx - LabTheme.spaceS,
                                           w: w + 2 * LabTheme.spaceS })
                lx += w + LabTheme.spaceXxl
            }
            _plot._legendHits = hits

            // --- the cursor readout ----------------------------------------
            if (_plot.cursorReadout && _plot._cursorX >= gutter
                && _plot._cursorX <= gutter + pw && series.length > 0) {
                const cx = _plot._cursorX
                const tAt = t0 + (cx - gutter) / pw * (t1 - t0)
                ctx.strokeStyle = LabTheme.inkFaint.toString()
                ctx.lineWidth = 1
                ctx.beginPath()
                ctx.moveTo(Math.round(cx) + 0.5, padT)
                ctx.lineTo(Math.round(cx) + 0.5, padT + ph)
                ctx.stroke()

                const rows = []
                for (const s of series) {
                    const p = _nearest(s.pts, tAt)
                    if (!p) continue
                    rows.push({ color: s.color,
                                text: s.name + " " + LabLang.num(p.v, 2)
                                      + (s.unit ? " " + s.unit : ""),
                                v: p.v })
                    ctx.fillStyle = s.color
                    ctx.beginPath()
                    ctx.arc(xOf(p.t), yOf(p.v), dot + 1, 0, 2 * Math.PI)
                    ctx.fill()
                }
                if (rows.length > 0) {
                    const lh = LabTheme.fontMicro + LabTheme.spaceS
                    let bw = ctx.measureText("t " + LabLang.num(tAt, 2)).width
                    for (const r of rows) bw = Math.max(bw, ctx.measureText(r.text).width)
                    bw += 2 * LabTheme.spaceM
                    const bh = (rows.length + 1) * lh + LabTheme.spaceS
                    // flips to the other side of the cursor near the right
                    // edge rather than being clamped onto the curve it reads
                    let bx = cx + LabTheme.spaceM
                    if (bx + bw > width) bx = cx - LabTheme.spaceM - bw
                    let by = Math.min(Math.max(padT, _plot._cursorY - bh / 2),
                                      padT + ph - bh)
                    ctx.fillStyle = LabTheme.panel.toString()
                    ctx.strokeStyle = LabTheme.panelEdge.toString()
                    ctx.lineWidth = LabTheme.borderWidth
                    ctx.beginPath()
                    ctx.rect(bx, by, bw, bh)
                    ctx.fill(); ctx.stroke()
                    let ty = by + LabTheme.spaceS + LabTheme.fontMicro
                    ctx.fillStyle = LabTheme.inkFaint.toString()
                    ctx.fillText("t " + LabLang.num(tAt, 2), bx + LabTheme.spaceM, ty)
                    for (const r of rows) {
                        ty += lh
                        ctx.fillStyle = r.color
                        ctx.fillText(r.text, bx + LabTheme.spaceM, ty)
                    }
                }
            }
        }

        // The sigma series is sampled on the same grid as its value series
        // (both are probes on one clock), so a straight index scan is enough -
        // but never assume it: a lab may add a sigma probe later, with fewer
        // samples than the curve it belongs to.
        function _sigmaAt(sig, t) {
            const p = _nearest(sig, t)
            return p ? Math.abs(p.v) : 0
        }

        function _nearest(pts, t) {
            if (!pts || pts.length === 0) return null
            let best = pts[0], bd = Math.abs(pts[0].t - t)
            for (let i = 1; i < pts.length; ++i) {
                const d = Math.abs(pts[i].t - t)
                if (d < bd) { bd = d; best = pts[i] }
            }
            return best
        }
    }

    // "rgba(r,g,b,a)": Context2D takes a colour object for fillStyle, but not
    // one with an alpha applied after the fact - so the band builds the string.
    function _translucent(c, alpha) {
        const q = Qt.color(c)
        return "rgba(" + Math.round(q.r * 255) + "," + Math.round(q.g * 255)
             + "," + Math.round(q.b * 255) + "," + alpha + ")"
    }

    // The legend doubles as the remove control: a curve is dropped where it is
    // named, so no extra list UI is needed to manage what is being watched.
    MouseArea {
        id: _legendArea
        x: _canvas.x; y: _canvas.y
        width: _canvas.width; height: _canvas.bandHeight
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

    // Everything below the legend band reads values back. Hover only - a
    // click here belongs to whatever the lab put underneath.
    MouseArea {
        id: _cursorArea
        x: _canvas.x
        y: _canvas.y + _canvas.bandHeight
        width: _canvas.width
        height: Math.max(0, _canvas.height - _canvas.bandHeight)
        enabled: _plot.cursorReadout
        hoverEnabled: enabled
        acceptedButtons: Qt.NoButton
        onPositionChanged: (m) => {
            _plot._cursorX = m.x
            _plot._cursorY = m.y + _canvas.bandHeight
        }
        onExited: { _plot._cursorX = -1; _canvas.requestPaint() }
    }
}
