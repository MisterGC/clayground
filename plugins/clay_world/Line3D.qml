import QtQuick
import QtQuick3D

Model {
    id: _line
    property var coords: []
    property color color: "black"
    property real width: 1

    MultiLine3D {
        coords: [_line.coords]
        color: _line.color
        width: _line.width
    }

}
