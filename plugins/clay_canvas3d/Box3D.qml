import QtQuick
import QtQuick3D
import QtQuick.Window // For Screen

import Clayground.Canvas3D

/*!
    \qmltype Box3D
    \inqmlmodule Clayground.Canvas3D
    \brief A 3D box with customizable dimensions, edge rendering, and toon shading.

    Box3D provides a convenient way to create 3D boxes with cartoon-style
    edge rendering and optional toon shading. The box origin is at the
    bottom center, making it easy to place objects on ground planes.

    Example usage:
    \qml
    import QtQuick3D
    import Clayground.Canvas3D

    Box3D {
        width: 100
        height: 150
        depth: 100
        color: "red"
        useToonShading: true
        showEdges: true
        edgeColorFactor: 0.4
    }
    \endqml

    \sa Box3DGeometry
*/
Model {
    /*!
        \qmlproperty color Box3D::color
        \brief The base color of the box.

        Defaults to red.
    */
    property alias color: _material.baseColor

    /*!
        \qmlproperty real Box3D::width
        \brief Width of the box along the X axis.

        Defaults to 1.0.
    */
    property real width: 1.0

    /*!
        \qmlproperty real Box3D::height
        \brief Height of the box along the Y axis.

        Defaults to width (creating a cube by default).
    */
    property real height: width

    /*!
        \qmlproperty real Box3D::depth
        \brief Depth of the box along the Z axis.

        Defaults to width (creating a cube by default).
    */
    property real depth:  width

    /*!
        \qmlproperty enumeration Box3D::scaledFace
        \brief Which face of the box should be scaled.

        Use with faceScale to create pyramids, trapezoids, etc.
        \sa Box3DGeometry::scaledFace
    */
    property alias scaledFace: _geometry.scaledFace

    /*!
        \qmlproperty vector2d Box3D::faceScale
        \brief Scale factor for the selected face.

        \sa Box3DGeometry::faceScale
    */
    property alias faceScale: _geometry.faceScale

    /*!
        \qmlproperty bool Box3D::showEdges
        \brief Whether to render dark edge lines.

        Defaults to true.
    */
    property alias showEdges: _geometry.showEdges

    /*!
        \qmlproperty real Box3D::edgeThickness
        \brief Thickness of edge lines.
    */
    property alias edgeThickness: _geometry.edgeThickness

    /*!
        \qmlproperty real Box3D::edgeColorFactor
        \brief Darkening factor for edges (0-1).

        Lower values create darker edges.
    */
    property alias edgeColorFactor: _geometry.edgeColorFactor

    /*!
        \qmlproperty int Box3D::edgeMask
        \brief Bitmask controlling which edges are visible.

        Use allEdges, topEdges, bottomEdges, etc.
    */
    property alias edgeMask: _geometry.edgeMask

    property bool cullMode: false
    property alias lighting: _material.lighting

    /*!
        \qmlproperty bool Box3D::useToonShading
        \brief Enables cartoon-style rendering.

        When enabled, uses half-lambert lighting for softer shadows,
        disables specular highlights and IBL. Works best with strong
        directional light shadows.
    */
    property alias useToonShading: _material.useToonShading

    /*!
        \qmlproperty int Box3D::allEdges
        \readonly
        \brief Convenience constant for showing all edges.
    */
    readonly property int allEdges: Box3DGeometry.AllEdges
    readonly property int topEdges: Box3DGeometry.TopEdges
    readonly property int bottomEdges: Box3DGeometry.BottomEdges
    readonly property int frontEdges: Box3DGeometry.FrontEdges
    readonly property int backEdges: Box3DGeometry.BackEdges
    readonly property int leftEdges: Box3DGeometry.LeftEdges
    readonly property int rightEdges: Box3DGeometry.RightEdges

    geometry: Box3DGeometry {
        id: _geometry
        size: Qt.vector3d(width, height, depth)
        edgeColorFactor: 0.4
        edgeMask: Box3DGeometry.AllEdges
    }

    materials: [
        CustomMaterial {
            id: _material
            property color baseColor: "red"

            vertexShader: "box3d.vert"
            fragmentShader: "box3d.frag"
            shadingMode: CustomMaterial.Shaded

            // Add basic lighting
            property real lighting: 1.0
            
            // Toon shading control
            // When true, applies cartoon-style lighting in the fragment shader
            property bool useToonShading: false

            // Edge settings (connected to Box3D properties)
            property bool showEdges: _geometry.showEdges
            property real edgeThickness: _geometry.edgeThickness
            property real edgeColorFactor: _geometry.edgeColorFactor
            property int edgeMask: _geometry.edgeMask

            // Add viewport height for consistent edge thickness
            property real viewportHeight: Screen.desktopAvailableHeight
        }
    ]
}
