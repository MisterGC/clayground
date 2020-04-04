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
    property real xWu: 0
    property real yWu: 0

    property alias strokeWidth: shapePath.strokeWidth
    property alias strokeColor: shapePath.strokeColor
    property alias fillColor:   shapePath.fillColor

    x: canvas.xToScreen(xWu)
    y: canvas.yToScreen(yWu)

    Component {id: pathLine; PathLine {}}
    function addPoint(xWu, yWu) {
        let path = pathLine.createObject( shapePath,{});
        path.x = Qt.binding( function()
            {return (xWu - theShape.xWu) * canvas.pixelPerUnit;});
        path.y = Qt.binding( function()
            {return (theShape.yWu - yWu) * canvas.pixelPerUnit;});
        shapePath.pathElements.push(path);
        if (path.x > width) width =  path.x;
        if (path.y > height) height =  path.y;
    }

    ShapePath {
        id: shapePath
        strokeWidth: 2
        strokeColor: "black"
        fillColor: "transparent"
    }
}
