import QtQuick
import QtQuick3D

import Clayground.Canvas3D

/*!
    \qmltype Poly3D
    \inqmlmodule Clayground.Canvas3D
    \brief A filled planar polygon, with holes, in any of the three world planes.

    Poly3D is the area primitive of Clayground.Canvas3D: hand it a ring of 2D
    points and it draws the filled region they enclose - a lake, a plaza, a
    footprint, a zone on the ground. Inner rings cut holes out of it.

    The ring closes implicitly and its winding does not matter; both are sorted
    out while the mesh is built. Points that do not enclose an area (fewer than
    three of them, all on one line, or zero size) draw nothing and say so once
    under the \c clay.poly logging category.

    Poly3D is the rich/few end of the family, in the same sense as Label3D
    against LabelBatch3D: one Model and one draw call per polygon, meant for
    tens of areas rather than thousands.

    A polygon lying at exactly the same height as another surface z-fights with
    it. Lift it a hair along its normal - \c {y: 0.5} for a polygon on the
    ground - which is the only reliable fix. Model's own \c depthBias is not
    one: in Qt Quick 3D it biases the distance used to \e sort objects, so it
    settles which of two exactly tied surfaces is drawn first and does nothing
    about the per-pixel fight that follows.

    The polygon is planar, but where that plane sits is free: Poly3D is a Node,
    so \c eulerRotation and \c position place it wherever it belongs. The
    \l plane property only names the three axis-aligned cases so they read as
    intent rather than as a rotation the reader has to decode.

    Example usage:
    \qml
    import QtQuick
    import QtQuick3D
    import Clayground.Canvas3D

    View3D {
        anchors.fill: parent

        PerspectiveCamera { position: Qt.vector3d(0, 320, 320); eulerRotation.x: -40 }
        DirectionalLight { eulerRotation.x: -35 }

        Poly3D {
            // An L shape on the ground, with a square hole in it.
            vertices: [Qt.vector2d(-120, -120), Qt.vector2d(60, -120),
                       Qt.vector2d(60, -20), Qt.vector2d(-20, -20),
                       Qt.vector2d(-20, 120), Qt.vector2d(-120, 120)]
            holes: [[Qt.vector2d(-100, -100), Qt.vector2d(-50, -100),
                     Qt.vector2d(-50, -50), Qt.vector2d(-100, -50)]]
            color: "#0f9d9a"
            y: 0.5   // clear of whatever else lies on the ground plane
        }
    }
    \endqml

    \sa Poly3DGeometry, Box3D
*/
Model {
    id: root

    // Mirrors Poly3DGeometry::Plane so the documented "plane: Poly3D.XZ"
    // spelling resolves without naming the geometry.
    enum Plane { XZ, XY, YZ }

    /*!
        \qmlproperty list<vector2d> Poly3D::vertices
        \brief The outer ring of the polygon, in plane coordinates.

        \c Qt.vector2d(u, v) is the canonical spelling; a plain \c {{x, y}}
        object, \c Qt.point() and a two-element \c [u, v] array are accepted
        too, because a point that has been through JSON or a spread arrives as
        one of those.

        The ring closes implicitly - a repeated last point is dropped - and is
        wound the right way round automatically.

        Defaults to an empty list, which draws nothing.
    */
    property alias vertices: _geometry.vertices

    /*!
        \qmlproperty list<list<vector2d>> Poly3D::holes
        \brief Inner rings cut out of the polygon.

        Each entry is a ring in the same format as \l vertices. A hole that
        encloses no area is ignored with a warning; holes that stray outside
        the outer ring or overlap each other are not repaired.

        Defaults to an empty list.
    */
    property alias holes: _geometry.holes

    /*!
        \qmlproperty color Poly3D::color
        \brief The fill color of the polygon.

        Defaults to the Clayground teal, \c #0f9d9a.
    */
    property alias color: _material.baseColor

    /*!
        \qmlproperty bool Poly3D::useToonShading
        \brief Enables cartoon-style rendering.

        The same knob Box3D has, running the same half-lambert lighting, so a
        Poly3D ground and the Box3D objects on it match. Defaults to false.
    */
    property alias useToonShading: _material.useToonShading

    /*!
        \qmlproperty enumeration Poly3D::cullMode
        \brief Which side of the polygon is drawn.

        A polygon is a single-sided surface: with the default
        \c Material.BackFaceCulling it disappears when seen from behind, which
        is what a ground plane wants. Set \c Material.NoCulling for one meant
        to be read from both sides - the lighting then still uses the front
        normal.
    */
    property alias cullMode: _material.cullMode

    /*!
        \qmlproperty enumeration Poly3D::plane
        \brief Which world plane the 2D points map to.

        \value Poly3D.XZ (u, v) becomes (u, 0, v) with normal +Y - the ground
               case, and the default.
        \value Poly3D.XY (u, v) becomes (u, v, 0) with normal +Z - a wall
               facing the default camera.
        \value Poly3D.YZ (u, v) becomes (0, u, v) with normal +X - a wall
               facing right.

        Anything not axis-aligned is the node's own \c eulerRotation.

        \sa Poly3DGeometry::plane
    */
    property int plane: Poly3D.XZ

    geometry: Poly3DGeometry {
        id: _geometry
        plane: root.plane
    }

    materials: [
        CustomMaterial {
            id: _material
            property color baseColor: "#0f9d9a"
            property bool useToonShading: false

            vertexShader: "poly3d.vert"
            fragmentShader: "poly3d.frag"
            shadingMode: CustomMaterial.Shaded
        }
    ]
}
