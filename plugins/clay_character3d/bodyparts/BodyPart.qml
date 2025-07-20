import QtQuick
import Clayground.Canvas3D

Box3D
{
    property vector3d basePos: Qt.vector3d(0,0,0)
    property vector3d baseEuler: Qt.vector3d(0,0,0)

    position: basePos
    eulerRotation: baseEuler
    showEdges: true
    edgeThickness: 7
    edgeColorFactor: 0.4
    castsShadows: true
}