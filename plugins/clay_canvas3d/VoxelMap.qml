// (c) Clayground Contributors - MIT License, see "LICENSE" file

import QtQuick
import QtQuick3D
import QtQuick.Window

Model {

    id: _voxelMap


    // Size of each voxel
    property real voxelSize: 1.0
    property real spacing: 1.0

    // Relative offset of the voxel edges in
    // relation to origin of the voxel map's local coord
    // system, this is important for things like edge drawing
    property vector3d voxelOffset: Qt.vector3d(0, 0, 0)

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

        // Utility function to process color data
        function processColorData(colorData) {
            if (typeof colorData === 'string') {
                return [{ color: colorData, weight: 1 }];
            } else if (Array.isArray(colorData) && !Array.isArray(colorData[0])) {
                // Single [color, weight] pair
                return [{ color: colorData[0], weight: colorData[1] || 1 }];
            } else if (Array.isArray(colorData)) {
                // Array of [color, weight] pairs
                return colorData.map(([color, weight=1]) => ({ color, weight }));
            }
            return colorData; // Return as is if it's already in the right format
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
                    if (Array.isArray(params)) {
                        // Compact: [x, y, z, radius, colorData, noise]
                        const [x, y, z, radius, colorData, noise=0] = params;
                        model.fillSphere(
                            x, y, z,
                            radius,
                            processColorData(colorData),
                            noise
                        );
                    } else {
                        const sphereDefaults = { radius: 1 }
                        const s = Object.assign({}, commonDefaults, sphereDefaults, params)
                        model.fillSphere(
                            s.pos.x, s.pos.y, s.pos.z,
                            s.radius,
                            s.colors,
                            s.noise
                        );
                    }
                    break;

                case "cylinder":
                    if (Array.isArray(params)) {
                        // Compact: [x, y, z, radius, height, colorData, noise]
                        const [x, y, z, radius, height, colorData, noise=0] = params;
                        model.fillCylinder(
                            x, y, z,
                            radius,
                            height,
                            processColorData(colorData),
                            noise
                        );
                    } else {
                        const cylinderDefaults = { radius: 1, height: 1 }
                        const c = Object.assign({}, commonDefaults, cylinderDefaults, params)
                        model.fillCylinder(
                            c.pos.x, c.pos.y, c.pos.z,
                            c.radius,
                            c.height,
                            c.colors,
                            c.noise
                        );
                    }
                    break;

                case "box":
                    if (Array.isArray(params)) {
                        // Compact: [x, y, z, width, height, depth, colorData, noise]
                        const [x, y, z, width, height, depth, colorData, noise=0] = params;
                        model.fillBox(
                            x, y, z,
                            width, height, depth,
                            processColorData(colorData),
                            noise
                        );
                    } else {
                        const boxDefaults = { width: 1, height: 1, depth: 1 }
                        const b = Object.assign({}, commonDefaults, boxDefaults, params)
                        model.fillBox(
                            b.pos.x, b.pos.y, b.pos.z,
                            b.width,
                            b.height,
                            b.depth,
                            b.colors,
                            b.noise
                        );
                    }
                    break;
            }
        });
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
            property vector3d voxelOffset: _voxelMap.voxelOffset

            // Edge properties
            property real edgeThickness: _voxelMap.edgeThickness
            property real edgeColorFactor: _voxelMap.edgeColorFactor
            property bool showEdges: _voxelMap.showEdges

            // Is expose to allows drawing edges in pixels instead of
            // of world units or pure relative voxel size - this allows
            // same edgethickness across voxelmaps with different voxel
            // sizes - TODO: Don't use
            property real viewportHeight: Screen.desktopAvailableHeight

        }
    ]

}
