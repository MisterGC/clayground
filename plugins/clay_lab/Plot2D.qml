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

    One axis carries one quantity. Two quantities that must be compared get
    \l strips: stacked charts, each autoscaled on its own axis, sharing one
    time axis and one cursor - the shape of a multi-channel scope.

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

    // A plot is a readout, and focus mode is for when readings are not the
    // point.
    visible: !LabView.focus
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
        \qmlproperty var Plot2D::strips
        \brief Stacked charts as \c {[{label, series}]}, overriding \l series.

        One quantity per axis is the rule; this is how two of them are read
        together anyway. Each entry becomes a strip with an autoscaled axis and
        a legend of its own, stacked top to bottom in the order given, and all
        of them share the time axis, the value gutter and the hover cursor - so
        "the voltage dipped when the current spiked" is one picture, and no
        curve is flattened onto the baseline by a neighbour measured in another
        unit.

        \c label is drawn at the head of the strip, ahead of its legend, and
        only while there is more than one: with a single strip whatever names
        the quantity elsewhere (the WatchMonitor's chip row) already says it,
        and the layout is then pixel-for-pixel the one-quantity chart. It is
        display text - the caller has already put it through \l LabLang.

        The per-series keys are \l series'; \l heightForStrips tells a caller
        how tall the panel has to be for a given number of strips.

        Null (the default) hands control back to \l series.
    */
    property var strips: null

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

    /*!
        \qmlproperty real Plot2D::stripMinChart
        \brief Smallest chart a stacked strip is allowed to shrink to.

        Below roughly this the curve stops being a shape and becomes a line
        with noise on it, so a caller sizing a panel divides what it has down
        to here and then grows instead - see \l heightForStrips.
    */
    property real stripMinChart: LabTheme.px(40)

    /*!
        \qmlproperty real Plot2D::stripBandHeight
        \readonly
        \brief Height of one strip's legend band (its title and latest values).
    */
    readonly property real stripBandHeight: LabTheme.fontMicro + LabTheme.spaceL

    /*!
        \qmlmethod real Plot2D::heightForStrips(int n)
        \brief The height at which \a n strips are still readable.

        The floor, not the wish: a panel takes the larger of its own budget and
        this, so one or two strips cost nothing and only a third one makes the
        panel grow.
    */
    function heightForStrips(n) {
        return 2 * LabTheme.spaceL + LabTheme.spaceM
             + Math.max(1, n) * (stripBandHeight + stripMinChart)
    }

    // legend hit boxes, filled while painting: {probe, x, y, w, h}
    property var _legendHits: []
    // the hovered legend entry, by probe name - an index would have to be
    // re-based every time a strip above it gains or loses a curve
    property string _hoverProbe: ""
    // cursor position in canvas pixels, or -1 while the pointer is away
    property real _cursorX: -1
    property real _cursorY: -1

    onSeriesChanged: _canvas.requestPaint()
    onStripsChanged: _canvas.requestPaint()
    onProbesChanged: _canvas.requestPaint()
    onPlaceholderChanged: _canvas.requestPaint()
    on_CursorXChanged: _canvas.requestPaint()
    on_CursorYChanged: _canvas.requestPaint()

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

        onPaint: {
            const ctx = getContext("2d")
            ctx.clearRect(0, 0, width, height)
            // explicit series win: the lab then owns label and colour, and the
            // legend becomes a set of remove buttons. Strips win over both -
            // the one-quantity chart is then just the one-strip case.
            const stacked = _plot.strips !== null && _plot.strips !== undefined
            const driven = stacked
                || (_plot.series !== null && _plot.series !== undefined)
            const groups = stacked
                ? _plot.strips.map(g => ({ label: g.label ? g.label : "",
                                           series: g.series ? g.series : [] }))
                : [{ label: "",
                     series: driven ? _plot.series
                           : (_plot.probes.length ? _plot.probes : Lab.probeNames)
                                 .map(n => ({ probe: n })) }]
            const tNow = Lab.clock ? Lab.clock.time : 0
            const t0 = Math.max(0, tNow - _plot.windowSeconds)
            const t1 = Math.max(tNow, t0 + 1e-6)

            // A strip ranges over its own curves and nothing else - that is
            // the whole point of stacking them. Time is what they share.
            const strips = []
            let drawn = 0
            for (const g of groups) {
                let vMin = Infinity, vMax = -Infinity
                const series = []
                for (const en of g.series) {
                    const pr = Lab.probe(en.probe)
                    if (!pr) continue
                    const pts = pr.samples.filter(s => s.t >= t0)
                    // an uncertainty band widens the axis: a curve that leaves
                    // its own band would be a plot lying about what it shows
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
                if (vMin > vMax) { vMin = 0; vMax = 1 }
                if (vMax - vMin < 1e-9) { vMax += 0.5; vMin -= 0.5 }
                const pad = (vMax - vMin) * 0.08
                strips.push({ label: g.label, series: series,
                              vMin: vMin - pad, vMax: vMax + pad })
                drawn += series.length
            }
            _plot._legendHits = []
            if (drawn === 0 && _plot.placeholder !== "") {
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
            // no strips declared at all: nothing to frame either. The
            // one-quantity paths always declare one, so this is the stacked
            // plot with nothing traced yet.
            if (strips.length === 0) return

            // A legend band on top of each strip, one axis gutter on the left
            // wide enough for every strip's ticks: the curves get a rect of
            // their own so a spike can never run through a label, and the
            // strips line up on the same instant of time.
            ctx.font = LabTheme.fontMicro + 'px "' + LabTheme.monoFont + '"'
            // a flat-zero series must not read as "-0.00", and the decimal
            // separator follows the lab's language
            const fmt = v => LabLang.num(Math.abs(v) < 5e-3 ? 0 : v, 2)
            let gutter = 0
            for (const st of strips) {
                st.ticks = [st.vMax, (st.vMax + st.vMin) / 2, st.vMin].map(fmt)
                for (const tk of st.ticks)
                    gutter = Math.max(gutter, ctx.measureText(tk).width)
            }
            gutter += LabTheme.spaceL

            const band = _plot.stripBandHeight
            const padB = LabTheme.spaceM, padR = LabTheme.spaceS
            const n = strips.length
            const pw = Math.max(1, width - gutter - padR)
            // the panel's height, divided: one strip reproduces the old
            // padT/ph exactly, and a caller that wants more room asks
            // heightForStrips() for it rather than being handed a taller chart
            const ph = Math.max(1, (height - padB - n * band) / n)
            // with a single strip the quantity is already named by whatever
            // offered it (the monitor's chip row), so a title there would be
            // the same word twice
            const titles = n > 1
            const xOf = t => gutter + (t - t0) / (t1 - t0) * pw
            const dot = Math.max(1.5, LabTheme.px(2.2))
            const hits = []

            for (let si = 0; si < n; ++si) {
                const st = strips[si]
                const top = si * (band + ph) + band
                st.top = top
                const yOf = v => top + ph - (v - st.vMin) / (st.vMax - st.vMin) * ph
                st.yOf = yOf

                ctx.strokeStyle = LabTheme.grid.toString()
                ctx.lineWidth = 1
                for (let i = 0; i <= 2; ++i) {
                    const y = Math.round(top + ph * i / 2) + 0.5
                    ctx.beginPath(); ctx.moveTo(gutter, y); ctx.lineTo(gutter + pw, y); ctx.stroke()
                }

                ctx.save()
                ctx.beginPath(); ctx.rect(gutter, top, pw, ph); ctx.clip()

                // bands first, behind every curve: the uncertainty is the ground
                // the estimates are drawn on, not something layered over them
                for (let i = 0; i < st.series.length; ++i) {
                    const s = st.series[i]
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

                for (let i = 0; i < st.series.length; ++i) {
                    const s = st.series[i]
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
                    const y = top + ph * i / 2
                    ctx.fillText(st.ticks[i],
                                 gutter - LabTheme.spaceM - ctx.measureText(st.ticks[i]).width,
                                 y + (i === 0 ? LabTheme.fontMicro * 0.8
                                    : (i === 2 ? 0 : LabTheme.fontMicro * 0.4)))
                }

                const baseline = top - band + LabTheme.fontMicro + 1
                let lx = gutter
                if (titles && st.label !== "") {
                    // the strip's own name goes first and the legend takes what
                    // is left: a curve with no name is still identified by its
                    // colour, a strip with no unit is not identified at all
                    ctx.fillStyle = LabTheme.inkFaint.toString()
                    ctx.fillText(st.label, lx, baseline)
                    lx += ctx.measureText(st.label).width + LabTheme.spaceL
                }
                for (let i = 0; i < st.series.length; ++i) {
                    const s = st.series[i]
                    const last = s.pts.length ? s.pts[s.pts.length - 1].v : 0
                    let txt = s.name + ": " + LabLang.num(last, 2) + (s.unit ? " " + s.unit : "")
                    if (driven && _plot._hoverProbe === s.probe) txt += " ×"
                    const w = ctx.measureText(txt).width
                    if (lx + w > width - padR) break
                    ctx.fillStyle = s.color
                    ctx.fillText(txt, lx, baseline)
                    if (driven) hits.push({ probe: s.probe, x: lx - LabTheme.spaceS,
                                            y: top - band, w: w + 2 * LabTheme.spaceS,
                                            h: band })
                    lx += w + LabTheme.spaceXxl
                }
            }
            _plot._legendHits = hits

            // --- the cursor readout ----------------------------------------
            // One cursor for the whole stack: the question a stacked plot is
            // asked is "what was everything doing at THIS instant", so the
            // readback crosses every strip rather than the hovered one.
            const chartTop = strips[0].top
            const chartBottom = strips[n - 1].top + ph
            // above the first chart is the top legend band, and reading values
            // back from there is what the band is not for; everything below it
            // reads, including the strip titles between the charts
            if (_plot.cursorReadout && drawn > 0
                && _plot._cursorX >= gutter && _plot._cursorX <= gutter + pw
                && _plot._cursorY >= chartTop) {
                const cx = _plot._cursorX
                const tAt = t0 + (cx - gutter) / pw * (t1 - t0)
                ctx.strokeStyle = LabTheme.inkFaint.toString()
                ctx.lineWidth = 1
                for (const st of strips) {
                    // segment per strip: drawn straight through, the line
                    // would strike out the legends it passes
                    ctx.beginPath()
                    ctx.moveTo(Math.round(cx) + 0.5, st.top)
                    ctx.lineTo(Math.round(cx) + 0.5, st.top + ph)
                    ctx.stroke()
                }

                const rows = []
                for (const st of strips) {
                    for (const s of st.series) {
                        const p = _nearest(s.pts, tAt)
                        if (!p) continue
                        rows.push({ color: s.color,
                                    text: s.name + " " + LabLang.num(p.v, 2)
                                          + (s.unit ? " " + s.unit : ""),
                                    v: p.v })
                        ctx.fillStyle = s.color
                        ctx.beginPath()
                        ctx.arc(xOf(p.t), st.yOf(p.v), dot + 1, 0, 2 * Math.PI)
                        ctx.fill()
                    }
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
                    // a stack reads back more rows than one strip has room
                    // for, so the box may be taller than the chart it sits on
                    let by = Math.min(Math.max(chartTop, _plot._cursorY - bh / 2),
                                      Math.max(0, chartBottom - bh))
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

    // One area over the whole chart, because with stacked strips a legend band
    // is no longer only at the top: the bands sit between the charts, so where
    // a press belongs can only be answered by hit-testing the boxes the
    // painter filled in. The legend doubles as the remove control - a curve is
    // dropped where it is named - and everything else reads values back on
    // hover and lets the press through to whatever the lab put underneath.
    MouseArea {
        id: _plotArea
        x: _canvas.x; y: _canvas.y
        width: _canvas.width; height: _canvas.height
        enabled: _plot.cursorReadout || _plot.series !== null
                 || _plot.strips !== null
        hoverEnabled: enabled
        cursorShape: _plot._hoverProbe !== "" ? Qt.PointingHandCursor
                                              : Qt.ArrowCursor

        function probeAt(mx, my) {
            const hits = _plot._legendHits
            for (let i = 0; i < hits.length; ++i) {
                const h = hits[i]
                if (mx >= h.x && mx <= h.x + h.w && my >= h.y && my <= h.y + h.h)
                    return h.probe
            }
            return ""
        }
        function setHover(p) {
            if (_plot._hoverProbe === p) return
            _plot._hoverProbe = p
            _canvas.requestPaint()
        }
        onPositionChanged: (m) => {
            setHover(probeAt(m.x, m.y))
            _plot._cursorX = m.x
            _plot._cursorY = m.y
        }
        onExited: { setHover(""); _plot._cursorX = -1; _canvas.requestPaint() }
        // not over a legend entry: decline the press so it reaches the item
        // below, the way the read-only cursor area used to by taking no buttons
        onPressed: (m) => { m.accepted = probeAt(m.x, m.y) !== "" }
        onClicked: (m) => {
            const p = probeAt(m.x, m.y)
            if (p !== "") _plot.seriesClicked(p)
        }
    }
}
