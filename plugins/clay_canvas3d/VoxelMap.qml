// (c) Clayground Contributors - MIT License, see "LICENSE" file

import QtQuick
import QtQuick3D

Model {

    id: _voxelMap


    // Size of each voxel
    property real voxelSize: 1.0
    property real spacing: 1.0

    // Edge properties
    property real edgeThickness: 0.05
    property real edgeColorFactor: 1.0
    property bool showEdges: true

    // The model of the voxel map
    property var model: undefined
    property bool autoCommit: true

    function get(x, y, z) {
        return model.voxel(x,y,z);
    }

    function set(x, y, z, color) {
        model.setVoxel(x,y,z,color);
    }

    function load(path) {
        model.loadFromFile(path);
    }

    function save(path) {
        model.saveToFile(path);
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
                colors: [{ color: "transparent", weight: 1.0 }],
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
        model.commit();
    }

    materials: [
        CustomMaterial {
            id: voxelMaterial
            vertexShader: "voxel_map.vert"
            fragmentShader: "voxel_map.frag"
            shadingMode: CustomMaterial.Shaded

            property real voxelSize: _voxelMap.voxelSize
            property real voxelSpacing: _voxelMap.spacing
            property vector3d voxelOffset: Qt.vector3d(
                                               (_voxelMap.width % 2 == 0) ? 0 : (_voxelMap.voxelSize * 0.5),
                                               0,
                                               (_voxelMap.depth % 2 == 0) ? 0 : (_voxelMap.voxelSize * 0.5)
                                               )

            // Edge properties
            property real edgeThickness: _voxelMap.edgeThickness
            property real edgeColorFactor: _voxelMap.edgeColorFactor
            property bool showEdges: _voxelMap.showEdges
        }
    ]
}
