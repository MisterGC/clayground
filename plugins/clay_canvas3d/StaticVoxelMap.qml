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
