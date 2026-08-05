import QtQuick
import QtQuick3D

import Clayground.Canvas3D

/*!
    \qmltype Poly3D
    \inqmlmodule Clayground.Canvas3D
    \brief A filled planar polygon, with holes, in any of the three world planes.

    Poly3D is the area primitive of Clayground.Canvas3D: hand it a ring of 2D
    points and it draws the filled region they enclose - a lake, a plaza, a
    footprint, a zone on the ground. Inner rings cut holes out of it, and
    \l extrude raises the whole thing into a prism when the area is meant to be
    a solid.

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
    it. \l surfaceOffset lifts it a hair along its normal, which is the only
    reliable fix. Model's own \c depthBias is not one: in Qt Quick 3D it biases
    the distance used to \e sort objects, so it settles which of two exactly
    tied surfaces is drawn first and does nothing about the per-pixel fight that
    follows. Measured on a lake coplanar with the ground at a grazing angle, out
    of some 3600 contested pixels 199 survived at \c {depthBias: 0}, 925 at 500
    and 962 at 100000 - against 3613 for a plain half-unit lift.

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
            surfaceOffset: 0.5   // clear of whatever else lies on the ground
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

        A flat polygon is a single-sided surface: with the default
        \c Material.BackFaceCulling it disappears when seen from behind, which
        is what a ground plane wants. Set \c Material.NoCulling for one meant
        to be read from both sides - the lighting then still uses the front
        normal.

        An extruded one is a closed solid with every face turned outwards, so
        the default is what it wants and \c Material.NoCulling only costs the
        fragments of the far side.
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
        \qmlproperty real Poly3D::extrude
        \brief How far the polygon rises along its plane normal.

        0, the default, is the flat area. Anything above it turns the same ring
        into a prism: the ring is the base, side walls rise along the plane
        normal and a cap closes the top. Holes are extruded too, so a ring with
        a courtyard becomes a building with a courtyard rather than a solid
        block.

        Direction and origin follow Box3D: the ring sits at the node's own
        origin plane and the solid grows from there - \c {+Y} for
        \c Poly3D.XZ, \c {+Z} for \c Poly3D.XY, \c {+X} for \c Poly3D.YZ.

        Side walls are faceted, not smoothed: each wall carries its own normal,
        so a hexagonal column reads as six flat faces rather than as a cylinder,
        which is what \l useToonShading wants.

        Changing \c extrude rebuilds the mesh. To animate the height, scale the
        node along the extrusion axis instead - the geometry is untouched, and
        because the edge lines are measured in screen space they keep their
        weight while it moves:

        \qml
        Poly3D {
            vertices: footprint
            extrude: 100
            showEdges: true
            NumberAnimation on scale.y {
                from: 0.2; to: 1.0; duration: 1200; loops: Animation.Infinite
            }
        }
        \endqml

        \sa plane
    */
    property alias extrude: _geometry.extrude

    /*!
        \qmlproperty real Poly3D::surfaceOffset
        \brief How far the polygon is lifted off its own plane.

        A lift, not a depth trick: it slides the geometry along the plane normal
        - \c {+Y} for \c Poly3D.XZ, \c {+Z} for \c Poly3D.XY, \c {+X} for
        \c Poly3D.YZ - by \c surfaceOffset units. Negative values push it the
        other way, under whatever it shares the plane with.

        This is the answer to z-fighting with a coplanar surface, and the only
        one that works; \c depthBias is not, for the reason given above.
        Something on the order of a thousandth of the scene's extent is enough -
        \c 0.5 in a world measured in hundreds of units.

        It leaves the node's own \c position alone, which is the point of doing
        it here rather than by moving the node: \c position stays free for
        placing the polygon, and for animating it without touching the mesh.

        0, the default, is not a translation of zero but no translation at all -
        the mesh comes out of the builder exactly as it did before the property
        existed.

        \l extrude is measured from the ring's own plane, not from the offset
        one, so lifting a prism moves it rather than making it taller or
        shorter. Changing \c surfaceOffset rebuilds the mesh, as \l extrude
        does; to animate a polygon's height off the ground, animate the node's
        \c position instead.

        \qml
        Poly3D {
            vertices: lakeRing
            color: "#00d9ff"
            surfaceOffset: 0.5   // above the ground it would otherwise fight
        }
        \endqml

        \sa plane, extrude
    */
    property alias surfaceOffset: _geometry.surfaceOffset

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

        \value Poly3D.FaceBorders The borders of the polygon's own faces - the
               rings that were handed over, including the rims of any holes,
               and on an extruded polygon the seams where cap and walls meet.
               Interior lines the triangulation invented stay hidden. The
               default, and the same thing Box3D and VoxelMap edges have always
               meant: an extruded Poly3D and a Box3D at the same
               \l edgeThickness draw the same weight of line.
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

        A line every surface on either side of it draws is laid down at half
        width from each, so it comes out at \c edgeThickness either way. A rim
        with nothing on the other side is drawn at full width for the same
        reason - which is why a flat polygon's outline, an extruded one's face
        borders and a Box3D border all read the same.
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
