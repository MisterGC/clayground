// (c) Clayground Contributors - MIT License, see "LICENSE" file

pragma ComponentBehavior: Bound

import QtQuick
import Clayground.Lab

/*!
    \qmltype BoardOverlay
    \inqmlmodule Clayground.Lab
    \brief The 2D readings over a \l Board: value labels, wire readings, watch marks and pinned tags.

    Four kinds of chip, all screen-space over the 3D board, all projected
    through the same camera with its scene transform listed as a dependency
    (without that the binding freezes the moment the rig moves - invisible
    with a static camera):

    \list
    \li \b {value labels} - with \l showValues on, every part shows the current
        \l valueAttr; \c V cycles it through the monitor's quantities
        (off, first, ..., off); a one-quantity domain keeps a binary toggle;
    \li \b {wire readings} - what \l wireReadingOf says, only for the
        \l wireAttr quantity (a wire carries one thing);
    \li \b {watch marks} - the dot a watched part wears in its curve's colour;
    \li \b {tags} - one attribute pinned to one part from its card: no probe,
        no history, a reading that stays. Put \l tags in \c viewState().
    \endlist

    Every reading goes through \l readingOf, so the labels, the tags and the
    card cannot disagree; \l severityOf paints a reading past its band in
    alarm ink rather than hiding it. \l hidden takes the wire readings, marks
    and tags off while somebody is standing on the board - a professor's
    sentence says which part this is, and a tag repeating it is not carrying
    its weight.

    \sa Board, WatchMark, WatchMonitor, PartCard
*/
Item {
    id: root

    /*! \qmlproperty Board BoardOverlay::board */
    property var board: null
    /*! \qmlproperty var BoardOverlay::view \brief The View3D to project through. */
    property var view: null
    /*! \qmlproperty var BoardOverlay::camera */
    property var camera: null
    /*! \qmlproperty var BoardOverlay::monitor \brief The \l WatchMonitor: quantities, colours, the watched set. */
    property var monitor: null
    /*!
        \qmlproperty var BoardOverlay::solved
        \brief Bind the domain's solve result here so every reading re-reads when it changes.
    */
    property var solved: null

    /*! \qmlproperty var BoardOverlay::readingOf \brief \c {(id, attr) -> string}, one reading, any attribute. */
    property var readingOf: (id, attr) => ""
    /*! \qmlproperty var BoardOverlay::severityOf \brief \c {(id, attr) -> "ok" | "warn"}. */
    property var severityOf: (id, attr) => "ok"
    /*! \qmlproperty var BoardOverlay::wireReadingOf \brief \c {(wire) -> string | null}; null draws nothing. */
    property var wireReadingOf: (w) => null
    /*! \qmlproperty var BoardOverlay::labelOf \brief \c {(id) -> string}, the short name a watch mark carries. */
    property var labelOf: (id) => String(id)

    /*! \qmlproperty bool BoardOverlay::hidden \brief Wire readings, marks and tags step aside (a teacher on the board). */
    property bool hidden: false

    /*! \qmlproperty real BoardOverlay::labelY \brief World height the value labels and marks anchor at. */
    property real labelY: 6.0
    /*! \qmlproperty real BoardOverlay::tagY */
    property real tagY: 7.6
    /*! \qmlproperty real BoardOverlay::wireY */
    property real wireY: 0.6

    /*! \qmlproperty var BoardOverlay::attributes \readonly \brief The monitor's quantity keys. */
    readonly property var attributes: monitor ? monitor.quantities.map(q => q.key) : []

    /*!
        \qmlproperty string BoardOverlay::valueAttr
        \brief The attribute the value labels show; "" is off. Twin of \l showValues.
    */
    property string valueAttr: ""
    /*!
        \qmlproperty bool BoardOverlay::showValues
        \brief Labels on. Turning it on lights the first attribute; setting any attribute sets it.

        The bool survives as a two-way twin so every read-site, flow verb and
        committed figure script (\c {showValues = true}) keeps meaning something.
    */
    property bool showValues: false
    onShowValuesChanged: {
        if (showValues && valueAttr === "") valueAttr = attributes.length ? attributes[0] : ""
        else if (!showValues) valueAttr = ""
    }
    onValueAttrChanged: showValues = valueAttr !== ""
    /*! \qmlmethod void BoardOverlay::cycleValueAttr() \brief off → first → ... → off. */
    function cycleValueAttr() {
        const cyc = [""].concat(attributes)
        valueAttr = cyc[(cyc.indexOf(valueAttr) + 1) % cyc.length]
    }
    /*! \qmlproperty string BoardOverlay::wireAttr \brief The one attribute a wire reading rides on; the first quantity. */
    property string wireAttr: attributes.length ? attributes[0] : ""

    /*! \qmlproperty var BoardOverlay::tags \brief \c {{ id: attr }} - the pinned tags. */
    property var tags: ({})
    /*! \qmlmethod void BoardOverlay::setTag(int id, string attr) \brief Pins (or, with "", unpins) a tag. */
    function setTag(id, attr) {
        const m = Object.assign({}, tags)
        if (!attr) delete m[id]; else m[id] = attr
        tags = m
    }

    /*! \qmlmethod var BoardOverlay::state() \brief \c {{ valueAttr, tags }} for \c viewState(). */
    function state() { return { valueAttr: valueAttr, tags: Object.assign({}, tags) } }
    /*! \qmlmethod void BoardOverlay::load(var s) \brief Restores a \l state; tags on parts that no longer exist are dropped. */
    function load(s) {
        if (!s) return
        if (s.valueAttr !== undefined) valueAttr = s.valueAttr
        if (s.tags) {
            const m = {}
            for (const k in s.tags)
                if (board && board.partAt(parseInt(k)) !== null) m[k] = s.tags[k]
            tags = m
        }
    }

    Connections {
        target: root.board
        function onRemoved(id) { if (root.tags[id] !== undefined) root.setTag(id, null) }
        function onCleared() { root.tags = ({}) }
    }

    function project(x, y, z) {
        if (!view) return Qt.vector3d(0, 0, 0)
        return view.mapFrom3DScene(Qt.vector3d(x, y, z))
    }
    function clampX(sx, w) { return Math.max(2, Math.min(root.width - w - 2, sx - w / 2)) }
    function clampY(sy, h) { return Math.max(2, Math.min(root.height - h - 2, sy - h)) }

    // --- value labels -----------------------------------------------------------
    Repeater {
        model: root.showValues && root.board ? root.board.parts : []
        Rectangle {
            id: valueChip
            required property var modelData
            readonly property var screenAt: {
                root.board.rev; root.camera.scenePosition; root.camera.sceneRotation
                const e = root.board.partAt(modelData.id)
                if (!e) return Qt.vector3d(0, 0, 0)
                return root.project(root.board.cellX(e.col), root.labelY, root.board.cellZ(e.row))
            }
            visible: root.board.specOf(modelData.type).watch !== false && screenAt.z > 0
            x: root.clampX(screenAt.x, width)
            y: root.clampY(screenAt.y, height)
            width: valueText.width + 12
            height: LabTheme.px(20)
            radius: LabTheme.px(5)
            color: LabTheme.panel
            readonly property string sev: {
                root.board.rev; root.solved
                return root.severityOf(modelData.id, root.valueAttr)
            }
            border.color: sev === "warn" ? LabTheme.alarm : LabTheme.panelEdge
            border.width: LabTheme.px(1)
            opacity: 0.94
            Text {
                id: valueText
                anchors.centerIn: parent
                // magnitudes only: direction is what the chevrons are for
                text: {
                    root.board.rev; root.solved
                    return root.readingOf(valueChip.modelData.id, root.valueAttr)
                }
                color: valueChip.sev === "warn" ? LabTheme.alarm : LabTheme.primary
                font.pixelSize: LabTheme.fontSmall
                font.family: LabTheme.monoFont
            }
        }
    }
    // Wires carry one thing, so their labels ride only that attribute.
    Repeater {
        model: root.showValues && root.valueAttr === root.wireAttr && root.board ? root.board.wires : []
        Text {
            id: wireLabel
            required property var modelData
            readonly property var screenAt: {
                root.board.rev; root.camera.scenePosition; root.camera.sceneRotation
                const m = root.board.wireMid(modelData)
                return root.project(m.x, root.wireY, m.z)
            }
            readonly property var reading: { root.board.rev; root.solved; return root.wireReadingOf(modelData) }
            visible: root.showValues && screenAt.z > 0 && !root.hidden && reading !== null
            x: screenAt.x - width / 2
            y: screenAt.y - height / 2
            text: reading === null ? "" : reading
            color: LabTheme.inkSoft; font.pixelSize: LabTheme.fontSmall; font.bold: true
            font.family: LabTheme.monoFont
            style: Text.Outline; styleColor: LabTheme.paperDeep
        }
    }

    // --- watch marks: a tag in the curve's own colour --------------------------------
    Repeater {
        model: root.monitor ? root.monitor.watched : []
        WatchMark {
            id: mark
            required property var modelData
            readonly property int pid: modelData
            readonly property var screenAt: {
                root.board.rev; root.camera.scenePosition; root.camera.sceneRotation
                const e = root.board.partAt(pid)
                if (!e) return Qt.vector3d(0, 0, 0)
                return root.project(root.board.cellX(e.col), root.labelY, root.board.cellZ(e.row))
            }
            monitor: root.monitor
            target: pid
            label: { root.board.rev; return root.labelOf(pid) }
            visible: screenAt.z > 0 && root.monitor.isWatched(pid) && !root.hidden
            x: root.clampX(screenAt.x, width)
            // steps aside for the value label when values are on
            y: Math.max(2, Math.min(root.height - height - 2,
                                    screenAt.y - height - (root.showValues ? LabTheme.px(23) : 0)))
        }
    }

    // --- pinned tags ------------------------------------------------------------------
    Repeater {
        model: Object.keys(root.tags)
        Rectangle {
            id: tag
            required property string modelData
            readonly property int elId: parseInt(modelData)
            readonly property string attr: root.tags[modelData] || root.wireAttr
            readonly property var screenAt: {
                root.board.rev; root.camera.scenePosition; root.camera.sceneRotation
                const e = root.board.partAt(elId)
                if (!e) return Qt.vector3d(0, 0, 0)
                return root.project(root.board.cellX(e.col), root.tagY, root.board.cellZ(e.row))
            }
            readonly property string sev: {
                root.board.rev; root.solved
                return root.severityOf(elId, attr)
            }
            visible: root.board.partAt(elId) !== null && screenAt.z > 0 && !root.hidden
            x: root.clampX(screenAt.x, width)
            y: root.clampY(screenAt.y, height)
            width: tagText.width + 12
            height: LabTheme.px(20)
            radius: LabTheme.px(5)
            color: LabTheme.panel
            border.color: sev === "warn" ? LabTheme.alarm
                        : (root.monitor && root.monitor.isWatched(elId)) ? root.monitor.colorOf(elId)
                        : LabTheme.secondary
            border.width: LabTheme.px(2)
            opacity: 0.96
            Text {
                id: tagText
                anchors.centerIn: parent
                text: {
                    root.board.rev; root.solved
                    return tag.attr + " " + root.readingOf(tag.elId, tag.attr)
                }
                color: tag.sev === "warn" ? LabTheme.alarm : LabTheme.ink
                font.pixelSize: LabTheme.fontSmall; font.bold: true
                font.family: LabTheme.monoFont
            }
        }
    }
}
