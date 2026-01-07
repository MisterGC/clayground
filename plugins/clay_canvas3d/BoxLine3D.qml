import QtQuick
import QtQuick3D
import Clayground.World

/*!
    \qmltype BoxLine3D
    \inqmlmodule Clayground.Canvas3D
    \brief Renders a 3D line as connected box segments using GPU instancing.

    BoxLine3D creates thick, visible lines by rendering box-shaped segments
    between consecutive positions. This approach produces lines that look
    good from any viewing angle, unlike screen-space line rendering.

    Uses GPU instancing for efficient rendering.

    Example usage:
    \qml
    import Clayground.Canvas3D

    BoxLine3D {
        positions: [
            Qt.vector3d(0, 0, 0),
            Qt.vector3d(100, 50, 0),
            Qt.vector3d(200, 0, 0)
        ]
        width: 5.0
        color: "green"
    }
    \endqml

    \sa Line3D, LineInstancing
*/
Node {
    id: _boxLine

    /*!
        \qmlproperty list<vector3d> BoxLine3D::positions
        \brief List of 3D positions defining the line path.
    */
    property var positions: []

    /*!
        \qmlproperty real BoxLine3D::width
        \brief The width of the box-shaped line segments.

        Defaults to 1.
    */
    property real width: 1

    /*!
        \qmlproperty color BoxLine3D::color
        \brief The color of the line.

        Defaults to blue.
    */
    property color color: "blue"

    /*!
        \qmlproperty Material BoxLine3D::material
        \brief The material used for rendering.

        Defaults to a DefaultMaterial with diffuseColor set to color.
    */
    property Material material: DefaultMaterial {
        diffuseColor: _boxLine.color
    }

    property real _particleSize: 100

    Model {
        source: "#Cube"
        instancing: LineInstancing {
            positions: _boxLine.positions
            width: _boxLine.width
            color: _boxLine.color
        }
        materials: _boxLine.material
        scale: Qt.vector3d(1/_particleSize, 1/_particleSize, 1/_particleSize)
    }
}
