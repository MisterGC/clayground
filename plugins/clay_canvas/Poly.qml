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

    \qmlmethod void Poly::refresh()
    \brief Refreshes the shape visualization after vertex changes.
*/
import QtQuick
import QtQuick.Shapes

Shape {
    id: theShape

    property ClayCanvas canvas: null
    parent: canvas ? canvas.coordSys : null

    property alias _shapePath: theShapePath
    property alias strokeWidth: theShapePath.strokeWidth
    property alias strokeColor: theShapePath.strokeColor
    property alias fillColor:   theShapePath.fillColor
    property alias strokeStyle: theShapePath.strokeStyle
    property alias dashPattern: theShapePath.dashPattern
    property bool closed: (fillColor != "transparent")

    Component.onCompleted: refresh();

    property var vertices: []

    property real _xWu: 0
    property real _yWu: 0
    property real _widthWu: 0
    property real _heightWu: 0
    x: canvas ? canvas.xToScreen(_xWu) : 0
    y: canvas ? canvas.yToScreen(_yWu) : 0
    width: _widthWu * canvas ? canvas.pixelPerUnit : 0
    height: _heightWu * canvas ? canvas.pixelPerUnit : 0
    onVerticesChanged: refresh()
    function refresh() { _syncVisu(); }
    function _syncVisu() {
        theShapePath.pathElements = [];
        let verts = theShape.vertices;

        let xMin = Number.MAX_VALUE;
        let yMin = Number.MAX_VALUE;
        let xMax = Number.MIN_VALUE;
        let yMax = Number.MIN_VALUE;
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

        for (const [i, v] of verts.entries())
            _addPoint(v, i===0);
        if (verts.length > 0 && closed) _addPoint(verts[0]);
    }

    Component {id: pathLine; PathLine {}}
    function _addPoint(vertex, isStart) {
        let xWu = vertex.x
        let yWu = vertex.y
        if (!isStart){
            let path = pathLine.createObject( theShapePath,{});
            path.x = Qt.binding( function()
            {return (xWu - theShape._xWu) * canvas.pixelPerUnit;});
            path.y = Qt.binding( function()
            {return (theShape._yWu - yWu) * canvas.pixelPerUnit;});
            theShapePath.pathElements.push(path);
        }
        else {
            theShapePath.startX = Qt.binding( function()
            {return (xWu - theShape._xWu) * canvas.pixelPerUnit;});
            theShapePath.startY = Qt.binding( function()
            {return (theShape._yWu - yWu) * canvas.pixelPerUnit;});
        }
    }

    ShapePath {
        id: theShapePath
        strokeWidth: 2
        strokeColor: "black"
        fillColor: "transparent"
    }
}
