// (c) Clayground Contributors - MIT License, see "LICENSE" file

import QtQuick
import QtQuick3D
import Clayground.Canvas3D

/*!
    \qmltype MultiLine3D
    \inqmlmodule Clayground.Canvas3D
    \brief Renders multiple 3D line paths in a single draw call.

    MultiLine3D draws many line paths with one uniform color and width. It is a
    thin wrapper over the instanced \l LineBatch3D backend: every path becomes a
    styled line in a shared batch, so the whole set is drawn as a single
    instanced draw call with camera-facing, constant-world-width ribbons.

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

    \sa Line3D, LineBatch3D
*/
Node {
    id: root

    /*!
        \qmlproperty list<list<vector3d>> MultiLine3D::coords
        \brief Array of line paths, each path being an array of 3D points.
    */
    property var coords

    /*!
        \qmlproperty color MultiLine3D::color
        \brief The color of all lines. Defaults to red.
    */
    property color color: "red"

    /*!
        \qmlproperty real MultiLine3D::width
        \brief The width of all lines in world units. Defaults to 1.
    */
    property real width: 1

    /*!
        \qmlproperty int MultiLine3D::orientation
        \brief \c LineBatch3D.Billboard (default) or \c LineBatch3D.Flat.

        Billboard ribbons always face the camera, which is right for a line in
        the air and wrong for a marking on the ground: on a curve, consecutive
        camera-facing quads splay apart and leave wedge-shaped gaps at the
        joins. Anything that represents a surface - a road, a lane, a trace on
        a board - wants \c Flat.
    */
    property int orientation: LineBatch3D.Billboard

    /*!
        \qmlproperty bool MultiLine3D::castsShadows
        \brief Whether the lines drop a shadow. Off by default.

        Forwarded to the underlying \l LineBatch3D, so the same rules apply:
        only a \c Flat set qualifies (MultiLine3D is always world-width), and a
        Billboard set that opts in warns once and stays shadowless. Turn it on
        for lines that are things in the world - a path floating above the
        road, a route ribbon - where the contact shadow is what conveys the
        height.
    */
    property bool castsShadows: false

    /*!
        \qmlproperty bool MultiLine3D::shapedShadows
        \brief Forwarded to \l {LineBatch3D::shapedShadows}: carved (default)
        versus cheap rectangular shadows while \l castsShadows is active.
    */
    property bool shapedShadows: true

    LineBatch3D {
        id: _batch
        widthUnits: LineBatch3D.World
        orientation: root.orientation
        castsShadows: root.castsShadows
        shapedShadows: root.shapedShadows
        lines: {
            if (!root.coords)
                return []
            var out = []
            for (var i = 0; i < root.coords.length; ++i)
                out.push({ points: root.coords[i], color: root.color,
                           width: root.width, styleId: 0 })
            return out
        }
    }
}
