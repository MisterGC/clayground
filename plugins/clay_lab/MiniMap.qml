// (c) Clayground Contributors - MIT License, see "LICENSE" file

import QtQuick

/*!
    \qmltype MiniMap
    \inqmlmodule Clayground.Lab
    \inherits LabPanel
    \brief The abstract view: a fitted 2D projection of the scene, drawn by the lab.

    Half of the highest-value pattern the labs know - \e {dual representation,
    one model}: the 3D scene shows what you built, this panel shows what it
    \e is, and both read the same data so they cannot disagree. Electronics
    draws a circuit diagram in one; street-network draws its lane graph.

    Both had implemented the same two things by hand: a fit-to-content
    projection (fit what \e exists, not the whole sheet - an empty board would
    otherwise squeeze the drawing into a corner) and the repaint plumbing that
    keeps a Canvas in step with a model that mutates in place. This owns both;
    the lab supplies \l bounds and a \l draw callback and nothing else.

    \l draw receives the context and a \c map with \c px(), \c py() and the
    scale \c s, so the lab's paint code never does arithmetic on the panel's
    size.

    \qml
    MiniMap {
        title: LabLang.t("plan.title")
        tag: "M"
        width: LabTheme.px(258); height: LabTheme.px(190)
        revision: root.graphRev
        emptyText: LabLang.t("plan.empty")
        bounds: RoadGraph.bounds(root.graph)          // {x0, y0, x1, y1, empty}
        draw: (ctx, map) => {
            for (const lane of root.net.lanes) {
                ctx.strokeStyle = LabTheme.muted.toString()
                ctx.beginPath()
                ctx.moveTo(map.px(lane.x0), map.py(lane.z0))
                ctx.lineTo(map.px(lane.x1), map.py(lane.z1))
                ctx.stroke()
            }
        }
    }
    \endqml

    \sa LabPanel, Plot2D
*/
LabPanel {
    id: root

    /*!
        \qmlproperty var MiniMap::bounds
        \brief What to fit, as \c {{x0, y0, x1, y1}} - or \c {{empty: true}}.

        Accepts \c z0 / \c z1 in place of \c y0 / \c y1, because a top-down
        view of a 3D scene is naturally expressed in x/z and re-labelling it at
        every call site is how a sign error gets in.
    */
    property var bounds: ({ empty: true })

    /*!
        \qmlproperty var MiniMap::draw
        \brief \c {(ctx, map) -> void}: the lab's paint code.
    */
    property var draw: (ctx, map) => { }

    /*!
        \qmlproperty int MiniMap::revision
        \brief Bump to repaint. The counter every in-place model needs.
    */
    property int revision: 0

    /*!
        \qmlproperty real MiniMap::contentPadding
        \brief Inset kept around the fitted content.
    */
    property real contentPadding: LabTheme.spaceXxl

    /*!
        \qmlproperty string MiniMap::emptyText
        \brief Drawn centred when \l bounds is empty.
    */
    property string emptyText: ""

    /*!
        \qmlproperty bool MiniMap::uniformScale
        \brief Keep the aspect ratio, so the shape stays the shape you built.

        Almost always what you want; turn it off only for a display whose two
        axes are different quantities.
    */
    property bool uniformScale: true

    /*!
        \qmlproperty var MiniMap::map
        \readonly
        \brief The live projection: \c {{s, sx, sy, ox, oy, px(), py(), width, height, empty}}.

        Available to bindings as well as to \l draw, for a lab that wants to
        put a QtQuick item at a projected point rather than paint it.
    */
    readonly property alias map: _canvas.map

    /*!
        \qmlmethod void MiniMap::repaint()
        \brief Force a repaint.
    */
    function repaint() { _canvas.requestPaint() }

    Canvas {
        id: _canvas
        width: root.body.width
        height: root.body.height

        readonly property var map: {
            root.revision
            const b = root.bounds ? root.bounds : { empty: true }
            const y0 = b.y0 !== undefined ? b.y0 : b.z0
            const y1 = b.y1 !== undefined ? b.y1 : b.z1
            const empty = !b || b.empty === true
                          || b.x0 === undefined || y0 === undefined
            const pad = root.contentPadding
            const w = Math.max(1, width), h = Math.max(1, height)
            if (empty)
                return { s: 1, sx: 1, sy: 1, ox: w / 2, oy: h / 2,
                         cx: 0, cy: 0, width: w, height: h, empty: true,
                         px: function (x) { return w / 2 + x },
                         py: function (y) { return h / 2 + y } }
            // a degenerate span (one part, a single road) must still produce a
            // finite scale, so the span has a floor rather than a guard
            const spanX = Math.max(1e-3, b.x1 - b.x0)
            const spanY = Math.max(1e-3, y1 - y0)
            let sx = (w - 2 * pad) / spanX
            let sy = (h - 2 * pad) / spanY
            if (sx <= 0) sx = 1
            if (sy <= 0) sy = 1
            if (root.uniformScale) { const s = Math.min(sx, sy); sx = s; sy = s }
            const cx = (b.x0 + b.x1) / 2, cy = (y0 + y1) / 2
            const ox = w / 2, oy = h / 2
            return { s: Math.min(sx, sy), sx: sx, sy: sy, ox: ox, oy: oy,
                     cx: cx, cy: cy, width: w, height: h, empty: false,
                     px: function (x) { return ox + (x - cx) * sx },
                     py: function (y) { return oy + (y - cy) * sy } }
        }

        onMapChanged: requestPaint()
        Connections {
            target: LabTheme
            function onModeChanged() { _canvas.requestPaint() }
            function onUiScaleChanged() { _canvas.requestPaint() }
        }
        Connections {
            target: LabLang
            function onLangChanged() { _canvas.requestPaint() }
        }

        onPaint: {
            const ctx = getContext("2d")
            ctx.reset()
            if (map.empty) {
                if (root.emptyText === "") return
                ctx.fillStyle = LabTheme.inkFaint.toString()
                // quoted: a family with a space in it is not a valid CSS font
                // shorthand unquoted, and the whole declaration is then dropped
                ctx.font = LabTheme.fontBody + 'px "' + LabTheme.handFont + '"'
                ctx.textAlign = "center"
                ctx.fillText(root.emptyText, width / 2, height / 2)
                ctx.textAlign = "left"
                return
            }
            if (root.draw) root.draw(ctx, map)
        }
    }
}
