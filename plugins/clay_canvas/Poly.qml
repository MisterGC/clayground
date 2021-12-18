// (c) serein.pfeiffer@gmail.com - zlib license, see "LICENSE" file

import QtQuick
import QtQuick.Shapes

/** Represents both a polygon and a polyline as it is based on Shape with ShapePath */
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
