// (c) Clayground Contributors - MIT License, see "LICENSE" file

import QtQuick
import QtQuick3D

/*!
    \qmltype Line3D
    \inqmlmodule Clayground.Canvas3D
    \brief A simple 3D line connecting multiple points.

    Line3D provides an easy way to draw a single connected line through
    a series of 3D points. It wraps MultiLine3D for convenience when
    only a single line path is needed.

    Example usage:
    \qml
    import Clayground.Canvas3D

    Line3D {
        coords: [
            Qt.vector3d(0, 0, 0),
            Qt.vector3d(100, 50, 0),
            Qt.vector3d(200, 0, 0)
        ]
        color: "blue"
        width: 2.0
    }
    \endqml

    \sa MultiLine3D, BoxLine3D
*/
Model {
    id: _line

    /*!
        \qmlproperty list<vector3d> Line3D::coords
        \brief List of 3D points defining the line path.
    */
    property var coords: []

    /*!
        \qmlproperty color Line3D::color
        \brief The color of the line.

        Defaults to black.
    */
    property color color: "black"

    /*!
        \qmlproperty real Line3D::width
        \brief The width of the line in world units.

        Defaults to 1.
    */
    property real width: 1

    MultiLine3D {
        coords: [_line.coords]
        color: _line.color
        width: _line.width
    }
}
