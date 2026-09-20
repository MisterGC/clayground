// (c) Clayground Contributors - MIT License, see "LICENSE" file

/*!
    \qmltype Poly
    \inqmlmodule Clayground.Canvas
    \inherits QtQuick.Shapes::Shape
    \brief A polygon or polyline shape defined by vertices in world units.

    Poly renders a shape from an array of vertex points in world coordinates.
    It can display as a closed polygon (with fill) or an open polyline.

    Example usage:
    \qml
    import Clayground.Canvas as Canv

    // Triangle
    Canv.Poly {
        canvas: myCanvas
        vertices: [
            {x: 0, y: 0},
            {x: 2, y: 0},
            {x: 1, y: 2}
        ]
        fillColor: "green"
        strokeColor: "darkgreen"
    }

    // Dashed path
    Canv.Poly {
        canvas: myCanvas
        vertices: [{x: -5, y: -5}, {x: -3, y: -3}, {x: -1, y: -3}]
        strokeColor: "purple"
        strokeStyle: ShapePath.DashLine
    }

    // A chalk line, half drawn
    Canv.Poly {
        canvas: myCanvas
        vertices: [{x: 0, y: 0}, {x: 4, y: 1}, {x: 6, y: 0}]
        sketch: "chalk"
        progress: 0.5
    }
    \endqml

    \qmlproperty ClayCanvas Poly::canvas
    \brief The parent canvas for coordinate transformation. Required.

    \qmlproperty var Poly::vertices
    \brief Array of vertex points {x, y} in world units.

    \qmlproperty real Poly::strokeWidth
    \brief Width of the outline stroke in pixels.

    \qmlproperty color Poly::strokeColor
    \brief Color of the outline stroke.

    \qmlproperty color Poly::fillColor
    \brief Fill color. Use "transparent" for polyline (no fill).

    \qmlproperty ShapePath.StrokeStyle Poly::strokeStyle
    \brief Style of the stroke (solid, dash, etc.).

    \qmlproperty var Poly::dashPattern
    \brief Custom dash pattern as an array of dash/gap lengths.

    \qmlproperty bool Poly::closed
    \readonly
    \brief Whether the shape is closed. True when fillColor is not transparent.

    \qmlproperty string Poly::sketch
    \brief The pen: "none" (default), "chalk" or "marker".

    "chalk" draws a wobbly, slightly jagged line with a wider, fainter grain
    pass beside it; "marker" a smooth slow wobble with round caps. The
    vertices themselves are never moved, so a stroke starts and ends where it
    was asked to.

    \qmlproperty real Poly::progress
    \brief How much of the outline is drawn, 0 to 1 along its length from the first vertex. Default 1.

    \qmlproperty int Poly::seed
    \brief Which wobble a sketched stroke gets. Two polys with the same seed and vertices draw the same line. Default 0.

    \qmlmethod void Poly::refresh()
    \brief Refreshes the shape visualization after vertex changes.
*/
import QtQuick
import QtQuick.Shapes
import "sketch.js" as Sketch

