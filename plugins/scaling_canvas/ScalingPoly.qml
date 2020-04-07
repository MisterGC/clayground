/*
 * This file is part of Clayground (https://github.com/MisterGC/clayground)
 *
 * This software is provided 'as-is', without any express or implied warranty.
 * In no event will the authors be held liable for any damages arising from
 * the use of this software.
 *
 * Permission is granted to anyone to use this software for any purpose,
 * including commercial applications, and to alter it and redistribute it
 * freely, subject to the following restrictions:
 *
 * 1. The origin of this software must not be misrepresented; you must not
 *    claim that you wrote the original software. If you use this software in
 *    a product, an acknowledgment in the product documentation would be
 *    appreciated but is not required.
 *
 * 2. Altered source versions must be plainly marked as such, and must not be
 *    misrepresented as being the original software.
 *
 * 3. This notice may not be removed or altered from any source distribution.
 *
 * Authors:
 * Copyright (c) 2019 Serein Pfeiffer <serein.pfeiffer@gmail.com>
 */
import QtQuick 2.0
import QtQuick.Shapes 1.14

/** Represents both a polygon and a polyline as it is based on Shape with ShapePath */
Shape {
    id: theShape

    property CoordCanvas canvas: null
    parent: canvas.coordSys

    property alias _shapePath: theShapePath
    property alias strokeWidth: theShapePath.strokeWidth
    property alias strokeColor: theShapePath.strokeColor
    property alias fillColor:   theShapePath.fillColor

    property real _xWu: 0
    property real _yWu: 0
    property real _widthWu: 0
    property real _heightWu: 0
    x: canvas.xToScreen(_xWu)
    y: canvas.yToScreen(_yWu)
    width: _widthWu * canvas.pixelPerUnit
    height: _heightWu * canvas.pixelPerUnit
    property var vertices: []
    onVerticesChanged: refresh()
    function refresh() { _syncVisu(); }
    function _syncVisu() {
        theShapePath.pathElements = [];

        let xMin = Number.MAX_VALUE;
        let yMin = Number.MAX_VALUE;
        let xMax = Number.MIN_VALUE;
        let yMax = Number.MIN_VALUE;
        for (const p of theShape.vertices)  {
         if (p.x < xMin) xMin = p.x;
         if (p.y < yMin) yMin = p.y;
         if (p.x > xMax) xMax = p.x;
         if (p.y > yMax) yMax = p.y;
        }
        theShape._xWu = xMin;
        theShape._yWu = yMax;
        theShape._widthWu = (xMax - xMin)
        theShape._heightWu = (yMax - yMin)

        for (const v of theShape.vertices) _addPoint(v);
    }

    Component {id: pathLine; PathLine {}}
    function _addPoint(vertex) {
        let xWu = vertex.x
        let yWu = vertex.y
        let path = pathLine.createObject( theShapePath,{});
        path.x = Qt.binding( function()
            {return (xWu - theShape._xWu) * canvas.pixelPerUnit;});
        path.y = Qt.binding( function()
            {return (theShape._yWu - yWu) * canvas.pixelPerUnit;});
        theShapePath.pathElements.push(path);
    }

    ShapePath {
        id: theShapePath
        strokeWidth: 2
        strokeColor: "black"
        fillColor: "transparent"
    }
}
