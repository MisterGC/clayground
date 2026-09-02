// (c) Clayground Contributors - MIT License, see "LICENSE" file

pragma ComponentBehavior: Bound

import QtQuick
import Clayground.Lab

/*!
    \qmltype PartCard
    \inqmlmodule Clayground.Lab
    \brief The selection card: what is selected, what it reads, what you can do to it.

    Follows the selected part on screen (kept inside the window - zoomed in,
    the anchor can sit far below the viewport). Two lines from the domain
    (\l titleOf, \l readingOf), then the domain's own rows declared as
    children (a slider, a row of chips), then the rows every board part has:
    put it on the plot (\l WatchChip), pin a reading to it as a tag, and a
    one-line hint.

    The card is also a keyboard target, and the only channel that survives
    having no pointer: \c j/\c k walk its rows, \c h/\c l adjust the focused
    one, Enter operates the part. Hand \l keys to \l LabKeys::selection; a
    domain row is adjusted through \l adjust, the kernel rows by the card
    itself. Declare a \l CardFocusRing in each domain row bound to
    \c {focusedRow === "<row>"} and every card shares one focus language.

    A part's state belongs on its card - a resistor's ohms are a slider here,
    a gate's function a row of chips - which is what keeps building and
    operating from feeling like the same gesture.

    \qml
    PartCard {
        id: selCard
        board: board; view: view3d; camera: rig.camera; monitor: monitor; overlay: overlay
        titleOf: (p) => root.cardTitle(p)
        readingOf: (p) => root.fmtV(root.simOf(p.id).v)
        adjust: (p, row, d) => root.adjustRow(p, row, d)
        operate: (p) => root.operatePart(p)
        Row { visible: selCard.part !== null && selCard.part.type === "switch"
              CardFocusRing { on: selCard.focusedRow === "state" } }
    }
    \endqml

    \sa Board, WatchChip, CardFocusRing, LabKeys
*/
LabPanel {
    id: root

    /*! \qmlproperty Board PartCard::board */
    property var board: null
    /*! \qmlproperty var PartCard::view \brief The View3D to project through. */
    property var view: null
    /*! \qmlproperty var PartCard::camera \brief The camera the View3D renders with (projection dependency). */
    property var camera: null
    /*! \qmlproperty var PartCard::monitor \brief The \l WatchMonitor the watch row toggles. */
    property var monitor: null
    /*! \qmlproperty var PartCard::overlay \brief The \l BoardOverlay the tag row pins into. */
    property var overlay: null

    /*! \qmlproperty var PartCard::titleOf \brief \c {(part) -> string}, the first line. */
    property var titleOf: (p) => LabLang.t("part." + p.type).toUpperCase()
    /*! \qmlproperty var PartCard::readingOf \brief \c {(part) -> string}, the second line; "" hides it. */
    property var readingOf: (p) => ""
    /*! \qmlproperty var PartCard::hintOf \brief \c {(part) -> string}, the last line. */
    property var hintOf: (p) => LabLang.t("card.hint.part")
    /*! \qmlproperty var PartCard::minWidthOf \brief \c {(part) -> real}, a floor for the card's width. */
    property var minWidthOf: (p) => 0
    /*!
        \qmlproperty var PartCard::adjust
        \brief \c {(part, row, d) -> bool} - \c h/\c l on a domain row; false refuses.
    */
    property var adjust: (p, row, d) => false
    /*!
        \qmlproperty var PartCard::operate
        \brief \c {(part) -> bool} - Enter on the card; false refuses.
    */
    property var operate: (p) => false

    /*! \qmlproperty real PartCard::anchorDz \brief How far below the part's centre the card hangs, in world units. */
    property real anchorDz: 5.5
    /*! \qmlproperty real PartCard::anchorY */
    property real anchorY: 0

    /*!
        \qmlproperty var PartCard::part
        \readonly
        \brief The selected part, live; null when nothing is selected.
    */
    readonly property var part: {
        if (!board) return null
        board.rev
        return board.selectedId === -1 ? null : board.partAt(board.selectedId)
    }
    /*! \qmlproperty bool PartCard::watchable \readonly \brief The part takes a plot and a tag (spec \c watch). */
    readonly property bool watchable: part !== null && board.specOf(part.type).watch !== false

    readonly property var screenAt: {
        if (!board || !view || !camera) return Qt.vector3d(0, 0, 0)
        board.rev; camera.scenePosition; camera.sceneRotation
        if (!part) return Qt.vector3d(0, 0, 0)
        return view.mapFrom3DScene(Qt.vector3d(board.cellX(part.col), anchorY,
                                               board.cellZ(part.row) + anchorDz))
    }
    visible: part !== null && screenAt.z > 0
    // kept inside the window: zoomed in, the anchor point can sit far below
    // the viewport
    x: Math.max(8, Math.min((parent ? parent.width : width) - width - 8, screenAt.x - width / 2))
    y: Math.max(8, Math.min((parent ? parent.height : height) - height - 44, screenAt.y + 6))
    width: Math.max(selCol.width + 20, part ? minWidthOf(part) : 0)
    height: selCol.height + 14
    padding: 10
    spacing: LabTheme.px(1)
    border.color: LabTheme.secondary

    /*! \qmlproperty list<Item> PartCard::rows \brief The domain's rows, stacked between the reading and the watch row. */
    default property alias rows: _domain.data

    // --- the card as a keyboard target ----------------------------------------
    /*! \qmlproperty int PartCard::focusRow \brief Which row \c j/\c k landed on. */
    property int focusRow: 0
    /*!
        \qmlmethod var PartCard::rowsOf(var part)
        \brief The rows in visual order: the spec's, then \c "watch" and \c "label" for a watchable part.
    */
    function rowsOf(p) {
        if (!p) return []
        const rows = (board.specOf(p.type).rows || []).slice()
        if (board.specOf(p.type).watch !== false) { rows.push("watch"); rows.push("label") }
        return rows
    }
    /*! \qmlproperty string PartCard::focusedRow \readonly */
    readonly property string focusedRow: {
        if (!board) return ""
        board.rev; board.selectedId; focusRow
        const rows = rowsOf(part)
        return rows.length ? rows[Math.min(focusRow, rows.length - 1)] : ""
    }
    /*! \qmlproperty var PartCard::attributes \readonly \brief What a tag may show: the monitor's quantity keys. */
    readonly property var attributes: monitor ? monitor.quantities.map(q => q.key) : []

    /*!
        \qmlproperty QtObject PartCard::keys
        \readonly
        \brief The adapter for \l LabKeys::selection.
    */
    readonly property QtObject keys: QtObject {
        readonly property bool active: root.board !== null && root.board.selectedId !== -1
        function moveFocus(d) {
            const n = root.rowsOf(root.part).length
            if (!n) return false
            root.focusRow = ((root.focusRow + d) % n + n) % n   // wraps
            return true
        }
        function adjust(d) {
            const p = root.part
            if (!p) return false
            const row = root.focusedRow
            if (row === "watch") { if (root.monitor) root.monitor.toggle(p.id); return true }
            if (row === "label") {
                const cyc = [""].concat(root.attributes)
                const cur = (root.overlay && root.overlay.tags[p.id]) || ""
                if (root.overlay)
                    root.overlay.setTag(p.id, cyc[((cyc.indexOf(cur) + d) % cyc.length + cyc.length) % cyc.length])
                return true
            }
            return root.adjust(p, row, d)
        }
        function operate() {
            const p = root.part
            return p ? root.operate(p) : false
        }
    }

    Connections {
        target: root.board
        function onSelectedIdChanged() { root.focusRow = 0 }   // a fresh card starts at its first row
    }

    Column {
        id: selCol
        spacing: LabTheme.px(1)
        Text {
            text: { root.board ? root.board.rev : 0; return root.part ? root.titleOf(root.part) : "" }
            color: LabTheme.primary; font.pixelSize: LabTheme.fontSmall; font.bold: true
            font.letterSpacing: 1.0; font.family: LabTheme.monoFont
        }
        Text {
            text: { root.board ? root.board.rev : 0; return root.part ? root.readingOf(root.part) : "" }
            visible: text !== ""
            color: LabTheme.inkSoft; font.pixelSize: LabTheme.fontSmall
            font.family: LabTheme.monoFont
        }
        Column {
            id: _domain
            spacing: LabTheme.px(1)
        }
        // Monitoring is a per-part act, like selecting: this puts the part on
        // the plot in the colour it then wears on the board.
        WatchChip {
            visible: root.monitor !== null
            monitor: root.monitor
            target: root.watchable ? root.part.id : undefined
            labels: ({ add: "card.watch", on: "card.watched", full: "card.watch.full" })
            CardFocusRing { on: root.focusedRow === "watch" }
        }
        // Pin one attribute to this part as a tag in the scene - the middle
        // rung of the persistence ladder: no probe, no history, a reading
        // that stays.
        Row {
            id: tagChips
            visible: root.watchable && root.overlay !== null && root.attributes.length > 0
            height: visible ? implicitHeight : 0
            spacing: LabTheme.px(3)
            CardFocusRing { on: root.focusedRow === "label" }
            Text {
                text: LabLang.t("card.tag")
                anchors.verticalCenter: parent.verticalCenter
                color: LabTheme.inkFaint; font.pixelSize: LabTheme.fontBody
                font.family: LabTheme.handFont
            }
            Repeater {
                model: [""].concat(root.attributes)
                Rectangle {
                    id: chip
                    required property string modelData
                    readonly property bool active: root.part !== null && root.overlay !== null
                        && (root.overlay.tags[root.part.id] || "") === modelData
                    // sized to the attribute's name: a one-letter kit gets a
                    // square chip, a kit that says "flow" gets room for it
                    width: Math.max(LabTheme.px(24), chipText.implicitWidth + LabTheme.px(10))
                    height: LabTheme.px(20)
                    radius: LabTheme.px(4)
                    color: active ? LabTheme.secondary : LabTheme.paper
                    border.color: active ? LabTheme.secondary : LabTheme.panelEdge
                    border.width: LabTheme.borderWidth
                    Text {
                        id: chipText
                        anchors.centerIn: parent
                        text: chip.modelData === "" ? "–" : chip.modelData
                        color: LabTheme.inkOn(chip.color)
                        font.pixelSize: LabTheme.fontSmall; font.bold: true
                        font.family: LabTheme.monoFont
                    }
                    MouseArea {
                        anchors.fill: parent
                        onClicked: if (root.part) root.overlay.setTag(root.part.id, chip.modelData)
                    }
                }
            }
        }
        Text {
            text: root.part ? root.hintOf(root.part) : ""
            color: LabTheme.inkFaint; font.pixelSize: LabTheme.fontBody
            font.family: LabTheme.handFont
        }
    }
}
