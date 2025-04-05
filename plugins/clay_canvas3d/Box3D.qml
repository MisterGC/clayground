import QtQuick
import QtQuick3D

Model {
    property alias color: _material.baseColor

    // Dimensions, cube by default
    property real width: 1.0
    property real height: width
    property real depth:  width

    // Modifyable dimension of the top rectangle
    property alias scaledFace: _geometry.scaledFace
    property alias faceScale: _geometry.faceScale

    geometry: Box3DGeometry {
        id: _geometry
        size: Qt.vector3d(width, height, depth)
    }
    materials: PrincipledMaterial {id: _material; baseColor: "red" }
}
