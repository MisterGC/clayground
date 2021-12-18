// (c) serein.pfeiffer@gmail.com - zlib license, see "LICENSE" file

import QtQuick
import QtQuick.Shapes

/** Connects to item (incl. automatic position updates) */
Shape {
    id: shape
    required property Item from
    required property Item to
    visible: to && from

    property alias strokeWidth: path.strokeWidth
    property alias color: path.strokeColor
    property alias style: path.strokeStyle
    property alias dashPattern: path.dashPattern

    property var fromPos: from ? mapFromItem(from.parent,
                                      from.x + from.width * .5,
                                      from.y + from.height * .5) : Qt.vector2d(0,0)
    property var toPos: to ? mapFromItem(to.parent,
                                    to.x + to.width * .5,
                                    to.y + to.height * .5) : Qt.vector2d(0,0)

    ShapePath {
        id: path
        strokeWidth: 3; strokeColor: "black"; fillColor: "transparent"
        startX: shape.fromPos.x
        startY: shape.fromPos.y
        PathLine {
            x: shape.toPos.x
            y: shape.toPos.y
        }
    }
}
