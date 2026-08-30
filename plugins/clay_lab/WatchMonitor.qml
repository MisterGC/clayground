// (c) Clayground Contributors - MIT License, see "LICENSE" file

import QtQuick

/*!
    \qmltype WatchMonitor
    \inqmlmodule Clayground.Lab
    \brief Watch a thing, get a probe, a colour and a curve.

    The plotted set is the WATCHED set: point at a part (a road, a resistor,
    a sensor), and it gains a Probe, a place in the legend and a colour it
    then wears everywhere - on the object, in the legend, on its card. Drop it
    by clicking its legend entry. Two labs had written this out in full before
    it moved here.

    The lab supplies only what is domain-specific: what an id is worth right
    now (\l valueOf), what to call it (\l labelOf), and which quantities can
    be plotted (\l quantities). Everything else - probe lifecycle, stable
    names, colours, the one-quantity-per-axis rule - lives here.

    One quantity per axis is deliberate, not a limitation: series that share
    an autoscaled axis must share a unit, or mixing mA with volts flattens the
    volts onto the baseline. The chip row switches which quantity the watched
    set is read as, and switching re-aims the whole set - the parts stay, the
    reading changes, and the samples go, because the old ones would draw a
    nonsense step across the change of unit.

    Two quantities that must be \e compared get a strip each instead
    (\l traceIn): stacked charts on one shared time axis, so "the voltage
    dipped when the current spiked" is one picture and the rule still holds.
    Strips appear and disappear with the traces in them, ordered by the
    lab's \l quantities, at most \l maxStrips of them.

    \qml
    WatchMonitor {
        id: monitor
        anchors.right: parent.right; anchors.bottom: parent.bottom
        idPrefix: "road"
        quantities: [{ key: "flow", label: "quantity.flow", unit: "/min" },
                     { key: "load", label: "quantity.load", unit: "" }]
        valueOf: (id) => root.rateOf(id)
        labelOf: (id) => root.roadLabel(id)
        placeholder: LabLang.t("plot.empty")
    }
    \endqml

    \sa Probe, Plot2D, LabTheme
*/
Item {

    // The plot IS the sensor tracking, so focus mode - which is for studying
    // a scene when readings are not the point - takes it with the rest of the
    // HUD. Kernel-side rather than per-lab: every lab that watches anything
    // has one of these, and the next one written should not have to remember.
    visible: !LabView.focus
    id: root

    /*!
        \qmlproperty string WatchMonitor::idPrefix
        \brief Probe-name prefix; probes are \c {<idPrefix><id>}.

        Id-based and therefore stable while the visible label changes under
        it - a lone BULB becomes BULB1 the moment a second one lands.

        A trace pinned in a quantity other than the first of \l quantities
        appends \c {.<key>} (\c part7.V), because the same part traced as
        volts and as milliamps is two probes and they may not collide. The
        first quantity keeps the plain name - it is the one every lab, record
        and study already knows. See \l probeName.
    */
    property string idPrefix: "watch"

    /*!
        \qmlproperty var WatchMonitor::quantities
        \brief \c {[{key, label, unit}]}.
    */
    property var quantities: []

    /*!
        \qmlproperty string WatchMonitor::quantity
        \brief Active quantity key: what \l setWatched traces in, and what the
        chip row shows as chosen.

        Switching it moves the traces that were being read as the old quantity
        over to the new one - the watched set is a set of parts, and the chips
        choose what the parts are read as. Traces pinned in another quantity
        with \l traceIn stay where they are and keep their strip.
    */
    property string quantity: quantities.length ? quantities[0].key : ""

    /*!
        \qmlproperty int WatchMonitor::maxSeries
        \brief Beyond this the colours would repeat.

        Counted in watched \e things, not in curves: a part traced in two
        quantities wears one colour and spends one slot, which is what keeps
        its \l WatchMark recognisable in both strips.
    */
    property int maxSeries: 6

    /*!
        \qmlproperty int WatchMonitor::maxStrips
        \brief How many quantities may be stacked at once.

        The strips divide the panel's height, so this is what stops it from
        growing without end. Three is the height at which the bottom-right slot
        still leaves the scene the room it is there for; a fourth trace in a
        fourth quantity is refused by \l traceIn rather than drawn too small to
        read.
    */
    property int maxStrips: 3

    /*!
        \qmlproperty var WatchMonitor::valueOf
        \brief \c {(id, quantity) -> real}: the current reading.

        The second argument says which quantity is being asked for, and a lab
        has to \e declare it to get stacked strips: a callback that only takes
        the id is one that reads \l quantity itself - as the first labs all
        did - so \l traceIn refuses a second quantity rather than plotting the
        active reading under another unit's name. A plot that lies is worse
        than a strip that never appears.
    */
    property var valueOf: (id, quantityKey) => 0

    /*!
        \qmlproperty var WatchMonitor::labelOf
        \brief \c {(id) -> string}: the legend/board label.
    */
    property var labelOf: (id) => "" + id

    /*!
        \qmlproperty var WatchMonitor::canWatch
        \brief \c {(id) -> bool}: veto (a solder dot has no reading).
    */
    property var canWatch: (id) => true

    /*!
        \qmlproperty var WatchMonitor::watched
        \readonly
        \brief The watched ids, in plot order - which is also colour order.

        Derived from the traces: an id appears once however many quantities it
        is traced in, and leaves only when the last of them goes. The set is
        changed through \l setWatched, \l traceIn, \l watchOnly, \l clear and
        \l prune, never by assignment - a lab that wrote to it would be
        deciding half of a pair the monitor keeps consistent.
    */
    readonly property var watched: {
        const out = []
        for (const tr of _traces) if (out.indexOf(tr.id) === -1) out.push(tr.id)
        return out
    }

    /*!
        \qmlproperty var WatchMonitor::tracedQuantities
        \readonly
        \brief The quantity keys that currently have a strip, in \l quantities
        order.
    */
    readonly property var tracedQuantities: {
        const out = []
        for (const q of quantities)
            if (_traces.some(tr => tr.quantity === q.key)) out.push(q.key)
        return out
    }

    // Every trace as {id, quantity}, in the order they were made: one probe,
    // one curve and one strip membership each. The watched SET is a projection
    // of this - the pair is what a strip stack needs and a flat list cannot
    // carry, and keeping the list the primary form is what lets `watched`
    // stay exactly the array labs already read.
    property var _traces: []

    /*!
        \qmlproperty int WatchMonitor::revision
        \brief Bump when labels change (ordinals, renames).
    */
    property int revision: 0

    /*!
        \qmlproperty string WatchMonitor::placeholder
        \brief Shown while nothing is watched.
    */
    property string placeholder: ""

    /*!
        \qmlproperty real WatchMonitor::windowSeconds
        \brief Plot window.
    */
    property real windowSeconds: 30

    /*!
        \qmlproperty real WatchMonitor::plotWidth
        \brief Chart width.
    */
    property real plotWidth: LabTheme.px(330)

    /*!
        \qmlproperty real WatchMonitor::plotHeight
        \brief Chart height - the budget the strips divide.

        One or two strips fit inside it (a two-channel stack is two half
        charts); a third takes the chart to the floor below which a curve stops
        being a shape, and only then does the panel grow. Bounded by
        \l maxStrips, so the bottom-right slot has a largest size and it is
        reached at three strips.
    */
    property real plotHeight: LabTheme.px(140)

    /*!
        \qmlproperty string WatchMonitor::unitText
        \readonly
        \brief Unit of the active quantity.
    */
    readonly property string unitText: {
        for (const q of quantities) if (q.key === quantity) return q.unit
        return ""
    }

    /*!
        \qmlsignal WatchMonitor::changed()
        \brief The watched set changed.
    */
    signal changed()

    implicitWidth: plotWidth
    implicitHeight: _chips.height + LabTheme.spaceM + _plot.height
    width: implicitWidth
    height: implicitHeight

    /*! \qmlmethod bool WatchMonitor::isWatched(var id) */
    function isWatched(id) { return watched.indexOf(id) !== -1 }

    /*!
        \qmlmethod bool WatchMonitor::isTracedIn(string quantity, var id)
        \brief The id has a curve on \a quantity's strip.
    */
    function isTracedIn(quantityKey, id) {
        return _traces.some(tr => tr.id === id && tr.quantity === quantityKey)
    }

    /*!
        \qmlmethod var WatchMonitor::traces()
        \brief Every trace as \c {[{id, quantity}]}, in the order they were
        made - a lab's \c viewState() serializes this.
    */
    function traces() { return _traces.map(tr => ({ id: tr.id, quantity: tr.quantity })) }

    /*!
        \qmlmethod string WatchMonitor::probeName(var id, string quantity)
        \brief The probe an id is sampled into for \a quantity (the active one
        when omitted).
    */
    function probeName(id, quantityKey) {
        const q = quantityKey === undefined ? quantity : quantityKey
        const base = idPrefix + id
        return (q === "" || !quantities.length || q === quantities[0].key)
            ? base : base + "." + q
    }

    /*!
        \qmlmethod string WatchMonitor::unitOf(string quantity)
        \brief The unit declared for \a quantity, empty when it has none.
    */
    function unitOf(quantityKey) {
        for (const q of quantities) if (q.key === quantityKey) return q.unit
        return ""
    }

    /*!
        \qmlmethod color WatchMonitor::colorOf(var id)
        \brief The id's series colour, or transparent when it is not watched.
    */
    function colorOf(id) {
        const i = watched.indexOf(id)
        return i === -1 ? "transparent"
            : LabTheme.seriesColors[i % LabTheme.seriesColors.length]
    }

    /*!
        \qmlmethod bool WatchMonitor::isFull()
        \brief No colour left for another curve.
    */
    function isFull() { return watched.length >= maxSeries }

    /*!
        \qmlmethod void WatchMonitor::setWatched(var id, bool on)
        \brief Put the id on the plot, read as the active \l quantity.

        Dropping it drops it from every strip: the card's chip is the answer to
        "is this part on the plot", so a part it says is off must not still be
        drawing a curve two strips down.
    */
    function setWatched(id, on) {
        if (on && !canWatch(id)) return
        if (on === isWatched(id)) return
        if (on) {
            if (isFull()) return
            _traces = _traces.concat([{ id: id, quantity: quantity }])
        } else {
            _traces = _traces.filter(tr => tr.id !== id)
        }
        changed()
    }

    /*!
        \qmlmethod bool WatchMonitor::traceIn(string quantity, var id, bool on)
        \brief Trace the id on \a quantity's strip, stacking a new one if that
        quantity has none yet.

        Returns false when the trace was refused, and the three reasons it can
        be are all budgets: no colour left (\l maxSeries), no strip left
        (\l maxStrips), or a \l valueOf that cannot be asked for a quantity
        other than the active one. Refusing is the point - the alternative is a
        strip labelled volts with milliamps drawn on it.
    */
    function traceIn(quantityKey, id, on) {
        if (!on) {
            const keep = _traces.filter(tr => !(tr.id === id && tr.quantity === quantityKey))
            if (keep.length === _traces.length) return true
            _traces = keep
            changed()
            return true
        }
        if (!canWatch(id) || !quantities.some(q => q.key === quantityKey)) return false
        if (isTracedIn(quantityKey, id)) return true
        if (!isWatched(id) && isFull()) return false
        if (tracedQuantities.indexOf(quantityKey) === -1) {
            if (tracedQuantities.length >= maxStrips) return false
            if (quantityKey !== quantity && valueOf.length < 2) {
                console.warn("WatchMonitor: valueOf takes only an id, so it can "
                           + "only answer for the active quantity - "
                           + quantityKey + " not traced")
                return false
            }
        }
        _traces = _traces.concat([{ id: id, quantity: quantityKey }])
        changed()
        return true
    }

    /*!
        \qmlmethod void WatchMonitor::traceOnly(var list)
        \brief Replace every trace with \c {[{id, quantity}]} - the restoring
        half of \l traces().
    */
    function traceOnly(list) {
        const out = [], ids = [], qs = []
        for (const tr of list) {
            if (!canWatch(tr.id)) continue
            const q = tr.quantity === undefined ? quantity : tr.quantity
            if (out.some(x => x.id === tr.id && x.quantity === q)) continue
            const newId = ids.indexOf(tr.id) === -1
            const newQ = qs.indexOf(q) === -1
            if (newId && ids.length >= maxSeries) continue
            if (newQ && qs.length >= maxStrips) continue
            if (newId) ids.push(tr.id)
            if (newQ) qs.push(q)
            out.push({ id: tr.id, quantity: q })
        }
        _traces = out
        changed()
    }

    /*! \qmlmethod void WatchMonitor::toggle(var id) */
    function toggle(id) { setWatched(id, !isWatched(id)) }

    /*!
        \qmlmethod void WatchMonitor::watchOnly(var ids)
        \brief Replace the set (presets seed it).
    */
    function watchOnly(ids) {
        traceOnly(ids.filter(canWatch).slice(0, maxSeries)
                     .map(id => ({ id: id, quantity: quantity })))
    }

    /*! \qmlmethod void WatchMonitor::clear() */
    function clear() { _traces = []; changed() }

    /*!
        \qmlmethod void WatchMonitor::prune(var stillExists)
        \brief Drops ids whose object is gone - deleted parts must not plot as zero.
    */
    function prune(stillExists) {
        const keep = _traces.filter(tr => stillExists(tr.id))
        if (keep.length !== _traces.length) { _traces = keep; changed() }
    }

    // The chips re-aim the watched set rather than replacing it: the parts are
    // what the user chose, the quantity is how they are read. Traces pinned in
    // another quantity keep their strip - they were asked for by name.
    // NOT bound to `quantity`: a binding would already carry the new value by
    // the time the handler below reads it, and the first switch of a session
    // would quietly re-aim nothing.
    property string _prevQuantity: ""
    Component.onCompleted: _prevQuantity = quantity
    onQuantityChanged: {
        const from = _prevQuantity
        _prevQuantity = quantity
        if (from === "" || from === quantity) return
        const out = []
        for (const tr of _traces) {
            const q = tr.quantity === from ? quantity : tr.quantity
            if (out.some(x => x.id === tr.id && x.quantity === q)) continue
            out.push({ id: tr.id, quantity: q })
        }
        // the samples go with the meaning: the probe of a re-aimed trace is
        // renamed and rebuilt, and drawing the old values across the change of
        // unit would be a step nothing measured
        for (const tr of _traces) {
            const pr = Lab.probe(probeName(tr.id, tr.quantity))
            if (pr && tr.quantity === from) pr.clear()
        }
        _traces = out
    }

    // One probe per TRACE, created and destroyed with it: a part traced as
    // volts and as milliamps is two series on two axes, and one probe cannot
    // carry two units.
    Instantiator {
        model: root._traces
        delegate: Probe {
            required property var modelData
            readonly property var wid: modelData.id
            readonly property string wq: modelData.quantity
            name: root.probeName(wid, wq)
            unit: root.unitOf(wq)
            expr: () => root.valueOf(wid, wq)
        }
    }

    Row {
        id: _chips
        anchors.top: parent.top
        anchors.right: parent.right
        spacing: LabTheme.spaceM

        Repeater {
            model: root.quantities
            Rectangle {
                required property var modelData
                readonly property bool active: modelData.key === root.quantity
                width: _chipLabel.implicitWidth + LabTheme.spaceXxl
                height: LabTheme.px(22)
                radius: LabTheme.radius
                color: active ? LabTheme.secondary : LabTheme.panel
                border.color: active ? LabTheme.secondary : LabTheme.panelEdge
                border.width: LabTheme.borderWidth
                Text {
                    id: _chipLabel
                    anchors.centerIn: parent
                    text: LabLang.t(modelData.label)
                          + (modelData.unit ? " (" + modelData.unit + ")" : "")
                    color: LabTheme.inkOn(parent.color)
                    font.pixelSize: LabTheme.fontBody
                    font.family: LabTheme.handFont
                }
                MouseArea {
                    anchors.fill: parent
                    onClicked: root.quantity = modelData.key
                }
            }
        }
    }

    /*!
        \qmlproperty var WatchMonitor::stripModel
        \readonly
        \brief What the plot is drawing: one entry per traced quantity, in
        \l quantities order, as \c {[{key, label, series}]}.

        The order is the lab's declared order rather than the order the traces
        happened in, so a strip appearing does not move the ones already there.
    */
    readonly property var stripModel: {
        revision
        const out = []
        for (const q of quantities) {
            const ids = []
            for (const tr of _traces)
                if (tr.quantity === q.key && ids.indexOf(tr.id) === -1) ids.push(tr.id)
            if (ids.length === 0) continue
            out.push({
                key: q.key,
                label: LabLang.t(q.label) + (q.unit ? " (" + q.unit + ")" : ""),
                series: ids.map(id => ({ probe: probeName(id, q.key),
                                         label: labelOf(id),
                                         color: colorOf(id) }))
            })
            if (out.length >= maxStrips) break
        }
        return out
    }

    Plot2D {
        id: _plot
        anchors.bottom: parent.bottom
        anchors.right: parent.right
        width: root.plotWidth
        // the strips divide plotHeight until they would be too thin to read;
        // past that the panel grows, and maxStrips is what bounds the growth
        height: Math.max(root.plotHeight, heightForStrips(root.stripModel.length))
        windowSeconds: root.windowSeconds
        placeholder: root.placeholder
        strips: root.stripModel
        // the legend is also the control: clicking an entry drops that curve
        // where it is named - the trace and not the part, so a part traced in
        // two quantities loses only the strip it was clicked in
        onSeriesClicked: (probe) => {
            for (const tr of root.traces())
                if (root.probeName(tr.id, tr.quantity) === probe) {
                    root.traceIn(tr.quantity, tr.id, false)
                    return
                }
        }
    }
}
