import QtQuick
import QtQuick3D

Model {
    property var coords: []
    property color color: _lineMat.lineColor
    property real width: _lineMat.lineWidth

    MultiLine3D {
        coords: [parent.coords]
        color: parent.color
        width: parent.width
    }

}
