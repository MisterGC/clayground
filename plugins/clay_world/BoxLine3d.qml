import QtQuick
import QtQuick3D
import Clayground.World

Node {
    id: root

    // Exposed properties
    property var positions: []
    property real width: 1
    property color color: "blue"
    property Material material: DefaultMaterial {
        diffuseColor: root.color
    }

    // Private properties
    property real _particleSize: 100 // Size of the cube model

    Model {
        source: "#Cube"
        instancing: LineInstancing {
            positions: root.positions
            width: root.width
            color: root.color
        }
        materials: root.material
        scale: Qt.vector3d(1/_particleSize, 1/_particleSize, 1/_particleSize)
    }
}
