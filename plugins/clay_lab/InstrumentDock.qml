// (c) Clayground Contributors - MIT License, see "LICENSE" file

import QtQuick

/*!
    \qmltype InstrumentDock
    \inqmlmodule Clayground.Lab
    \brief A column of HUD instruments the reader can put away one at a time.

    A lab decides per instrument whether it belongs \e in the world - a dial
    printed on the part it measures - or on the HUD. The ones on the HUD go in
    a dock, and the reader may put any of them away: the panel folds and its
    name appears as a chip in a slim tray at the foot of the dock, which offers
    it back. Which instruments are essential is a per-lab call, so the kernel
    provides the mechanics and the lab declares the set.

    The visible set rides in \l viewState(), so a lab that merges it into its
    own comes back after a reload showing exactly the instruments the reader
    had out. Declare the children as \l DockedInstrument; anything else in the
    dock is stacked but never hidable.

    Example usage:
    \qml
    import Clayground.Lab

    InstrumentDock {
        id: dock
        anchors.left: parent.left
        anchors.top: parent.top
        anchors.margins: LabTheme.spaceXl
        itemWidth: LabTheme.px(220)

        DockedInstrument {
            key: "volts"; label: LabLang.t("inst.volts")
            Gauge { width: parent.width; height: LabTheme.px(112); scale: voltScale }
        }
        DockedInstrument {
            key: "level"; label: LabLang.t("inst.level")
            BarFace { width: parent.width; scale: levelScale; segments: 20 }
        }
    }
    \endqml

    In the lab's conventions block:

    \qml
    function viewState() {
        return Object.assign(Lab.viewState(), { dock: dock.viewState() })
    }
    function applyViewState(s) {
        if (!s) return
        dock.applyViewState(s.dock)
        Lab.applyViewState(s.lab)
    }
    \endqml

    \sa DockedInstrument, InstrumentScale, LabPanel
*/
Item {

    // Same as the belt: instruments are what focus mode is standing down.
    visible: !LabView.focus
    id: root

    /*!
        \qmlproperty bool InstrumentDock::isInstrumentDock
        \readonly
        \brief Marker a \l DockedInstrument finds its dock by.
    */
    readonly property bool isInstrumentDock: true

    /*!
        \qmlproperty real InstrumentDock::itemWidth
        \brief Width every docked instrument takes.
    */
    property real itemWidth: LabTheme.px(214)

    /*!
        \qmlproperty int InstrumentDock::spacing
        \brief Gap between stacked instruments.
    */
    property int spacing: LabTheme.spaceL

    /*!
        \qmlproperty var InstrumentDock::hidden
        \brief The keys currently put away, in the order they were dismissed.

        Assignable, so a scenario or a flow can stage the dock. \l viewState()
        carries it.
    */
    property var hidden: []

    /*!
        \qmlproperty bool InstrumentDock::showTray
        \brief Offer the put-away instruments back.
    */
    property bool showTray: true

    /*!
        \qmlproperty list<Item> InstrumentDock::content
        \brief The docked instruments (the default property).
    */
    default property alias content: _col.data

    /*!
        \qmlsignal InstrumentDock::changed()
        \brief The visible set changed.
    */
    signal changed()

    /*!
        \qmlproperty int InstrumentDock::revision
        \readonly
        \brief Bumps whenever an instrument registers.
    */
    readonly property alias revision: _reg.revision

    implicitWidth: itemWidth
    implicitHeight: _col.height + (_tray.visible ? _tray.height + LabTheme.spaceM : 0)
    width: implicitWidth
    height: implicitHeight

    /*! \qmlmethod bool InstrumentDock::isShown(string key) */
    function isShown(key) { return hidden.indexOf(key) === -1 }

    /*!
        \qmlmethod void InstrumentDock::hide(string key)
        \brief Folds an instrument into the tray.
    */
    function hide(key) {
        if (!isShown(key)) return
        hidden = hidden.concat([key])
        changed()
    }

    /*!
        \qmlmethod void InstrumentDock::show(string key)
        \brief Takes it back out.
    */
    function show(key) {
        if (isShown(key)) return
        hidden = hidden.filter(k => k !== key)
        changed()
    }

    /*! \qmlmethod void InstrumentDock::toggle(string key) */
    function toggle(key) { isShown(key) ? hide(key) : show(key) }

    /*!
        \qmlmethod void InstrumentDock::showAll()
        \brief Empties the tray.
    */
    function showAll() {
        if (!hidden.length) return
        hidden = []
        changed()
    }

    /*!
        \qmlmethod var InstrumentDock::keys()
        \brief Every declared instrument key, in dock order.
    */
    function keys() {
        _reg.revision
        return _reg.items.map(i => i.key)
    }

    /*!
        \qmlmethod string InstrumentDock::labelOf(string key)
        \brief The declared caption of an instrument, for the tray chip.
    */
    function labelOf(key) {
        _reg.revision
        for (const i of _reg.items)
            if (i.key === key) return i.label !== "" ? i.label : i.key
        return key
    }

    /*!
        \qmlmethod var InstrumentDock::viewState()
        \brief \c {{ hidden: [...] }}.
    */
    function viewState() { return { hidden: hidden.slice() } }

    /*! \qmlmethod void InstrumentDock::applyViewState(var s) */
    function applyViewState(s) {
        if (!s || !s.hidden) return
        hidden = s.hidden.slice()
        changed()
    }

    // --- registration ------------------------------------------------------
    //
    // Children announce themselves rather than being scanned for: a dock that
    // walked its own children would have to re-walk them on every change, and
    // the tray needs the caption of an instrument that is currently NOT in the
    // column - the very thing a walk cannot see.

    QtObject {
        id: _reg
        property var items: []
        property int revision: 0
    }

    function register(item) {
        if (_reg.items.indexOf(item) !== -1) return
        _reg.items = _reg.items.concat([item])
        _reg.revision++
    }

    function unregister(item) {
        _reg.items = _reg.items.filter(i => i !== item)
        _reg.revision++
    }

    Column {
        id: _col
        width: root.itemWidth
        spacing: root.spacing
    }

    // The tray: one chip per put-away instrument, plus a way to take them all
    // back. It stacks rather than running along one line, and every chip is
    // capped at the dock's own width - a row of chips carrying instrument
    // names ran straight off the edge of the window the first time two things
    // were put away at once.
    Column {
        id: _tray
        y: _col.height + LabTheme.spaceM
        width: root.itemWidth
        visible: root.showTray && root.hidden.length > 0
        spacing: LabTheme.spaceXs

        Text {
            text: LabLang.t("dock.hidden")
            color: LabTheme.inkFaint
            font.pixelSize: LabTheme.fontMicro
            font.letterSpacing: 1.0
            font.family: LabTheme.monoFont
        }

        Repeater {
            model: root.hidden
            Rectangle {
                required property var modelData
                height: LabTheme.px(20)
                width: Math.min(root.itemWidth,
                                _chip.implicitWidth + LabTheme.spaceXl)
                radius: LabTheme.radius
                color: _tap.containsMouse ? LabTheme.secondary : LabTheme.panel
                border.color: LabTheme.panelEdge
                border.width: LabTheme.borderWidth
                Text {
                    id: _chip
                    anchors.centerIn: parent
                    width: Math.min(implicitWidth,
                                    root.itemWidth - LabTheme.spaceXl)
                    elide: Text.ElideRight
                    text: "+ " + root.labelOf(modelData)
                    // the fill changes on hover, so the ink has to follow it
                    color: LabTheme.inkOn(parent.color)
                    font.pixelSize: LabTheme.fontMicro
                    font.family: LabTheme.monoFont
                }
                MouseArea {
                    id: _tap
                    anchors.fill: parent
                    hoverEnabled: true
                    onClicked: root.show(modelData)
                }
            }
        }

        // Only once putting things back one at a time has become a chore.
        Rectangle {
            visible: root.hidden.length > 1
            height: LabTheme.px(20)
            width: _all.implicitWidth + LabTheme.spaceXl
            radius: LabTheme.radius
            color: _allTap.containsMouse ? LabTheme.tertiary : LabTheme.panel
            border.color: LabTheme.panelEdge
            border.width: LabTheme.borderWidth
            Text {
                id: _all
                anchors.centerIn: parent
                text: LabLang.t("dock.showAll")
                color: LabTheme.inkOn(parent.color)
                font.pixelSize: LabTheme.fontMicro
                font.family: LabTheme.monoFont
            }
            MouseArea {
                id: _allTap
                anchors.fill: parent
                hoverEnabled: true
                onClicked: root.showAll()
            }
        }
    }
}
