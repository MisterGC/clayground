import QtQuick
import QtQuick3D
import Clayground.World

Model {
    id: root
    property var lineData

    geometry: CustomLineGeometry {
        id: lineGeometry
        vertices: lineData.vertices
        //color: lineData.color
        //width: lineData.width
    }

    materials: [
        CustomMaterial {
            property real lineWidth: lineData.width
            property color lineColor: Qt.rgba(lineData.color.r, lineData.color.g, lineData.color.b, .8)  //lineData.color
            //NumberAnimation on lineWidth { from: 1.0; to: 3.0; duration: 1000; loops: -1 }

            shadingMode: CustomMaterial.Unshaded
            sourceBlend: CustomMaterial.SrcAlpha
            destinationBlend: CustomMaterial.SrcAlpha

            vertexShader: "custom_line.vert"
            fragmentShader: "custom_line.frag"
        }
    ]
}
