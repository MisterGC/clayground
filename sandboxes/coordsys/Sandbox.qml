import QtQuick 2.12
import "qrc:/" as LivLd
import Box2D 2.0
import GcPopulator 1.0

CoordCanvas
{
    id: theCanvas
    anchors.fill: parent

    Component.onCompleted: thePopulator.setPopulationModel("/home/mistergc/dev/qml_live_loader/plugins/populator/sample_level.svg")
    Component {
        id: rectCreator
        RectangleBoxBody {
            parent: coordSys
            pixelPerUnit: theCanvas.pixelPerUnit
            xWu: 10; yWu: 10; widthWu: 1; heightWu: 0.6;
            Component.onCompleted: console.log("x: " + x +
                                               " y:" + y +
                                               " width:" + width +
                                               " height:" + height );
        }
    }

    World {
        id: physicsWorld

        gravity: Qt.point(0,9.81)
        timeStep: 1/20.0
        pixelsPerMeter: 32.0
    }


    Populator
    {
        id: thePopulator
        property var objs: []

        onAboutToPopulate: {
            console.log("World: " + widthWu + "x" + heightWu + " Px: " + widthPx + "x" + heightPx)
            while(objs.length > 0) {
                var obj = objs.pop();
                obj.destroy();
            }
            theCanvas.worldXMax = widthWu;
            theCanvas.worldYMax = heightWu;
            console.log("WuWidth: " + widthWu  +" Width: " + theCanvas.coordSys.width)
        }
        onCreateItemAt: {
            console.log("Create item: " + componentName + " x: " + xWu + " y: " + yWu);
            var bt = componentName == "Table" ? Body.Static : Body.Dynamic;
            var clr = componentName == "Table" ? "brown" : "red";
            var obj = rectCreator.createObject(theCanvas.coordSys, {"xWu": xWu,
                                                                    "yWu": theCanvas.worldYMax - yWu,
                                                                    "bodyType": bt,
                                                                    "color": clr});
            objs.push(obj);
            console.log(obj.x + "," + obj.y);
        }
    }

}
