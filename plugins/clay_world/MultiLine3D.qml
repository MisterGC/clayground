import QtQuick
import QtQuick3D
import Clayground.World

Model {
    id: root

    /** Array of arrays with line coordinates. */
    property var coords
    property alias color: _lineMat.lineColor
    property alias width: _lineMat.lineWidth
    property CustomMaterial material: _lineMat

    geometry: CustomLineGeometry {
        id: lineGeometry
        lines: coords
    }

    materials: [
        CustomMaterial {
            id: _lineMat

            shadingMode: CustomMaterial.Unshaded
            property real lineWidth: 1
            property color lineColor: "black"
            vertexShader: "custom_line.vert"
            fragmentShader: "custom_line.frag"
        }
    ]
}
