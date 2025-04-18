import QtQuick
import QtQuick3D

import Clayground.Canvas3D

Model {
    property alias color: _material.baseColor

    // Dimensions, cube by default
    property real width: 1.0
    property real height: width
    property real depth:  width

    // Modifyable dimension of the top rectangle
    property alias scaledFace: _geometry.scaledFace
    property alias faceScale: _geometry.faceScale

    // Edge rendering properties
    property alias showEdges: _geometry.showEdges
    property alias edgeThickness: _geometry.edgeThickness
    property alias edgeFalloff: _geometry.edgeFalloff
    property alias edgeDarkness: _geometry.edgeDarkness
    property alias cornerDarkness: _geometry.cornerDarkness
    property alias viewDistanceFactor: _geometry.viewDistanceFactor

    // Material properties
    property bool cullMode: false
    property alias lighting: _material.lighting

    geometry: Box3DGeometry {
        id: _geometry
        size: Qt.vector3d(width, height, depth)
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

            // Edge settings (connected to Box3D properties)
            property bool showEdges: _geometry.showEdges
            property real edgeThickness: _geometry.edgeThickness
            property real edgeFalloff: _geometry.edgeFalloff
            property real edgeDarkness: _geometry.edgeDarkness
            property real cornerDarkness: _geometry.cornerDarkness
            property real viewDistanceFactor: _geometry.viewDistanceFactor
        }
    ]
}
