// (c) Clayground Contributors - MIT License, see "LICENSE" file

import QtQuick
import Clayground.Lab
import "measure.js" as Measure

/*!
    \qmltype MeasureTool
    \inqmlmodule Clayground.Lab
    \brief The tape measure: clicked points chained into a run, with the
    length of every leg, the angle at every corner and the total on screen.

    A lab answers "what does this do" all day and "how far is that" never,
    because nothing could be asked. This is the asking: in the pointer's
    \c measure mode a left click drops a point, the next one chains to it, and
    the picture carries its own dimensions.

    \section2 It is a question, not scene state

    A measurement belongs to the moment it is taken. Backspace takes the last
    point back, Esc clears the run, and \e leaving measure mode clears it too;
    nothing here goes into a lab's \c viewState, so a reload does not restore
    a question nobody is asking any more. Holding Space is the exception that
    proves it - the quasimode borrows the camera without touching \c mode, so
    a run survives being looked at from another angle.

    \section2 Screen-space, for the same reason as CameraAnchorMark

    The ink is 2D and drawn over the view, not laid on the ground: world
    content is legitimately occluded by geometry, and a dimension that
    disappears into a house is worse than useless. Drawn as UI it cannot
    z-fight, keeps its pixel size at any distance, and stays readable close up
    over cars and parts. Declare it as a direct child of the \c View3D, which
    is what puts it in the view's coordinate space and renders it above the
    scene.

    The arithmetic is not here either - it is \c measure.js, checked by
    \c {node measure.test.js}, so no length or angle is only as right as a
    screenshot looks.

    \qml
    View3D {
        OrbitInput3D { id: nav; rig: rig; view: parent; modes: ["explore", "measure"] }
        CameraAnchorMark { pointer: nav }
        MeasureTool { id: measure; pointer: nav; measureUnit: "m" }
    }
    LabKeys { pointer: nav; measure: measure }
    \endqml

    \sa OrbitInput3D, CameraAnchorMark, ModeChip
*/
Item {
    id: root

    /*!
        \qmlproperty var MeasureTool::pointer
        \brief The \c OrbitInput3D to take points from.

        Its \c pickedAt is what a click arrives as, and its \c mode is what
        tells the run when it is over.
    */
    property var pointer: null

    /*!
        \qmlproperty string MeasureTool::measureUnit
        \brief The unit the lab's world is in: \c "m", \c "mm", \c "u" ...

        The kernel cannot know - one lab's cell is a metre of tarmac and
        another's is a millimetre of board - so the lab says, and the SI
        prefixing (\c LabLang::qty) follows from it.
    */
    property string measureUnit: "u"

    /*! \qmlproperty color MeasureTool::tone \brief Ink for the line, dots and chips. */
    property color tone: LabTheme.primary

    /*! \qmlproperty real MeasureTool::dotPx \brief Radius of a vertex dot, in pixels. */
    property real dotPx: 4

    /*! \qmlproperty real MeasureTool::arcPx \brief Radius of the angle arc, in pixels. */
    property real arcPx: 26

    /*! \qmlproperty var MeasureTool::points \readonly \brief The run, as world points. */
    readonly property alias points: _s.points

    /*! \qmlproperty int MeasureTool::count \readonly \brief How many points are in the run. */
    readonly property int count: _s.points.length

    /*! \qmlproperty bool MeasureTool::empty \readonly \brief Nothing has been measured. */
    readonly property bool empty: count === 0

    /*!
        \qmlproperty var MeasureTool::readout
        \readonly
        \brief The whole measurement as data: segments, vertices and total.

        Straight out of \c measure.js, with this lab's unit and decimal
        notation already applied - what the overlay draws and what a test or
        an agent asserts against, so both read the same numbers.
    */
    readonly property var readout: Measure.readout(
        _s.points, (d) => LabLang.qty(d, root.measureUnit), LabLang.decimalPoint)

    /*! \qmlproperty real MeasureTool::total \readonly \brief Total length of the run. */
    readonly property real total: readout.total

    /*! \qmlproperty var MeasureTool::lengths \readonly \brief Length of each leg. */
    readonly property var lengths: readout.segments.map(s => s.length)

    /*! \qmlproperty var MeasureTool::angles \readonly \brief Angle at each interior corner, in degrees. */
    readonly property var angles: readout.vertices.map(v => v.deg)

    /*!
        \qmlmethod void MeasureTool::add(var p)
        \brief Chains a world point onto the run.
    */
    function add(p) {
        if (!p) return
        _s.points = _s.points.concat([Qt.vector3d(p.x, p.y === undefined ? 0 : p.y, p.z)])
    }

    /*!
        \qmlmethod void MeasureTool::undo()
        \brief Takes the last point back. Backspace and Delete.
    */
    function undo() {
        if (_s.points.length === 0) return
        _s.points = _s.points.slice(0, _s.points.length - 1)
    }

    /*!
        \qmlmethod void MeasureTool::clear()
        \brief Ends the run. Esc, and leaving measure mode.
    */
    function clear() {
        if (_s.points.length === 0) return
        _s.points = []
    }

    /*!
        \qmlmethod var MeasureTool::info()
        \brief The measurement as plain values, for an agent or a driver.
    */
    function info() {
        return { count: count, unit: measureUnit, lengths: lengths,
                 angles: angles, total: total,
                 texts: readout.segments.map(s => s.text),
                 angleTexts: readout.vertices.map(v => v.text),
                 totalText: readout.totalText }
    }

    QtObject {
        id: _s
        property var points: []
    }

    Connections {
        target: root.pointer
        function onPickedAt(p) { root.add(p) }
        // The STICKY mode, not the effective one: Space held is a borrowed
        // camera, not the end of the question being asked.
        function onModeChanged() {
            if (root.pointer.mode !== "measure") root.clear()
        }
    }

    /*!
        \qmlproperty var MeasureTool::plan
        \readonly
        \brief The run projected into view pixels - what the overlay draws.

        \c {{ pts, segs, verts, total }}, each entry carrying an \c ok that is
        false where a point sits behind the camera: that segment is not drawn,
        while the measurement itself is untouched. Walking behind your own
        tape measure must not delete it.

        Projected with the camera's motion as EXPLICIT dependencies - the
        \l WorldLabel trap: without the \c scenePosition / \c sceneRotation
        reads the whole overlay freezes the moment the camera moves.
    */
    readonly property var plan: {
        const out = { pts: [], segs: [], verts: [], total: null }
        const v = pointer ? pointer.view : null
        if (!v || !v.camera) return out
        const cam = v.camera
        void cam.scenePosition
        void cam.sceneRotation
        const r = readout
        const to2d = (p) => {
            const s = v.mapFrom3DScene(Qt.vector3d(p.x, p.y === undefined ? 0 : p.y, p.z))
            return { x: s.x, y: s.y, ok: s.z > 0 }
        }
        for (const p of _s.points) out.pts.push(to2d(p))
        for (const s of r.segments) {
            const a = to2d(s.a), b = to2d(s.b), m = to2d(s.mid)
            out.segs.push({ ax: a.x, ay: a.y, bx: b.x, by: b.y,
                            mx: m.x, my: m.y, text: s.text,
                            ok: a.ok && b.ok && m.ok })
        }
        for (const w of r.vertices) {
            const c = out.pts[w.i]
            const a = out.pts[w.i - 1], b = out.pts[w.i + 1]
            if (!c || !a || !b) continue
            const a1 = Math.atan2(a.y - c.y, a.x - c.x)
            const a2 = Math.atan2(b.y - c.y, b.x - c.x)
            // the short way round, which is the corner a protractor would be
            // laid into rather than the reflex angle behind it
            let d = a2 - a1
            while (d > Math.PI) d -= 2 * Math.PI
            while (d < -Math.PI) d += 2 * Math.PI
            const bis = a1 + d / 2
            out.verts.push({ x: c.x, y: c.y, start: a1, sweep: d,
                             lx: c.x + Math.cos(bis) * (root.arcPx + LabTheme.px(16)),
                             ly: c.y + Math.sin(bis) * (root.arcPx + LabTheme.px(16)),
                             text: w.text, ok: a.ok && b.ok && c.ok })
        }
        if (r.totalAt) {
            const t = to2d(r.totalAt)
            out.total = { x: t.x, y: t.y, text: r.totalText, ok: t.ok }
        }
        return out
    }

    // --- the ink -----------------------------------------------------------
    // One Canvas for everything drawn with a pen; the readings are Items above
    // it, so text stays crisp and never repaints with the line.
    Canvas {
        id: _ink
        width: root.pointer && root.pointer.view ? root.pointer.view.width : 0
        height: root.pointer && root.pointer.view ? root.pointer.view.height : 0
        visible: root.count > 0
        onPaint: {
            const ctx = getContext("2d")
            ctx.clearRect(0, 0, width, height)
            const pl = root.plan
            ctx.strokeStyle = root.tone
            ctx.fillStyle = root.tone
            ctx.lineWidth = 2

            ctx.setLineDash([6, 5])
            for (const s of pl.segs) {
                if (!s.ok) continue
                ctx.beginPath()
                ctx.moveTo(s.ax, s.ay)
                ctx.lineTo(s.bx, s.by)
                ctx.stroke()
            }

            ctx.setLineDash([])
            for (const w of pl.verts) {
                if (!w.ok) continue
                ctx.beginPath()
                ctx.arc(w.x, w.y, root.arcPx, w.start, w.start + w.sweep, w.sweep < 0)
                ctx.stroke()
            }

            for (let i = 0; i < pl.pts.length; ++i) {
                const p = pl.pts[i]
                if (!p.ok) continue
                ctx.beginPath()
                ctx.arc(p.x, p.y, root.dotPx, 0, 2 * Math.PI)
                ctx.fill()
                // the last point is the one the next click chains to, so it
                // wears a ring: the run has a live end, and it is visible
                if (i === pl.pts.length - 1) {
                    ctx.beginPath()
                    ctx.arc(p.x, p.y, root.dotPx + 4, 0, 2 * Math.PI)
                    ctx.stroke()
                }
            }
        }
        Connections {
            target: root
            function onPlanChanged() { _ink.requestPaint() }
            function onToneChanged() { _ink.requestPaint() }
        }
        onVisibleChanged: if (visible) requestPaint()
    }

    // --- the readings ------------------------------------------------------
    // A chip rather than bare text: these sit over a scene, and unbacked text
    // on a light road under a dark sky is legible in exactly one of the two.
    component Chip: Rectangle {
        property string text: ""
        property bool filled: true
        readonly property color fill: filled ? root.tone : LabTheme.panel
        color: fill
        border.color: root.tone
        border.width: LabTheme.borderWidth
        radius: LabTheme.radius
        implicitWidth: _t.implicitWidth + 2 * LabTheme.spaceM
        implicitHeight: _t.implicitHeight + LabTheme.spaceS
        width: implicitWidth
        height: implicitHeight
        Text {
            id: _t
            anchors.centerIn: parent
            text: parent.text
            color: LabTheme.inkOn(parent.fill)
            font.pixelSize: LabTheme.fontSmall
            font.family: LabTheme.monoFont
        }
    }

    Repeater {
        model: root.plan.segs.length
        delegate: Chip {
            required property int index
            readonly property var seg: root.plan.segs[index]
            visible: seg !== undefined && seg.ok
            text: seg ? seg.text : ""
            x: (seg ? seg.mx : 0) - width / 2
            y: (seg ? seg.my : 0) - height / 2
        }
    }

    Repeater {
        model: root.plan.verts.length
        delegate: Chip {
            required property int index
            readonly property var vert: root.plan.verts[index]
            visible: vert !== undefined && vert.ok
            filled: false
            text: vert ? vert.text : ""
            x: (vert ? vert.lx : 0) - width / 2
            y: (vert ? vert.ly : 0) - height / 2
        }
    }

    // Sigma rather than a word: the total is read at a glance, in any language.
    Chip {
        readonly property var t: root.plan.total
        visible: t !== null && t.ok
        text: t ? "Σ " + t.text : ""
        x: (t ? t.x : 0) + LabTheme.px(14)
        y: (t ? t.y : 0) + LabTheme.px(12)
    }
}
