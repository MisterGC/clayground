import QtQuick 2.12
import "qrc:/" as LivLd

Item
{
    anchors.fill: parent

Timer {
    interval: 500
    running: true
    repeat: true

    onTriggered: {
        var newAngle = Math.random() * (Math.PI * 2);
        //theAngle.updateAngle(newAngle);
    }
}

LivLd.LiveLoader {
    anchors.fill: parent
    observed: "CoordCanvas.qml"
}

Text {
    id: theLabel
    text: "or somewhere else?"
    font.pixelSize: parent.height / 14
    anchors.horizontalCenter: parent.horizontalCenter
    anchors.bottom: parent.bottom
    anchors.bottomMargin: 10
}

MouseArea {
    anchors.fill: parent
    onMouseXChanged: updateAngle()
    onMouseYChanged: updateAngle()
    function updateAngle()
    {
       var vec = Qt.vector2d(mouseX - width/2, mouseY - height/2);
       var r = vec.length();
       var alpha = Math.acos(vec.x/r);
       if (vec.y < 0) {
           if (x < 0)
               alpha = Math.PI - (alpha - Math.PI);
           else
               alpha = (2 * Math.PI) - alpha;
       }

       theAngle.updateAngle(alpha);
    }

}
}
