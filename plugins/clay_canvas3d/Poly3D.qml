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

    It can also show its own edges - either the outline it was given or the
    triangulation underneath it, see \l showEdges and \l edgeMode. Edges are off
    by default and cost nothing until asked for.

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

    // Mirrors Poly3DGeometry::EdgeMode, same reason.
    enum EdgeMode { FaceBorders, Triangles }

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

    /*!
        \qmlproperty bool Poly3D::showEdges
        \brief Whether the polygon draws its own edges.

        Defaults to false, unlike Box3D, where it defaults to true: a box's
        borders are its look, while a polygon's edges are a deliberate choice -
        an area on the ground usually wants to be an area, not a diagram of one.

        The mesh a polygon needs in order to draw edges is wider than the one it
        needs to be filled, so setting this true for the first time rebuilds it.
        That wider mesh is then kept, which is what makes
        \c {showEdges: hoverHandler.hovered} a reasonable thing to write: one
        rebuild for the object's lifetime, and a uniform write per toggle after
        that.

        \sa edgeMode
    */
    property alias showEdges: _geometry.showEdges

    /*!
        \qmlproperty enumeration Poly3D::edgeMode
        \brief Which lines \l showEdges draws.

        \value Poly3D.FaceBorders The polygon outline only - the rings that were
               handed over, including the rims of any holes. Interior lines the
               triangulation invented stay hidden. The default, and the same
               thing Box3D and VoxelMap edges have always meant.
        \value Poly3D.Triangles Every edge of the triangulation, the mesh's own
               structure. What a lab explaining how a shape is built wants.

        Switching between the two costs nothing - both read the same channel.

        \qml
        Poly3D {
            vertices: ring
            showEdges: true
            edgeMode: Poly3D.Triangles
            edgeColor: "#2f3437"
        }
        \endqml
    */
    property alias edgeMode: _geometry.edgeMode

    /*!
        \qmlproperty real Poly3D::edgeThickness
        \brief Thickness of the edge lines, in pixels.

        Screen-space, so a line keeps its weight as the camera moves or the
        polygon tilts away. The same unit Box3D::edgeThickness and
        VoxelMap::edgeThickness use. Defaults to 1.0.

        An edge shared by two triangles is drawn from both sides and so comes
        out about twice as wide as one on the polygon's rim.
    */
    property alias edgeThickness: _geometry.edgeThickness

    /*!
        \qmlproperty real Poly3D::edgeColorFactor
        \brief Darkening factor for edges (0-1).

        Lower values give darker edges. Ignored once \l edgeColor is set.
        Defaults to 0.4.
    */
    property alias edgeColorFactor: _geometry.edgeColorFactor

    /*!
        \qmlproperty color Poly3D::edgeColor
        \brief The edge color, as an absolute color rather than a factor.

        Wins over \l edgeColorFactor as soon as it has a visible alpha, which is
        what counts as set here - a fully transparent edge has no meaning, so it
        serves as the unset sentinel and leaves opaque black reachable.

        On a light fill this is the difference between edges that read and edges
        that barely exist: \c edgeColorFactor can only ever darken the fill
        towards black by a fraction of itself.
    */
    property alias edgeColor: _geometry.edgeColor

    geometry: Poly3DGeometry {
        id: _geometry
        plane: root.plane
    }

    materials: [
        CustomMaterial {
            id: _material
            property color baseColor: "#0f9d9a"
            property bool useToonShading: false

            // Edge settings, read off the geometry: it owns them because it is
            // what has to change shape when edges are switched on.
            property bool showEdges: _geometry.showEdges
            property int edgeMode: _geometry.edgeMode
            property real edgeThickness: _geometry.edgeThickness
            property real edgeColorFactor: _geometry.edgeColorFactor
            property color edgeColor: _geometry.edgeColor

            vertexShader: "poly3d.vert"
            fragmentShader: "poly3d.frag"
            shadingMode: CustomMaterial.Shaded
        }
    ]
}
