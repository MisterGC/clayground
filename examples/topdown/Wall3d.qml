// (c) Clayground Contributors - MIT License, see "LICENSE" file

import QtQuick3D
import QtQuick3D.Physics
import Clayground.Canvas3D

StaticRigidBody {
    id: _wall

    // Dimensions for the wall
    property alias width: _box.width
    property alias height: _box.height
    property alias depth: _box.depth
    property alias color: _box.color

    // Default dimensions
    width: 100
    height: 100
    depth: 100

    collisionShapes: BoxShape { 
        id: boxShape
        extents: Qt.vector3d(_wall.width, _wall.height, _wall.depth)
    }
    
    readonly property Model model: _box

    Box3D
    {
        id: _box
        color: "gray"
        useToonShading: true
    }

}
