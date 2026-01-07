// (c) Clayground Contributors - MIT License, see "LICENSE" file

import QtQuick
import QtQuick3D
import Clayground.World

/*!
    \qmltype MultiLine3D
    \inqmlmodule Clayground.Canvas3D
    \brief Efficiently renders multiple 3D line paths in a single draw call.

    MultiLine3D uses custom shaders to render multiple line paths with
    consistent screen-space width. This is more efficient than creating
    multiple Line3D instances when you need to draw many lines.

    Example usage:
    \qml
    import Clayground.Canvas3D

    MultiLine3D {
        coords: [
            [Qt.vector3d(0, 0, 0), Qt.vector3d(100, 0, 0)],
            [Qt.vector3d(0, 50, 0), Qt.vector3d(100, 50, 0)],
            [Qt.vector3d(0, 100, 0), Qt.vector3d(100, 100, 0)]
        ]
        color: "red"
        width: 2.0
    }
    \endqml

    \sa Line3D, CustomLineGeometry
*/
Model {
    id: root

    /*!
        \qmlproperty list<list<vector3d>> MultiLine3D::coords
        \brief Array of line paths, each path being an array of 3D points.
    */
    property var coords

    /*!
        \qmlproperty color MultiLine3D::color
        \brief The color of all lines.

        This is a convenience alias for \c{material.lineColor}.
    */
    property alias color: _lineMat.lineColor

    /*!
        \qmlproperty real MultiLine3D::width
        \brief The width of all lines in screen pixels.

        This is a convenience alias for \c{material.lineWidth}.
    */
    property alias width: _lineMat.lineWidth

    /*!
        \qmlproperty CustomMaterial MultiLine3D::material
        \brief The material used for rendering the lines.

        The material provides \c{lineColor} and \c{lineWidth} properties
        which are also exposed via the \l color and \l width aliases for convenience.
    */
    property CustomMaterial material: _lineMat

    geometry: CustomLineGeometry {
        id: lineGeometry
        lines: coords
    }

    materials: [
        CustomMaterial {
            id: _lineMat

            shadingMode: CustomMaterial.Unshaded
            property real lineWidth: 1
            property color lineColor: "red"
            vertexShader: "custom_line.vert"
            fragmentShader: "custom_line.frag"
        }
    ]
}
