// (c) Clayground Contributors - zlib license, see "LICENSE" file

import QtQuick
import Clayground.Canvas
import Clayground.Svg

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

    Component {
        id: svgSourceLoader
        SvgImageSource {
            Component.onCompleted: {
                console.log("Does element rect1 exist? " + has("rect1"))
                console.log("Does element rect2 exist? " + has("rect2"))
            }
            svgPath: "somegraphics"
        }
    }

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

    Component {id: theRect; Rectangle {}}
    Component {id: thePoly; Poly {fillColor:"orange"}}

    Timer {
        running: true; interval: 500;
        onTriggered: {
            console.log("Read the generated SVG:");
            theSvgReader.setSource(theWriter.path);

            console.log("\n\n")
            console.log("Read one sample SVG (created with Inkscape):")
            inkscapeSampleReader.setSource(ClayLiveLoader.sandboxDir + "/map.svg");

            console.log("\n\n")
            console.log("Check SVG Image Provider:")
            svgSourceLoader.createObject(theCanvas);
        }
    }

    // Read an SVG that has been created with the SVGWriter
    SvgReader
    {
        id: theSvgReader
        property var objs: []

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


        onPolygon: (points, description) => {
            console.log("A polygon: " + description)
            let obj = createPoly(points);
            objs.push(obj);
        }

        onPolyline: (points, description) => {
            console.log("A polyline: " + description)
            let obj = createPoly(points);
            obj.fillColor = "transparent"
            objs.push(obj);
        }
    }


    // Read an SVG that has been created with Inkscape
    SvgReader
    {
        id: inkscapeSampleReader
        property var objs: []

        onBegin: {
            for (let obj of objs) obj.destroy();
            objs = [];
        }

        onRectangle: (x, y, width, height) => {
            console.log("Rectangle{x:" + x.toFixed(2) +
                        " y:" + y.toFixed(2) +
                        " w:" + width.toFixed(2) +
                        " h:" + height.toFixed(2))
        }

        onBeginGroup: (name, description) => {console.log("groupid: " + name + " descr: " + description);}
        onEndGroup: {}
    }
}
