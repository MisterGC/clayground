// (c) Clayground Contributors - MIT License, see "LICENSE" file

import QtQuick
import QtQuick3D

VoxelMap {
    id: _voxelMap
    model: _voxelMesh

    geometry: VoxelMapGeometry {
        id: _voxelMesh
        width: _voxelMap.width
        height: _voxelMap.height
        depth: _voxelMap.depth
        voxelSize: _voxelMap.voxelSize
        spacing: _voxelMap.spacing
    }
}
