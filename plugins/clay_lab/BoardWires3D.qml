// (c) Clayground Contributors - MIT License, see "LICENSE" file

import QtQuick
import QtQuick3D
import Clayground.Canvas3D
import Clayground.Lab

/*!
    \qmltype BoardWires3D
    \inqmlmodule Clayground.Lab
    \brief Every wire on a \l Board as one flat instanced line batch, plus the dangling preview.

    Wires lie flat on the board as one \c LineBatch3D: that is what buys a
    flowing animation along them, it stays a single draw call however many
    wires the board grows, and a line lying on the paper casts no shadow, so
    the shadow question is simply gone. Two lines per wire when something
    flows: the ink body and a chevron overlay riding a hair above it, marching
    at one of \l flowSteps speeds.

    The board owns the geometry; the domain owns what a wire carries. \l lineOf
    is asked once per wire and says how to draw it - the circuit kit colours a
    hot wire in alarm ink and picks the chevron speed relative to the largest
    current on the board, so a junction visibly splits.

    \qml
    BoardWires3D {
        board: board; y: stage.overlayMaxY; clock: clock; solved: root.sim
        lineOf: (w, pts, hovered) => root.wireLine(w, pts, hovered)
    }
    \endqml

    \sa Board, LineBatch3D, LabStage3D
*/
Node {
    id: root

    /*! \qmlproperty Board BoardWires3D::board */
    property var board: null
    /*! \qmlproperty real BoardWires3D::y \brief Height above the board the wires are drawn at (the stage's overlay budget). */
    property real y: 0.12
    /*! \qmlproperty var BoardWires3D::clock \brief The \l SimClock the flow animation runs on - deterministic, never a wall clock. */
    property var clock: null
    /*!
        \qmlproperty var BoardWires3D::solved
        \brief Bind the domain's solve result here; the lines are rebuilt whenever it changes.
    */
    property var solved: null
    /*! \qmlproperty int BoardWires3D::flowSteps \brief How many chevron speeds there are. */
    readonly property int flowSteps: 6

    /*!
        \qmlproperty var BoardWires3D::lineOf
        \brief \c {(wire, points, hovered) -> { color, width, styleId, flow }}.

        \c flow is null for an idle wire, or \c {{ reverse, color, width, styleId }}
        for the chevron overlay - \c reverse draws it the other way round, which
        is how a negative current points its arrows. \l flowStyle turns a 0..1
        share of the board's maximum into a \c styleId. The default draws a
        quiet ink line and never flows.
    */
    property var lineOf: (w, pts, hovered) => ({
        color: hovered ? (board.eraser ? LabTheme.alarm : LabTheme.secondary) : LabTheme.ink,
        width: 0.5, styleId: 0, flow: null
    })

    /*! \qmlproperty color BoardWires3D::previewColor \brief The dangling wire's ink. */
    property color previewColor: LabTheme.secondary
    /*! \qmlproperty real BoardWires3D::previewWidth */
    property real previewWidth: 0.4

    /*!
        \qmlmethod int BoardWires3D::flowStyle(real rel)
        \brief Style 0 for no flow, else 1..\l flowSteps from a 0..1 share of the maximum.
    */
    function flowStyle(rel) {
        if (!(rel > 0)) return 0
        return 1 + Math.min(flowSteps - 1, Math.max(0, Math.round((flowSteps - 1) * rel)))
    }

    /*! \qmlmethod var BoardWires3D::pathOf(var wire) \brief The drawn path as vector3d points at \l y. */
    function pathOf(w) {
        return board.wirePath(w).map(q => Qt.vector3d(q.x, root.y, q.z))
    }
    /*! \qmlmethod vector3d BoardWires3D::midOf(var wire) \brief Where a reading belongs - half the wire's length along it. */
    function midOf(w) {
        const m = board.wireMid(w)
        return Qt.vector3d(m.x, root.y, m.z)
    }

    /*!
        \qmlproperty var BoardWires3D::lines
        \readonly
        \brief What the batch draws; rebuilt on every board change, hover, eraser flip and \l solved.
    */
    readonly property var lines: {
        if (!board) return []
        board.rev; board.hoverHit; board.eraser; root.solved
        const out = []
        for (const w of board.wires) {
            const pts = pathOf(w)
            if (pts.length < 2) continue
            const hovered = board.hoverHit !== null && board.hoverHit.kind === "wire"
                            && board.hoverHit.wire === w.id
            const l = lineOf(w, pts, hovered)
            out.push({ points: pts, color: l.color, width: l.width, styleId: l.styleId || 0 })
            if (!l.flow) continue
            // The dash phase runs continuously along a polyline (LineBatch3D
            // packs the accumulated path distance per segment), so the
            // chevrons march round the corners instead of restarting at each
            const flow = l.flow.reverse ? pts.slice().reverse() : pts
            out.push({ points: flow.map(p => Qt.vector3d(p.x, p.y + 0.05, p.z)),
                       color: l.flow.color, width: l.flow.width, styleId: l.flow.styleId })
        }
        return out
    }

    LineBatch3D {
        widthUnits: LineBatch3D.World
        orientation: LineBatch3D.Flat     // ribbons lie in the board plane
        opaque: true                      // crossings resolve by depth
        depthBias: 4
        castsShadows: false
        flowTime: root.clock ? root.clock.time : 0
        flowAutoPlay: false
        styles: [
            { dash: [0, 0], capRound: true, opacity: 1.0 },
            // deliberately unhurried: the flow is there to be read, not to
            // make the board feel busy
            { dash: [1.4, 3.4], pattern: "chevron", flow: 1.0 },
            { dash: [1.4, 3.4], pattern: "chevron", flow: 1.8 },
            { dash: [1.4, 3.4], pattern: "chevron", flow: 2.8 },
            { dash: [1.4, 3.4], pattern: "chevron", flow: 4.0 },
            { dash: [1.4, 3.4], pattern: "chevron", flow: 5.4 },
            { dash: [1.4, 3.4], pattern: "chevron", flow: 7.0 }
        ]
        lines: root.lines
    }

    // The dangling wire: flat, and routed like the real thing, so what you
    // see while dragging is the wire you get when you let go.
    MultiLine3D {
        visible: root.board !== null && root.board.wiringFrom !== null
        coords: {
            if (!root.board || !root.board.wiringFrom) return []
            root.board.rev
            const c = root.board.cursorW
            const p = root.board.previewPath(root.board.wiringFrom, { x: c.x, z: c.z })
            return [p.map(q => Qt.vector3d(q.x, root.y, q.z))]
        }
        color: root.previewColor
        width: root.previewWidth
    }
}
