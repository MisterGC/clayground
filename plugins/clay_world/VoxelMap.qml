// (c) Clayground Contributors - MIT License, see "LICENSE" file

import QtQuick
import QtQuick3D

Model {

    id: _voxelMap

    // Dimensions of the voxel map
    property int width: 100
    property int height: 100
    property int depth: 100

    // Size of each voxel
    property real voxelSize: 1.0
    property real spacing: 1.0

    // By default none of the voxels are visible
    // and also not created in the voxel map (performance!)
    property color defaultColor: "transparent"

    // The model of the voxel map
    property var model

    function get(x, y, z) {
        return model.voxel(x,y,z);
    }

    function set(x, y, z, color) {
        model.setVoxel(x,y,z,color);
    }

    function fill(shapes) {
        // Handle single shape case
        if (!Array.isArray(shapes)) {
            shapes = [shapes];
        }

        shapes.forEach(shape => {
            // Support both object notation and array notation
            let type, params;
            if (Array.isArray(shape)) {
                [type, params] = shape;
            } else {
                [[type, params]] = Object.entries(shape);
            }

            // Common defaults
            const commonDefaults = {
                pos: Qt.vector3d(0, 0, 0),
                colors: [{ color: defaultColor, weight: 1.0 }],
                noise: 0.0,
                rotation: Qt.vector3d(0, 0, 0)
            }

            switch(type.toLowerCase()) {
                case "sphere":
                    const sphereDefaults = { radius: 1 }
                    const s = Object.assign({}, commonDefaults, sphereDefaults, params)
                    model.fillSphere(
                        s.pos.x, s.pos.y, s.pos.z,
                        s.radius,
                        s.colors,
                        s.noise
                    )
                    break

                case "cylinder":
                    const cylinderDefaults = { radius: 1, height: 1 }
                    const c = Object.assign({}, commonDefaults, cylinderDefaults, params)
                    model.fillCylinder(
                        c.pos.x, c.pos.y, c.pos.z,
                        c.radius,
                        c.height,
                        c.colors,
                        c.noise
                    )
                    break


                case "box":
                    const boxDefaults = { width: 1, height: 1, depth: 1 }
                    const b = Object.assign({}, commonDefaults, boxDefaults, params)
                    model.fillBox(
                        b.pos.x, b.pos.y, b.pos.z,
                        b.width,
                        b.height,
                        b.depth,
                        b.colors,
                        b.noise
                    )
                    break
            }
        })
    }

    materials: [
        CustomMaterial {
            vertexShader: "voxel_map.vert"
            fragmentShader: "voxel_map.frag"
            shadingMode: CustomMaterial.Shaded

            // Add these properties for proper shadow handling
            property bool receivesDepth: true
            property bool receivesShadows: true
        }
    ]
}
