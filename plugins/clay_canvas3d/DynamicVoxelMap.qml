import QtQuick
import QtQuick3D

VoxelMap {
    id: _voxelMap
    model: _voxelInstancing

    // Dimensions of the voxel map
    property alias width: _voxelInstancing.width
    property alias height: _voxelInstancing.height
    property alias depth: _voxelInstancing.depth

    // Individual cubes + instancing are use, for each voxel, the offset
    // is half its dimension, cause Box3DGeometry has its origin in the bottom face
    voxelOffset: Qt.vector3d(_voxelMap.voxelSize * 0.5, 0, _voxelMap.voxelSize * 0.5)

    instancing: VoxelMapInstancing {
        id: _voxelInstancing
        width: _voxelMap.width
        height: _voxelMap.height
        depth: _voxelMap.depth
        voxelSize: _voxelMap.voxelSize
        spacing: _voxelMap.spacing
    }

    // Use a built-in cube model as the source.
    geometry: Box3DGeometry {
        id: _geometry
        size: Qt.vector3d(_voxelMap.voxelSize, _voxelMap.voxelSize, _voxelMap.voxelSize)
    }
}
