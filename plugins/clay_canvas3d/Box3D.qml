import QtQuick
import QtQuick3D
import QtQuick.Window // For Screen

import Clayground.Canvas3D

Model {
    property alias color: _material.baseColor

    // Dimensions, cube by default
    property real width: 1.0
    property real height: width
    property real depth:  width
    
    // Origin point: The box's origin (0,0,0) is at the bottom center.
    // - X axis: centered (extends from -width/2 to +width/2)
    // - Y axis: bottom-aligned (extends from 0 to height)
    // - Z axis: centered (extends from -depth/2 to +depth/2)
    // This means when y=0, the bottom face of the box sits on the ground plane.

    // Modifyable dimension of the top rectangle
    property alias scaledFace: _geometry.scaledFace
    property alias faceScale: _geometry.faceScale

    // Edge rendering properties (matching VoxelMap)
    property alias showEdges: _geometry.showEdges
    property alias edgeThickness: _geometry.edgeThickness
    property alias edgeColorFactor: _geometry.edgeColorFactor
    property alias edgeMask: _geometry.edgeMask

    // Material properties
    property bool cullMode: false
    property alias lighting: _material.lighting
    
    // Toon shading property - enables cartoon-style rendering
    // When enabled:
    // - Uses half-lambert lighting for softer shadows
    // - Disables specular highlights and IBL
    // - Works best with strong directional light shadows
    property alias useToonShading: _material.useToonShading

    // Edge mask enums exposed for easier QML usage
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
