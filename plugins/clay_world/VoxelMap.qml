// (c) Clayground Contributors - MIT License, see "LICENSE" file

import QtQuick
import QtQuick3D

Model {
    property alias width: _voxelMap.width
    property alias height: _voxelMap.height
    property alias depth: _voxelMap.depth
    property alias voxelSize: _voxelMap.voxelSize
    property alias defaultColor: _voxelMap.defaultColor

    geometry: VoxelMapGeometry {
        id: _voxelMap
    }

    materials: [
        CustomMaterial {
            vertexShader: "voxel_map.vert"
            fragmentShader: "voxel_map.frag"
            shadingMode: CustomMaterial.Shaded
        }
    ]
}
