import QtQuick 2.12
import "qrc:/" as LivLd
import Box2D 2.0

CoordCanvas
{
    id: theCanvas
    anchors.fill: parent
    RectangleBoxBody {
        color: "blue"
        parent: coordSys
        pixelPerUnit: theCanvas.pixelPerUnit
        xWu: 10; yWu: 10; widthWu: 1; heightWu: 1;
        Component.onCompleted: console.log("x: " + x +
                                           " y:" + y +
                                           " width:" + width +
                                           " height:" + height );
    }

    LivLd.LiveLoader{
        visible: false
        observed: "CoordCanvas.qml"
    }
}
