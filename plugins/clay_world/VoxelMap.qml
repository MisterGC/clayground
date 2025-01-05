// (c) Clayground Contributors - MIT License, see "LICENSE" file

import QtQuick
import QtQuick3D

Model {
    property alias width: _voxelMap.width
    property alias height: _voxelMap.height
    property alias depth: _voxelMap.depth
    property alias voxelSize: _voxelMap.voxelSize
    property alias defaultColor: _voxelMap.defaultColor

    function get(x, y, z) {
        return _voxelMap.voxel(x,y,z);
    }

    function set(x, y, z, color) {
        _voxelMap.setVoxel(x,y,z,color);
    }

    function fillSphere(cx, cy, cz, r, color)
    {
        _voxelMap.fillSphere(cx, cy, cz, r, color);
    }

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
