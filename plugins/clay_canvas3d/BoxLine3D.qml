import QtQuick
import QtQuick3D
import Clayground.World

Node {
    id: _boxLine

    property var positions: []
    property real width: 1
    property color color: "blue"
    property Material material: DefaultMaterial {
        diffuseColor: _boxLine.color
    }

    property real _particleSize: 100

    Model {
        source: "#Cube"
        instancing: LineInstancing {
            positions: _boxLine.positions
            width: _boxLine.width
            color: _boxLine.color
        }
        materials: _boxLine.material
        scale: Qt.vector3d(1/_particleSize, 1/_particleSize, 1/_particleSize)
    }
}
