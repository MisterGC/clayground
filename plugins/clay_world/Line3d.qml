import QtQuick
import QtQuick3D
import Clayground.World

Model {
    id: root
    property var lineData

    geometry: Line3dGeometry {
        id: lineGeometry
        vertices: lineData.vertices
        color: lineData.color
        width: lineData.width
    }

    materials: [
        CustomMaterial {
            property real width: lineData.width
            shadingMode: CustomMaterial.Unshaded
            vertexShader: "custom_line.vert"
            fragmentShader: "custom_line.frag"
        }
    ]
}
