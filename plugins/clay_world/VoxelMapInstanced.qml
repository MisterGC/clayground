import QtQuick
import QtQuick3D

Model {
    id: voxelMapModel

    // Expose properties for grid dimensions, voxel size, spacing, and default color.
    property alias width: voxelInstancing.width
    property alias height: voxelInstancing.height
    property alias depth: voxelInstancing.depth
    property alias voxelSize: voxelInstancing.voxelSize
    property alias spacing: voxelInstancing.spacing
    property alias defaultColor: voxelInstancing.defaultColor

    // Helper functions to get/set individual voxels.
    function get(x, y, z) {
        return voxelInstancing.voxel(x, y, z);
    }
    function set(x, y, z, color) {
        voxelInstancing.setVoxel(x, y, z, color);
    }

    // Fill functions support an array of shape descriptors.
    function fill(shapes) {
        if (!Array.isArray(shapes))
            shapes = [shapes];
        shapes.forEach(function(shape) {
            let type, params;
            if (Array.isArray(shape)) {
                [type, params] = shape;
            } else {
                for (let key in shape) {
                    type = key;
                    params = shape[key];
                    break;
                }
            }
            const commonDefaults = {
                pos: Qt.vector3d(0,0,0),
                colors: [{ color: defaultColor, weight: 1.0 }],
                noise: 0.0
            };
            switch(type.toLowerCase()) {
                case "sphere": {
                    const sphereDefaults = { radius: 1 };
                    let s = Object.assign({}, commonDefaults, sphereDefaults, params);
                    voxelInstancing.fillSphere(s.pos.x, s.pos.y, s.pos.z, s.radius, s.colors, s.noise);
                    break;
                }
                case "cylinder": {
                    const cylinderDefaults = { radius: 1, height: 1 };
                    let c = Object.assign({}, commonDefaults, cylinderDefaults, params);
                    voxelInstancing.fillCylinder(c.pos.x, c.pos.y, c.pos.z, c.radius, c.height, c.colors, c.noise);
                    break;
                }
                case "box": {
                    const boxDefaults = { width: 1, height: 1, depth: 1 };
                    let b = Object.assign({}, commonDefaults, boxDefaults, params);
                    voxelInstancing.fillBox(b.pos.x, b.pos.y, b.pos.z, b.width, b.height, b.depth, b.colors, b.noise);
                    break;
                }
            }
        });
    }

    // Use the custom instancing element.
    instancing: VoxelMapInstancing {
        id: voxelInstancing
        width: 16
        height: 16
        depth: 16
        voxelSize: 1
        spacing: 0.1
        defaultColor: "red"
    }

    // Use a built-in cube model as the source.
    source: "#Cube"
    scale: Qt.vector3d(1/100, 1/100, 1/100)

    materials: [
        DefaultMaterial {
            diffuseColor: voxelInstancing.defaultColor
        }
    ]
}
