import QtQuick
import QtQuick3D

VoxelMap {
    id: _voxelMap
    model: _voxelInstancing

    // Dimensions of the voxel map
    property alias width: _voxelInstancing.width
    property alias height: _voxelInstancing.height
    property alias depth: _voxelInstancing.depth

    instancing: VoxelMapInstancing {
        id: _voxelInstancing
        width: _voxelMap.width
        height: _voxelMap.height
        depth: _voxelMap.depth
        voxelSize: _voxelMap.voxelSize
        spacing: _voxelMap.spacing
    }

    // Use a built-in cube model as the source.
    source: "#Cube"
    scale: Qt.vector3d(1/100, 1/100, 1/100)
}