Shape {
    id: theShape

    property ClayCanvas canvas: null
    parent: canvas ? canvas.coordSys : null

    property alias _shapePath: theShapePath
    property alias _grainPath: grainPath
    property alias strokeWidth: theShapePath.strokeWidth
    property alias strokeColor: theShapePath.strokeColor
    property alias fillColor:   theShapePath.fillColor
    property alias strokeStyle: theShapePath.strokeStyle
    property alias dashPattern: theShapePath.dashPattern
    // Qt.colorEqual, not `!=`: a color compared to a string is compared as
    // its "#aarrggbb" text, which never equals "transparent" - every Poly
    // used to be closed, dashed paths included.
    property bool closed: !Qt.colorEqual(fillColor, "transparent")

    property string sketch: "none"
    property real progress: 1
    property int seed: 0
    readonly property var _look: Sketch.look(sketch)
    readonly property real _progress: Math.max(0, Math.min(1, progress))

    Component.onCompleted: refresh();

    property var vertices: []

    property real _xWu: 0
    property real _yWu: 0
    property real _widthWu: 0
    property real _heightWu: 0
    x: canvas ? canvas.xToScreen(_xWu) : 0
    y: canvas ? canvas.yToScreen(_yWu) : 0
    width: _widthWu * (canvas ? canvas.pixelPerUnit : 0)
    height: _heightWu * (canvas ? canvas.pixelPerUnit : 0)
    // A sketched stroke is resampled when its length in pixels crosses a
    // STEP: the sample spacing is a pixel thing, and the canvas has neither
    // its size nor its zoom yet when a poly first completes.
    readonly property int _pieces: Sketch.isSketch(sketch) && canvas
        ? Sketch.pieces(Sketch.polyLength(vertices) * canvas.pixelPerUnit, Sketch.STEP) : 1
    onVerticesChanged: refresh()
    onSketchChanged: refresh()
    onSeedChanged: refresh()
    onClosedChanged: refresh()
    on_PiecesChanged: refresh()
    function refresh() { _syncVisu(); }
    function _syncVisu() {
        theShapePath.pathElements = [];
        grainPath.pathElements = [];
        let verts = theShape.vertices;

        let xMin = Number.MAX_VALUE;
        let yMin = Number.MAX_VALUE;
        let xMax = -Number.MAX_VALUE;
        let yMax = -Number.MAX_VALUE;
        for (const p of verts)  {
         if (p.x < xMin) xMin = p.x;
         if (p.y < yMin) yMin = p.y;
         if (p.x > xMax) xMax = p.x;
         if (p.y > yMax) yMax = p.y;
        }
        theShape._xWu = xMin;
        theShape._yWu = yMax;
        theShape._widthWu = (xMax - xMin)
        theShape._heightWu = (yMax - yMin)

        if (verts.length === 0) return;
        let pts = verts.slice();
        if (closed) pts.push(verts[0]);

        if (!Sketch.isSketch(theShape.sketch)) {
            for (const [i, v] of pts.entries())
                _addPoint(theShapePath, v, i === 0, 0, 0, 0);
            return;
        }

        // The hand samples the stroke every STEP pixels, taken in world units
        // at the current scale (see _pieces). The sideways offset per sample
        // is bound to the stroke width, so a heavier pen wobbles more.
        const ppu = (canvas && canvas.pixelPerUnit > 0) ? canvas.pixelPerUnit : 1;
        const samples = Sketch.sample(pts, Sketch.STEP / ppu);
        for (const [k, s] of samples.entries()) {
            const o = Sketch.offset(k, theShape.seed, theShape._look);
            _addPoint(theShapePath, s, k === 0, s.nx, s.ny, s.vertex ? 0 : o);
        }
        if (!theShape._look.grain) return;
        // The grain is the same stroke with another wobble: chalk dust lies
        // beside the line, not on it, so the two must not coincide.
        for (const [k, s] of samples.entries()) {
            const o = Sketch.offset(k, theShape.seed + 1000, theShape._look);
            _addPoint(grainPath, s, k === 0, s.nx, s.ny, s.vertex ? 0 : o);
        }
    }

    Component {id: pathLine; PathLine {}}
    // `off` is the sideways displacement in stroke widths along the world
    // normal (nx, ny); the screen y axis runs the other way, hence the minus.
    function _addPoint(path, vertex, isStart, nx, ny, off) {
        let xWu = vertex.x
        let yWu = vertex.y
        const dx = nx * off, dy = -ny * off;
        if (!isStart){
            let el = pathLine.createObject(path, {});
            el.x = Qt.binding( function()
            {return (xWu - theShape._xWu) * canvas.pixelPerUnit + dx * theShapePath.strokeWidth;});
            el.y = Qt.binding( function()
            {return (theShape._yWu - yWu) * canvas.pixelPerUnit + dy * theShapePath.strokeWidth;});
            path.pathElements.push(el);
        }
        else {
            path.startX = Qt.binding( function()
            {return (xWu - theShape._xWu) * canvas.pixelPerUnit;});
            path.startY = Qt.binding( function()
            {return (theShape._yWu - yWu) * canvas.pixelPerUnit;});
        }
    }

    ShapePath {
        id: theShapePath
        strokeWidth: 2
        strokeColor: "black"
        fillColor: "transparent"
        capStyle: Sketch.isSketch(theShape.sketch) ? ShapePath.RoundCap : ShapePath.SquareCap
        joinStyle: Sketch.isSketch(theShape.sketch) ? ShapePath.RoundJoin : ShapePath.BevelJoin
        // One number on the renderer's side: the path is cut at this share of
        // its length, so drawing an item on costs no rebuild per frame.
        trim.end: theShape._progress
    }

    ShapePath {
        id: grainPath
        strokeWidth: theShapePath.strokeWidth * theShape._look.grainWidth
        strokeColor: Qt.rgba(theShapePath.strokeColor.r, theShapePath.strokeColor.g,
                             theShapePath.strokeColor.b,
                             theShapePath.strokeColor.a * theShape._look.grainAlpha)
        fillColor: "transparent"
        capStyle: ShapePath.RoundCap
        joinStyle: ShapePath.RoundJoin
        trim.end: theShape._progress
    }
}
