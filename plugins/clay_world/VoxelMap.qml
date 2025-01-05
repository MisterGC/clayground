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

    function fillSphere(cx, cy, cz, r, colorOrDistribution) {
        if (Array.isArray(colorOrDistribution)) {
            // It's already a distribution array
            _voxelMap.fillSphere(cx, cy, cz, r, colorOrDistribution);
        } else {
            // It's a single color, convert to simple distribution array
            _voxelMap.fillSphere(cx, cy, cz, r, [
                { color: colorOrDistribution.toString(), weight: 1.0 }
            ]);
        }
    }

    function fillCylinder(cx, cy, cz, r, height, colorOrDistribution) {
        if (Array.isArray(colorOrDistribution)) {
            // It's already a distribution array
            _voxelMap.fillCylinder(cx, cy, cz, r, height, colorOrDistribution);
        } else {
            // It's a single color, convert to simple distribution array
            _voxelMap.fillCylinder(cx, cy, cz, r, height, [
                { color: colorOrDistribution.toString(), weight: 1.0 }
            ]);
        }
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
