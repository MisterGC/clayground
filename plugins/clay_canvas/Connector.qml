// (c) Clayground Contributors - MIT License, see "LICENSE" file

/*!
    \qmltype Connector
    \inqmlmodule Clayground.Canvas
    \inherits QtQuick.Shapes::Shape
    \brief A visual line connecting two items with automatic position tracking.

    Connector draws a line between the centers of two items and automatically
    updates when either item moves. Useful for visualizing relationships or
    connections in diagrams and games. Given a \l canvas, an end may also be
    a world point, and the line may end in an arrow head.

    Example usage:
    \qml
    import Clayground.Canvas as Canv

    Canv.Connector {
        from: nodeA
        to: nodeB
        color: "green"
        strokeWidth: 3
        style: ShapePath.DashLine
    }

    // An arrow between two world points, drawn in chalk
    Canv.Connector {
        canvas: myCanvas
        from: {x: 1, y: 1}
        to: {x: 5, y: 3}
        arrow: "to"
        sketch: "chalk"
    }
    \endqml

    \qmlproperty var Connector::from
    \brief The source end. An Item (its centre, or its edge with \l attach), or a {x, y} world point when \l canvas is set. Required.

    \qmlproperty var Connector::to
    \brief The target end, in the same forms as \l from. Required.

    \qmlproperty ClayCanvas Connector::canvas
    \brief The canvas whose world units a point end is given in, and whose camera the line follows. Optional for item ends.

    \qmlproperty string Connector::attach
    \brief Where the line meets an Item end: "center" (default) or "edge", the edge of its bounding box.

    \qmlproperty string Connector::arrow
    \brief Arrow heads: "none" (default), "to", "from" or "both".

    Drawn in the order a hand draws them when \l progress runs: the shaft,
    then the head at \l to, then the head at \l from.

    \qmlproperty real Connector::headSize
    \brief Length of an arrow head's barbs in pixels. Default 4 * strokeWidth + 4.

    \qmlproperty real Connector::strokeWidth
    \brief Width of the connector line.

    \qmlproperty color Connector::color
    \brief Color of the connector line.

    \qmlproperty ShapePath.StrokeStyle Connector::style
    \brief Style of the line (solid, dash, etc.).

    \qmlproperty var Connector::dashPattern
    \brief Custom dash pattern as an array of dash/gap lengths.

    \qmlproperty string Connector::sketch
    \brief The pen: "none" (default), "chalk" or "marker". See Poly::sketch.

    \qmlproperty real Connector::progress
    \brief How much of the connector is drawn, 0 to 1, shaft first and heads after. Default 1.

    \qmlproperty int Connector::seed
    \brief Which wobble a sketched line gets. Default 0.
*/
import QtQuick
import QtQuick.Shapes
import "sketch.js" as Sketch

