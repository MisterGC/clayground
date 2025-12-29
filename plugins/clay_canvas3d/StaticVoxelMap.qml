// (c) Clayground Contributors - MIT License, see "LICENSE" file

import QtQuick
import QtQuick3D

VoxelMap {
    id: _voxelMap
    model: _voxelMesh

    // Dimensions of the voxel map (in voxel counts)
    // Aliased to the underlying geometry for direct access
    property alias voxelCountX: _voxelMesh.voxelCountX
    property alias voxelCountY: _voxelMesh.voxelCountY
    property alias voxelCountZ: _voxelMesh.voxelCountZ

    // For StaticVoxelMaps the entire map is generated as one static mesh
    // which has its origin in the bottom center - depending if the number
    // of voxels along a dim is even or odd we may have to apply an offset
    voxelOffset: Qt.vector3d(
                     (_voxelMap.voxelCountX % 2 == 0) ? 0 : (_voxelMap.voxelSize * 0.5),
                     0,
                     (_voxelMap.voxelCountZ % 2 == 0) ? 0 : (_voxelMap.voxelSize * 0.5)
                     )

    function load(path) {_voxelMesh.loadFromFile(path);}
    function save(path) {_voxelMesh.saveToFile(path);}

    geometry: VoxelMapGeometry {
        id: _voxelMesh
        voxelSize: _voxelMap.voxelSize
        spacing: _voxelMap.spacing
    }
}
