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

    One quantity at a time is deliberate, not a limitation: all series share
    one autoscaled axis, so mixing mA with volts would flatten the volts onto
    the baseline. Switching clears the samples, because the old ones would
    draw a nonsense step across the change of unit.

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
    id: root

    /*!
        \qmlproperty string WatchMonitor::idPrefix
        \brief Probe-name prefix; probes are \c {<idPrefix><id>}.

        Id-based and therefore stable while the visible label changes under
        it - a lone BULB becomes BULB1 the moment a second one lands.
    */
    property string idPrefix: "watch"

    /*! \qmlproperty var WatchMonitor::quantities \brief \c {[{key, label, unit}]}. */
    property var quantities: []

    /*! \qmlproperty string WatchMonitor::quantity \brief Active quantity key. */
    property string quantity: quantities.length ? quantities[0].key : ""

    /*! \qmlproperty int WatchMonitor::maxSeries \brief Beyond this the colours would repeat. */
    property int maxSeries: 6

    /*! \qmlproperty var WatchMonitor::valueOf \brief \c {(id) -> real}: the current reading. */
    property var valueOf: (id) => 0

    /*! \qmlproperty var WatchMonitor::labelOf \brief \c {(id) -> string}: the legend/board label. */
    property var labelOf: (id) => "" + id

    /*! \qmlproperty var WatchMonitor::canWatch \brief \c {(id) -> bool}: veto (a solder dot has no reading). */
    property var canWatch: (id) => true

    /*! \qmlproperty var WatchMonitor::watched \brief The watched ids, in plot order. */
    property var watched: []

    /*! \qmlproperty int WatchMonitor::revision \brief Bump when labels change (ordinals, renames). */
    property int revision: 0

    /*! \qmlproperty string WatchMonitor::placeholder \brief Shown while nothing is watched. */
    property string placeholder: ""

    /*! \qmlproperty real WatchMonitor::windowSeconds \brief Plot window. */
    property real windowSeconds: 30

    /*! \qmlproperty real WatchMonitor::plotWidth \brief Chart width. */
    property real plotWidth: 330

    /*! \qmlproperty real WatchMonitor::plotHeight \brief Chart height. */
    property real plotHeight: 140

    /*! \qmlproperty string WatchMonitor::unitText \readonly \brief Unit of the active quantity. */
    readonly property string unitText: {
        for (const q of quantities) if (q.key === quantity) return q.unit
        return ""
    }

    /*! \qmlsignal WatchMonitor::changed() \brief The watched set changed. */
    signal changed()

    implicitWidth: plotWidth
    implicitHeight: _chips.height + 6 + plotHeight
    width: implicitWidth
    height: implicitHeight

    /*! \qmlmethod bool WatchMonitor::isWatched(var id) */
    function isWatched(id) { return watched.indexOf(id) !== -1 }

    /*!
        \qmlmethod color WatchMonitor::colorOf(var id)
        \brief The id's series colour, or transparent when it is not watched.
    */
    function colorOf(id) {
        const i = watched.indexOf(id)
        return i === -1 ? "transparent"
            : LabTheme.seriesColors[i % LabTheme.seriesColors.length]
    }

    /*! \qmlmethod bool WatchMonitor::isFull() \brief No colour left for another curve. */
    function isFull() { return watched.length >= maxSeries }

    /*! \qmlmethod void WatchMonitor::setWatched(var id, bool on) */
    function setWatched(id, on) {
        if (on && !canWatch(id)) return
        if (on === isWatched(id)) return
        if (on) {
            if (isFull()) return
            watched = watched.concat([id])
        } else {
            watched = watched.filter(x => x !== id)
        }
        changed()
    }

    /*! \qmlmethod void WatchMonitor::toggle(var id) */
    function toggle(id) { setWatched(id, !isWatched(id)) }

    /*! \qmlmethod void WatchMonitor::watchOnly(var ids) \brief Replace the set (presets seed it). */
    function watchOnly(ids) {
        watched = ids.filter(canWatch).slice(0, maxSeries)
        changed()
    }

    /*! \qmlmethod void WatchMonitor::clear() */
    function clear() { watched = []; changed() }

    /*!
        \qmlmethod void WatchMonitor::prune(var stillExists)
        \brief Drops ids whose object is gone - deleted parts must not plot as zero.
    */
    function prune(stillExists) {
        const keep = watched.filter(stillExists)
        if (keep.length !== watched.length) { watched = keep; changed() }
    }

    onQuantityChanged: {
        for (const id of watched) {
            const pr = Lab.probe(idPrefix + id)
            if (pr) pr.clear()
        }
    }

    // One probe per watched id, created and destroyed with the watch set.
    Instantiator {
        model: root.watched
        delegate: Probe {
            required property var modelData
            readonly property var wid: modelData
            name: root.idPrefix + wid
            unit: root.unitText
            expr: () => root.valueOf(wid)
        }
    }

    Row {
        id: _chips
        anchors.top: parent.top
        anchors.right: parent.right
        spacing: 6

        Repeater {
            model: root.quantities
            Rectangle {
                required property var modelData
                readonly property bool active: modelData.key === root.quantity
                width: _chipLabel.implicitWidth + 16
                height: 22
                radius: LabTheme.radius
                color: active ? LabTheme.secondary : LabTheme.panel
                border.color: active ? LabTheme.secondary : LabTheme.panelEdge
                border.width: LabTheme.borderWidth
                Text {
                    id: _chipLabel
                    anchors.centerIn: parent
                    text: LabLang.t(modelData.label)
                          + (modelData.unit ? " (" + modelData.unit + ")" : "")
                    color: parent.active ? LabTheme.paper : LabTheme.inkSoft
                    font.pixelSize: 12
                    font.family: LabTheme.handFont
                }
                MouseArea {
                    anchors.fill: parent
                    onClicked: root.quantity = modelData.key
                }
            }
        }
    }

    Plot2D {
        id: _plot
        anchors.bottom: parent.bottom
        anchors.right: parent.right
        width: root.plotWidth
        height: root.plotHeight
        windowSeconds: root.windowSeconds
        placeholder: root.placeholder
        series: {
            root.revision
            return root.watched.map((id, i) => ({
                probe: root.idPrefix + id,
                label: root.labelOf(id),
                color: LabTheme.seriesColors[i % LabTheme.seriesColors.length] }))
        }
        // the legend is also the control: clicking an entry drops that curve
        // where it is named
        onSeriesClicked: (probe) => {
            const raw = probe.substring(root.idPrefix.length)
            const asNum = parseInt(raw)
            root.setWatched(isNaN(asNum) ? raw : asNum, false)
        }
    }
}