Shape {
    id: shape
    required property var from
    required property var to
    visible: (to && from) ? true : false

    property ClayCanvas canvas: null
    property string attach: "center"
    property string arrow: "none"
    property real headSize: 4 * path.strokeWidth + 4
    property string sketch: "none"
    property real progress: 1
    property int seed: 0

    property alias strokeWidth: path.strokeWidth
    property alias color: path.strokeColor
    property alias style: path.strokeStyle
    property alias dashPattern: path.dashPattern
    property alias _shaftPath: path
    property alias _grainPath: grainPath
    property alias _headToPath: headTo
    property alias _headFromPath: headFrom

    readonly property var _look: Sketch.look(sketch)

    // mapFromItem() captures no dependency on where the camera is, so a
    // connector outside the canvas' content would keep its old pixels through
    // a pan or a zoom. _box() reads this tick, and the canvas' signals bump
    // it. A plain value written from a handler rather than a binding on the
    // canvas: bound, the tick's own chain re-entered _fromBox while it was
    // evaluating and Qt reported a binding loop.
    property int _camera: 0
    Connections {
        target: shape.canvas
        function onXInWUChanged() { shape._camera++ }
        function onYInWUChanged() { shape._camera++ }
        function onPixelPerUnitChanged() { shape._camera++ }
    }

    function _isItem(v) { return v && typeof v.mapToItem === "function" }

    // An end as a box in this shape's coordinates: an item's bounding box, or
    // a world point as a box with no extent.
    function _box(v) {
        var tick = shape._camera
        if (_isItem(v)) {
            var a = mapFromItem(v.parent, v.x, v.y)
            var b = mapFromItem(v.parent, v.x + v.width, v.y + v.height)
            return { cx: (a.x + b.x) / 2, cy: (a.y + b.y) / 2,
                     hw: Math.abs(b.x - a.x) / 2, hh: Math.abs(b.y - a.y) / 2 }
        }
        if (v && canvas) {
            var p = mapFromItem(canvas.coordSys, canvas.xToScreen(v.x), canvas.yToScreen(v.y))
            return { cx: p.x, cy: p.y, hw: 0, hh: 0 }
        }
        return { cx: 0, cy: 0, hw: 0, hh: 0 }
    }
    readonly property var _fromBox: _box(from)
    readonly property var _toBox: _box(to)

    property var fromPos: ({ x: _fromBox.cx, y: _fromBox.cy })
    property var toPos: ({ x: _toBox.cx, y: _toBox.cy })

    // The shaft's ends: the centres, or where the centre line leaves each box.
    readonly property var _a: attach === "edge"
        ? Sketch.boxEdge(_fromBox.cx, _fromBox.cy, _fromBox.hw, _fromBox.hh, _toBox.cx, _toBox.cy)
        : { x: _fromBox.cx, y: _fromBox.cy }
    readonly property var _b: attach === "edge"
        ? Sketch.boxEdge(_toBox.cx, _toBox.cy, _toBox.hw, _toBox.hh, _fromBox.cx, _fromBox.cy)
        : { x: _toBox.cx, y: _toBox.cy }

    readonly property real _len: Sketch.dist(_a, _b)
    readonly property real _nx: _len > 0 ? -(_b.y - _a.y) / _len : 0
    readonly property real _ny: _len > 0 ? (_b.x - _a.x) / _len : 0
    readonly property bool _headAtTo: arrow === "to" || arrow === "both"
    readonly property bool _headAtFrom: arrow === "from" || arrow === "both"
    // Ink: the shaft costs its length, a head its two barbs. One progress
    // number is split over the three, in drawing order.
    readonly property var _fractions: Sketch.split(
        [_len, _headAtTo ? 2 * headSize : 0, _headAtFrom ? 2 * headSize : 0], progress)
    readonly property var _headTo: Sketch.arrowHead(_a, _b, headSize)
    readonly property var _headFrom: Sketch.arrowHead(_b, _a, headSize)

    // A sketched shaft is a chain of samples every STEP pixels, each bound to
    // its share of the way from _a to _b plus its own sideways offset - so an
    // end that moves drags the whole wobble along without a rebuild. Only a
    // change in the number of samples rebuilds the chain.
    readonly property int _pieces: Sketch.isSketch(sketch) ? Sketch.pieces(_len, Sketch.STEP) : 1
    on_PiecesChanged: _rebuild()
    onSketchChanged: _rebuild()
    onSeedChanged: _rebuild()
    Component.onCompleted: _rebuild()

    Component { id: lineComp; PathLine {} }
    function _rebuild() {
        path.pathElements = []
        grainPath.pathElements = []
        _fill(path, seed)
        if (_look.grain) _fill(grainPath, seed + 1000)
    }
    function _fill(p, s) {
        const n = shape._pieces
        for (let k = 1; k < n; ++k) {
            const t = k / n
            const o = Sketch.offset(k, s, shape._look)
            let el = lineComp.createObject(p, {})
            el.x = Qt.binding(function() {
                return shape._a.x + (shape._b.x - shape._a.x) * t + shape._nx * o * path.strokeWidth })
            el.y = Qt.binding(function() {
                return shape._a.y + (shape._b.y - shape._a.y) * t + shape._ny * o * path.strokeWidth })
            p.pathElements.push(el)
        }
        let end = lineComp.createObject(p, {})
        end.x = Qt.binding(function() { return shape._b.x })
        end.y = Qt.binding(function() { return shape._b.y })
        p.pathElements.push(end)
    }

    ShapePath {
        id: path
        strokeWidth: 3; strokeColor: "black"; fillColor: "transparent"
        capStyle: Sketch.isSketch(shape.sketch) ? ShapePath.RoundCap : ShapePath.SquareCap
        joinStyle: Sketch.isSketch(shape.sketch) ? ShapePath.RoundJoin : ShapePath.BevelJoin
        startX: shape._a.x
        startY: shape._a.y
        trim.end: shape._fractions[0]
    }

    ShapePath {
        id: grainPath
        strokeWidth: path.strokeWidth * shape._look.grainWidth
        strokeColor: Qt.rgba(path.strokeColor.r, path.strokeColor.g, path.strokeColor.b,
                             path.strokeColor.a * shape._look.grainAlpha)
        fillColor: "transparent"
        capStyle: ShapePath.RoundCap
        joinStyle: ShapePath.RoundJoin
        startX: shape._a.x
        startY: shape._a.y
        trim.end: shape._fractions[0]
    }

    // A head is one stroke, barb - tip - barb, so a trim draws it the way a
    // hand does. The colour is cut rather than the elements, so an arrow can
    // be switched on without a rebuild.
    ShapePath {
        id: headTo
        strokeWidth: path.strokeWidth
        strokeColor: shape._headAtTo ? path.strokeColor : "transparent"
        fillColor: "transparent"
        capStyle: ShapePath.RoundCap
        joinStyle: ShapePath.RoundJoin
        startX: shape._headTo.left.x
        startY: shape._headTo.left.y
        PathLine { x: shape._headTo.tip.x; y: shape._headTo.tip.y }
        PathLine { x: shape._headTo.right.x; y: shape._headTo.right.y }
        trim.end: shape._headAtTo ? shape._fractions[1] : 0
    }

    ShapePath {
        id: headFrom
        strokeWidth: path.strokeWidth
        strokeColor: shape._headAtFrom ? path.strokeColor : "transparent"
        fillColor: "transparent"
        capStyle: ShapePath.RoundCap
        joinStyle: ShapePath.RoundJoin
        startX: shape._headFrom.left.x
        startY: shape._headFrom.left.y
        PathLine { x: shape._headFrom.tip.x; y: shape._headFrom.tip.y }
        PathLine { x: shape._headFrom.right.x; y: shape._headFrom.right.y }
        trim.end: shape._headAtFrom ? shape._fractions[2] : 0
    }
}
