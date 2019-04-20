import QtQuick 2.12
import "qrc:/" as LivLd

Item
{
    anchors.fill: parent
    LivLd.LiveLoader {
        anchors.fill: parent
        observed: "CoordCanvas.qml"
    }
}
