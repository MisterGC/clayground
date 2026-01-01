// (c) Clayground Contributors - MIT License, see "LICENSE" file

/*!
    \qmltype Connector
    \inqmlmodule Clayground.Canvas
    \inherits QtQuick.Shapes::Shape
    \brief A visual line connecting two items with automatic position tracking.

    Connector draws a line between the centers of two items and automatically
    updates when either item moves. Useful for visualizing relationships or
    connections in diagrams and games.

    Example usage:
    \qml
    import Clayground.Canvas as Canv

    Canv.Connector {
        from: nodeA
        to: nodeB
        color: "green"
        strokeWidth: 3
        style: ShapePath.DashLine
    }
    \endqml

    \qmlproperty Item Connector::from
    \brief The source item to connect from. Required.

    \qmlproperty Item Connector::to
    \brief The target item to connect to. Required.

    \qmlproperty real Connector::strokeWidth
    \brief Width of the connector line.

    \qmlproperty color Connector::color
    \brief Color of the connector line.

    \qmlproperty ShapePath.StrokeStyle Connector::style
    \brief Style of the line (solid, dash, etc.).

    \qmlproperty var Connector::dashPattern
    \brief Custom dash pattern as an array of dash/gap lengths.
*/
import QtQuick
import QtQuick.Shapes

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
