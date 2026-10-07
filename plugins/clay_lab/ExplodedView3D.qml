// (c) Clayground Contributors - MIT License, see "LICENSE" file

import QtQuick
import QtQuick3D
import Clayground.Canvas3D
import Clayground.Lab
import "explode.js" as Explode

/*!
    \qmltype ExplodedView3D
    \inqmlmodule Clayground.Lab
    \ingroup lab-flow
    \brief Any composition of named parts comes apart along its axes, staged and labelled, by id.

    The subject contract of a lab: a \c Node whose \l ExplodePart children
    are the rows of a part table (ids, roles, teaching order, offsets,
    anchors), and the one place every lesson mechanism resolves a part's
    name - \l partAt for a mark, the finger, the camera and a card. Nothing
    in this file knows what the assembly is, and that is the point: a
    transistor, a valve or a gearbox is a file of parts, and the mechanism -
    the glide, the stages, the focus dimming, the assembly lines, the labels
    - is here.

    Like the classic engineering drawing: every part travels along its own
    \c offset, along one axis or several, and a dashed assembly line runs
    from where it sat to where it is. Parts declare a \c stage, so the shell
    comes off at \c {spread 1} and what is inside comes apart at \c {spread
    2}; a part may contain parts, a sub-assembly that leaves as a whole and
    then opens on its own.

    Goal and interpolant are two properties: \l spread and \l focus are what
    a flow step sets and an \c expect asserts; \l spreadNow and \l focusNow
    are what the frame draws. \c Lab.runFlow() steps sim time without an
    event loop, so an interpolant can never be asserted headless - only the
    goal can. Where a camera has to hold the whole explosion, \l partAt with
    a second argument answers where a part is GOING.

    The parts are moved imperatively, from one handler, rather than by each
    part binding its own position to the view: a part authored with a plain
    \c position is readable next to the models it has to match silhouettes
    with; the same part written as an offset arithmetic binding is not.

    \qml
    ExplodedView3D {
        id: assembly
        spread: 0                      // goal: 0 assembled .. stages exploded
        focus: ""                      // goal: a part id, or nothing
        labelled: "all"                // which parts carry a label
        labels: ({ "case": LabLang.t("anatomy.case") })
        ExplodePart { row: Anatomy.partById("case"); position: ...; Model { ... } }
        ExplodePart { row: Anatomy.partById("die");  position: ...
            ExplodePart { row: Anatomy.partById("die.base"); ... }   // nested
        }
    }
    MarkLayer { marks: assembly.marks; view: view3d; camera: view3d.camera }
    \endqml

    \sa ExplodePart, MarkLayer, CameraDirector
*/
Node {
    id: root

    /*!
        \qmlproperty real ExplodedView3D::spread
        \brief The goal: 0 assembled, 1 the first stage fully out, 2 the
        second, up to \l stages. Fractions are part-way through a stage.
    */
    property real spread: 0

    /*!
        \qmlproperty real ExplodedView3D::spreadNow
        \brief The interpolant \l spread eases toward, over \l glideMs.
    */
    readonly property real spreadNow: _glide.value

    /*!
        \qmlproperty string ExplodedView3D::focus
        \brief The goal: the id of the part to look at. Every part that is
        not it, not above it and not inside it fades to \l dimOpacity. Empty
        means nothing is focused and all parts are drawn fully.
    */
    property string focus: ""

    /*!
        \qmlproperty real ExplodedView3D::focusNow
        \brief The interpolant of \l focus: how far the dimming has arrived,
        0 (nothing dimmed) to 1 (the unfocused parts sit at \l dimOpacity).
        Moving the focus from one part straight to another is a cut, not a
        crossfade.
    */
    readonly property real focusNow: _focusGlide.value

    /*!
        \qmlproperty real ExplodedView3D::unit
        \brief Scales every part's offset - how far apart "fully exploded" is.
    */
    property real unit: 1.0

    /*!
        \qmlproperty real ExplodedView3D::dimOpacity
        \brief How far an unfocused part fades.
    */
    property real dimOpacity: 0.25

    /*!
        \qmlproperty int ExplodedView3D::glideMs
        \brief How long \l spreadNow and \l focusNow take to reach their
        goals. 0 applies a goal the instant it is set.
    */
    property int glideMs: 900

    /*!
        \qmlproperty var ExplodedView3D::labels
        \brief Part id to display text, the lesson's language. Data, never
        looked up here: the lab owns its strings. A part without an entry is
        labelled with its id.
    */
    property var labels: ({})

    /*!
        \qmlproperty var ExplodedView3D::labelled
        \brief Which parts carry a label: a list of ids in the order the
        marks are listed, or \c "all" for every explained part in teaching
        order. Ids the subject does not have are skipped.
    */
    property var labelled: []

    /*!
        \qmlproperty var ExplodedView3D::marks
        \brief One \c {{id, at, label}} per labelled part, \c at being
        \l partAt now - what a \l MarkLayer takes as its \c marks. Follows
        the parts as they travel.
    */
    readonly property var marks: {
        root._poseRev
        root.scenePosition
        root.sceneRotation
        const ids = Explode.labelledIds(root._table, root.labelled)
        const out = []
        for (let i = 0; i < ids.length; ++i) {
            const at = root.partAt(ids[i])
            if (at.x !== at.x) continue
            out.push({ id: ids[i], at: at, label: Explode.labelOf(ids[i], root.labels) })
        }
        return out
    }

    /*!
        \qmlproperty bool ExplodedView3D::assemblyLines
        \brief Draw the dashed line from each moved part's assembled place to
        where it is now.
    */
    property bool assemblyLines: true

    /*!
        \qmlproperty real ExplodedView3D::dashLength
        \brief A dash of an assembly line, in the assembly's units.
    */
    property real dashLength: 0.35

    /*!
        \qmlproperty real ExplodedView3D::dashGap
        \brief The gap between two dashes.
    */
    property real dashGap: 0.25

    /*!
        \qmlproperty real ExplodedView3D::lineWidth
        \brief The width of an assembly line, in world units.
    */
    property real lineWidth: 0.05

    /*!
        \qmlproperty color ExplodedView3D::lineColor
        \brief The ink of the assembly lines.
    */
    property color lineColor: LabTheme.inkSoft

    /*!
        \qmlproperty var ExplodedView3D::lines
        \brief One \c {{id, from, to}} per part that has left its place,
        plain triples in this Node's own frame: the assembly lines as
        numbers, for a check that never needs a picture.
    */
    readonly property var lines: root._lines

    /*!
        \qmlproperty bool ExplodedView3D::animating
        \brief True while anything is still moving toward its goal.
    */
    readonly property bool animating: Math.abs(_glide.value - root.spread) > 1e-4
                                      || Math.abs(_focusGlide.value - _focusGlide.goal) > 1e-4
                                      || root.otherAnimating

    /*!
        \qmlproperty bool ExplodedView3D::otherAnimating
        \brief For a subject that adds a glide of its own (an x-ray): bind
        this and \l animating covers it too.
    */
    property bool otherAnimating: false

    /*!
        \qmlproperty int ExplodedView3D::stages
        \brief The largest stage any part declares; \l spread runs 0 to this.
    */
    readonly property int stages: Explode.stagesOf(root._table)

    /*!
        \qmlproperty var ExplodedView3D::partIds
        \brief Every part's id, nested ones included, in document order.
    */
    readonly property var partIds: root._ids

    /*!
        \qmlproperty var ExplodedView3D::parts
        \brief The \l ExplodePart objects themselves, in the same order.
    */
    readonly property var parts: root._parts

    /*!
        \qmlproperty var ExplodedView3D::table
        \brief The part table as the parts declare it: one
        \c {{id, parent, role, order, stage, offset, anchor}} per part, plain
        numbers, in the same order as \l partIds.
    */
    readonly property var table: root._table

    /*!
        \qmlmethod vector3d ExplodedView3D::partAt(string id, real atSpread)

        The part's anchor in scene coordinates as it is NOW - assembled pose
        plus the current displacement of it and of every sub-assembly it
        sits in - for a fingertip, a ring or a card. With \a atSpread, where
        the anchor WILL be at that spread: the goal, for a camera that has
        to hold the whole explosion before it has happened.

        An unknown id answers \c {Qt.vector3d(NaN, NaN, NaN)} rather than
        throwing, because a lesson naming a part a subject does not have
        should show up as a mark that cannot be placed, not as a broken flow.
    */
    function partAt(id, atSpread) {
        const i = root._indexOf(id)
        if (i < 0) return Qt.vector3d(NaN, NaN, NaN)
        // Copied: a vector3d handed straight out is a live reference to the
        // property it came from, so two calls would answer the same object.
        const v = root._parts[i].anchorScene
        let out = Qt.vector3d(v.x, v.y, v.z)
        if (atSpread === undefined || atSpread === null) return out
        // Walk up the chain of parts this one sits in: each contributes the
        // difference between where it will be and where it is, mapped
        // through the frame its position is expressed in.
        for (let k = i; k >= 0; k = root._parentIndex[k]) {
            const p = root._parts[k]
            const now = Explode.displacement(p.offset, p.stage, _glide.value, root.unit)
            const then = Explode.displacement(p.offset, p.stage, atSpread, root.unit)
            const dx = then.x - now.x, dy = then.y - now.y, dz = then.z - now.z
            if (dx === 0 && dy === 0 && dz === 0) continue
            const frame = p.parent
            const a = frame.mapPositionToScene(p.position)
            const b = frame.mapPositionToScene(Qt.vector3d(p.position.x + dx, p.position.y + dy,
                                                           p.position.z + dz))
            out = Qt.vector3d(out.x + b.x - a.x, out.y + b.y - a.y, out.z + b.z - a.z)
        }
        return out
    }

    /*!
        \qmlmethod ExplodePart ExplodedView3D::partOf(string id)
        \brief The part with this id, or null.
    */
    function partOf(id) {
        const i = root._indexOf(id)
        return i < 0 ? null : root._parts[i]
    }

    /*!
        \qmlmethod list<string> ExplodedView3D::idsInOrder()
        \brief The ids a lesson walks: every part with \c {order > 0},
        ascending.
    */
    function idsInOrder() { return Explode.idsInOrder(root._table) }

    /*!
        \qmlmethod void ExplodedView3D::refresh()

        Collect the parts again - after a part was added or removed at run
        time. Parts declared in the file are collected on completion, so a
        static subject never calls this.
    */
    function refresh() { root._collect() }

    // --- internals -----------------------------------------------------------

    property var _parts: []
    property var _ids: []
    property var _table: []
    property var _parentIndex: []
    property var _lines: []
    property var _dashCoords: []
    property int _poseRev: 0

    function _indexOf(id) {
        for (let i = 0; i < root._table.length; ++i)
            if (root._table[i].id === id) return i
        return -1
    }

    // The interpolants live in their own objects so `spreadNow`/`focusNow`
    // can stay readonly and the Behavior has a plain, writable property to
    // intercept. A Behavior on a binding-driven property animates binding
    // updates too, which is why assigning the goal is all a caller ever has
    // to do.
    QtObject {
        id: _glide
        property real value: root.spread
        Behavior on value {
            enabled: root.glideMs > 0
            NumberAnimation { duration: root.glideMs; easing.type: Easing.InOutCubic }
        }
        onValueChanged: root._applyPose()
    }
    QtObject {
        id: _focusGlide
        readonly property real goal: root.focus === "" ? 0 : 1
        property real value: goal
        Behavior on value {
            enabled: root.glideMs > 0
            NumberAnimation { duration: root.glideMs; easing.type: Easing.InOutCubic }
        }
        onValueChanged: root._applyFade()
    }

    onUnitChanged: root._applyPose()
    onDashLengthChanged: root._applyPose()
    onDashGapChanged: root._applyPose()
    onFocusChanged: root._applyFocus()
    onDimOpacityChanged: root._applyFade()

    Component.onCompleted: root._collect()

    // Parts are found by walking the children for a duck-typed marker rather
    // than by type. A `default property list<ExplodePart>` would NOT parent
    // the parts into the 3D scene - they would never be drawn - and a type
    // check would refuse a subclass of ExplodePart that a subject might want.
    // The walk continues INTO a part, so a sub-assembly's parts are rows too,
    // with the part they sit in as their parent.
    function _collect() {
        const parts = [], table = [], parentIndex = []
        const walk = (n, parentIdx) => {
            const cs = n.children
            if (!cs) return
            for (let i = 0; i < cs.length; ++i) {
                const c = cs[i]
                if (c.partId !== undefined && c.offset !== undefined
                        && c.basePosition !== undefined) {
                    const idx = parts.length
                    parts.push(c)
                    parentIndex.push(parentIdx)
                    table.push({
                        id: c.partId,
                        parent: parentIdx < 0 ? "" : table[parentIdx].id,
                        role: c.role, order: c.order, stage: c.stage,
                        offset: { x: c.offset.x, y: c.offset.y, z: c.offset.z },
                        anchor: { x: c.anchor.x, y: c.anchor.y, z: c.anchor.z }
                    })
                    walk(c, idx)
                } else {
                    walk(c, parentIdx)
                }
            }
        }
        walk(root, -1)
        root._parts = parts
        root._parentIndex = parentIndex
        root._table = table
        root._ids = table.map(r => r.id)
        root._applyPose()
        root._applyFocus()
        root._applyFade()
    }

    function _applyPose() {
        const s = _glide.value
        const parts = root._parts
        for (let i = 0; i < parts.length; ++i) {
            const p = parts[i]
            const d = Explode.displacement(p.offset, p.stage, s, root.unit)
            const b = p.basePosition
            p.displacement = Qt.vector3d(d.x, d.y, d.z)
            p.position = Qt.vector3d(b.x + d.x, b.y + d.y, b.z + d.z)
        }
        // Every position is written before any line is read: a line's two
        // ends are scene positions, and a sub-assembly's parts move with it.
        const lines = [], coords = []
        for (let i = 0; i < parts.length; ++i) {
            const p = parts[i]
            const d = p.displacement
            if (d.x === 0 && d.y === 0 && d.z === 0) continue
            const a = root.mapPositionFromScene(p.assembledScene)
            const b = root.mapPositionFromScene(p.anchorScene)
            const from = { x: a.x, y: a.y, z: a.z }, to = { x: b.x, y: b.y, z: b.z }
            lines.push({ id: root._table[i].id, from: from, to: to })
            const ds = Explode.dashes(from, to, root.dashLength, root.dashGap)
            for (let k = 0; k < ds.length; ++k)
                coords.push([Qt.vector3d(ds[k][0].x, ds[k][0].y, ds[k][0].z),
                             Qt.vector3d(ds[k][1].x, ds[k][1].y, ds[k][1].z)])
        }
        root._lines = lines
        root._dashCoords = coords
        root._poseRev = root._poseRev + 1
    }

    function _applyFocus() {
        const dim = Explode.dimmedIds(root._table, root.focus)
        for (let i = 0; i < root._parts.length; ++i)
            root._parts[i].dimmed = dim.indexOf(root._table[i].id) >= 0
    }

    function _applyFade() {
        const fade = (1 - root.dimOpacity) * _focusGlide.value
        for (let i = 0; i < root._parts.length; ++i)
            root._parts[i].fade = fade
    }

    // One batch for every assembly line of the subject: the dashes are short
    // polylines in this Node's frame, so they turn and travel with it.
    MultiLine3D {
        visible: root.assemblyLines && root._dashCoords.length > 0
        coords: root._dashCoords
        color: root.lineColor
        width: root.lineWidth
    }
}
