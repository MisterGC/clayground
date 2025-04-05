// (c) Clayground Contributors - MIT License, see "LICENSE" file

import QtQuick
import QtQuick3D

VoxelMap {
    id: _voxelMap
    model: _voxelMesh

    // Dimensions of the voxel map
    property alias width: _voxelMesh.width
    property alias height: _voxelMesh.height
    property alias depth: _voxelMesh.depth

    // For StaticVoxelMaps the entire map is generated as one static mesh
    // which has its origin in the bottom center - depending if the number
    // of voxels along a dim is even or odd we may have to apply an offset
    voxelOffset: Qt.vector3d(
                     (_voxelMap.width % 2 == 0) ? 0 : (_voxelMap.voxelSize * 0.5),
                     0,
                     (_voxelMap.depth % 2 == 0) ? 0 : (_voxelMap.voxelSize * 0.5)
                     )

    function load(path) {_voxelMesh.loadFromFile(path);}
    function save(path) {_voxelMesh.saveToFile(path);}

    geometry: VoxelMapGeometry {
        id: _voxelMesh
        width: _voxelMap.width
        height: _voxelMap.height
        depth: _voxelMap.depth
        voxelSize: _voxelMap.voxelSize
        spacing: _voxelMap.spacing
    }
}
