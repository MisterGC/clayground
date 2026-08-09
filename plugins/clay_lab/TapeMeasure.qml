// (c) Clayground Contributors - MIT License, see "LICENSE" file

import QtQuick
import Clayground.Lab
import "measure.js" as Measure

/*!
    \qmltype TapeMeasure
    \inqmlmodule Clayground.Lab
    \inherits HandheldInstrument
    \brief Clicked points chained into a run, with the length of every leg, the
    angle at every corner and the total on screen.

    A lab answers "what does this do" all day and "how far is that" never,
    because nothing could be asked. This is the asking: with the tape in hand a
    left click drops a point, the next one chains to it, and the picture
    carries its own dimensions. Dragging still moves the world - the camera is
    never taken away, whatever is in the hand.

    One of the two instruments the kernel ships in every lab, because every lab
    has a ground plane to measure on; a kit's own instruments (a voltmeter)
    come with the kit. See \l InstrumentBelt.

    \section2 It is a question, not scene state

    A measurement belongs to the moment it is taken. Backspace takes the last
    point back, Esc clears the run, and putting the tape away clears it too;
    nothing here goes into a lab's \c viewState, so a reload does not restore a
    question nobody is asking any more. \l {HandheldInstrument::pin}{Pinning}
    is the deliberate exception - that is what "this one is worth keeping"
    means, and it turns the reading into a probe the run record carries.

    \section2 Screen-space, for the same reason as CameraAnchorMark

    The ink is 2D and drawn over the view, not laid on the ground: world
    content is legitimately occluded by geometry, and a dimension that
    disappears into a house is worse than useless. Drawn as UI it cannot
    z-fight, keeps its pixel size at any distance, and stays readable close up
    over cars and parts.

    The arithmetic is not here either - it is \c measure.js, checked by
    \c {node measure.test.js}, so no length or angle is only as right as a
    screenshot looks.

    \sa HandheldInstrument, InstrumentBelt, CameraAnchorMark
*/
HandheldInstrument {
    id: root

    name: "dist"
    label: LabLang.t("hand.tape")
    glyph: "📏"
    pickKind: "point"
    unit: "u"

    /*! \qmlproperty real TapeMeasure::dotPx \brief Radius of a vertex dot, in pixels. */
    property real dotPx: 4

    /*! \qmlproperty real TapeMeasure::arcPx \brief Radius of the angle arc, in pixels. */
    property real arcPx: 26

    /*!
        \qmlproperty var TapeMeasure::readout
        \readonly
        \brief The whole measurement as data: segments, vertices and total.

        Straight out of \c measure.js, with this lab's unit and decimal
        notation already applied - what the overlay draws and what a test or an
        agent asserts against, so both read the same numbers.
    */
    readonly property var readout: Measure.readout(
        picks, (d) => LabLang.qty(d, root.unit), LabLang.decimalPoint)

    /*! \qmlproperty var TapeMeasure::lengths \readonly \brief Length of each leg. */
    readonly property var lengths: readout.segments.map(s => s.length)

    /*! \qmlproperty var TapeMeasure::angles \readonly \brief Angle at each interior corner, in degrees. */
    readonly property var angles: readout.vertices.map(v => v.deg)

    /*! \qmlproperty real TapeMeasure::total \readonly \brief Total length of the run. */
    readonly property real total: readout.total

    // the reading IS the total walked, which is what a pinned tape records
    value: total
    valueText: count > 1 ? readout.totalText || LabLang.qty(readout.total, unit) : ""

    // A pinned tape keeps measuring the same two places, so the snapshot is
    // the whole story - but it is computed rather than frozen, so a lab whose
    // points move (a tape clipped to something that drives off) reports the
    // truth rather than a memory.
    function sampler(snapshot) {
        return () => Measure.total(snapshot)
    }

    function info() {
        return { name: name, kind: pickKind, count: count, unit: unit,
                 value: value, text: valueText,
                 lengths: lengths, angles: angles, total: readout.total,
                 texts: readout.segments.map(s => s.text),
                 angleTexts: readout.vertices.map(v => v.text),
                 totalText: readout.totalText,
                 pinned: pinnedReadings.map(p => p.name) }
    }

    /*!
        \qmlproperty var TapeMeasure::plan
        \readonly
        \brief The run projected into view pixels - what the overlay draws.

        \c {{ pts, segs, verts, total }}, each entry carrying an \c ok that is
        false where a point sits behind the camera: that segment is not drawn,
        while the measurement itself is untouched. Walking behind your own tape
        measure must not delete it.

        Projected with the camera's motion as EXPLICIT dependencies - the
        \l WorldLabel trap: without the \c scenePosition / \c sceneRotation
        reads the whole overlay freezes the moment the camera moves.
    */
    readonly property var plan: {
        const out = { pts: [], segs: [], verts: [], total: null }
        const v = root.view
        if (!v || !v.camera) return out
        const cam = v.camera
        void cam.scenePosition
        void cam.sceneRotation
        const r = readout
        const to2d = (p) => {
            const s = v.mapFrom3DScene(Qt.vector3d(p.x, p.y === undefined ? 0 : p.y, p.z))
            return { x: s.x, y: s.y, ok: s.z > 0 }
        }
        for (const p of root.picks) out.pts.push(to2d(p))
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
        width: root.view ? root.view.width : 0
        height: root.view ? root.view.height : 0
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

    // --- what has been kept -------------------------------------------------
    // A pinned tape stays stretched where it was measured: it is a mounted
    // instrument now, so it survives the tape being put away, and the run
    // record has a column for it.
    Repeater {
        model: root.pinnedReadings.length
        delegate: Item {
            required property int index
            readonly property var rec: root.pinnedReadings[index]
            readonly property var scr: {
                const v = root.view
                if (!v || !v.camera || !rec || rec.at.length === 0) return null
                const cam = v.camera
                void cam.scenePosition
                void cam.sceneRotation
                const a = rec.at[rec.at.length - 1]
                const s = v.mapFrom3DScene(Qt.vector3d(a.x, a.y, a.z))
                return s.z > 0 ? s : null
            }
            visible: scr !== null
            x: scr ? scr.x : 0
            y: scr ? scr.y : 0
            Chip {
                filled: false
                text: parent.rec ? "📌 " + parent.rec.name + " " + parent.rec.text : ""
                x: LabTheme.px(10)
                y: -height / 2
            }
        }
    }
}
