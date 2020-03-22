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
import QtQuick 2.12
import Clayground.ScalingCanvas 1.0
import Clayground.SvgUtils 1.0

CoordCanvas
{
    id: theCanvas
    anchors.fill: parent
    pixelPerUnit: 30
    keyBoardNavigationEnabled: true

    worldXMin: 0
    worldXMax:  10
    worldYMin: 0
    worldYMax: 10

    SvgWriter {
        id: theWriter
        path: ClayLiveLoader.sandboxDir + "/../test.svg"

        Component.onCompleted:
        {
            begin(theCanvas.worldXMax - theCanvas.worldXMin,
                  theCanvas.worldYMax - theCanvas.worldYMin);

            let rcomp = JSON.stringify({component: "MyRect.qml"});
            rectangle(5, 6, 2.5, 2.5, rcomp)

            let ccomp = JSON.stringify({component: "MyCircle.qml"});
            circle(1.5, 1, 1, ccomp)
            circle(3.5, 3, 1, ccomp)

            let pcomp = JSON.stringify({component: "MyPolygon.qml"});
            let verts = [Qt.point(8,6),
                         Qt.point(10,6),
                         Qt.point(11,5),
                         Qt.point(10,4),
                         Qt.point(8,4),
                         Qt.point(9,5),
                         Qt.point(8,6)
                        ];
            polygon(verts, pcomp);

            end();
        }
    }

    Component {id: theRect; ScalingRectangle {}}
    Component {id: thePoly; ScalingPolygon {fillColor:"orange"}}

    SvgInspector
    {
        id: theSvgInspector
        property var objs: []

        Component.onCompleted: setSource(theWriter.path)
        onBegin: {
            for (let obj of objs) obj.destroy();
            objs = [];
        }

        onRectangle: {
            console.log("A rectangle: " + description)
            let obj = theRect.createObject(theCanvas,
                                           {canvas: theCanvas,
                                            color: "black",
                                            xWu:x,
                                            yWu:y,
                                            widthWu:width,
                                            heightWu:height });
            objs.push(obj);
        }

        onCircle: {
            console.log("A circle: " + description)
            let obj = theRect.createObject(theCanvas,
                                           {canvas: theCanvas,
                                            color: "black",
                                            xWu:x - radius,
                                            yWu:y + radius,
                                            widthWu: 2 * radius,
                                            heightWu: 2 * radius,
                                            radius: width * .5 });
            objs.push(obj);
        }

        onPolygon: {
            console.log("A polygon: " + description)
            let obj = thePoly.createObject(theCanvas,
                                           {canvas: theCanvas,
                                            xWu: points[0].x,
                                            yWu: points[0].y});
            for (let i = 1; i<points.length; ++i) {
                let p = points[i];
                obj.addPoint(p.x, p.y);
            }
            objs.push(obj);
        }
    }
}
