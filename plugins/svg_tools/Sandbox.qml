// (c) serein.pfeiffer@gmail.com - zlib license, see "LICENSE" file

import QtQuick 2.12
import Clayground.Canvas 1.0
import Clayground.SvgUtils 1.0

ClayCanvas
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

            let plcomp = JSON.stringify({component: "MyPolygon.qml"});
            verts = [Qt.point(3,8), Qt.point(4,8), Qt.point(4,7)];
            polyline(verts, pcomp);

            end();
        }
    }

    Component {id: theRect; ScalingRectangle {}}
    Component {id: thePoly; ScalingPoly {fillColor:"orange"}}

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

        function createPoly(points) {
            let obj = thePoly.createObject(theCanvas,
                                           {canvas: theCanvas,
                                            vertices: points
                                            });
            return obj;
        }


        onPolygon: {
            console.log("A polygon: " + description)
            let obj = createPoly(points);
            objs.push(obj);
        }

        onPolyline: {
            console.log("A polyline: " + description)
            let obj = createPoly(points);
            obj.fillColor = "transparent"
            objs.push(obj);
        }
    }
}
