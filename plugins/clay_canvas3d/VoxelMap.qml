// (c) Clayground Contributors - MIT License, see "LICENSE" file

import QtQuick
import QtQuick3D
import QtQuick.Window

/*!
    \qmltype VoxelMap
    \inqmlmodule Clayground.Canvas3D
    \brief Base type for voxel-based 3D structures.

    VoxelMap is the abstract base type for StaticVoxelMap and DynamicVoxelMap.
    It provides common properties and methods for working with voxel grids,
    including edge rendering, toon shading, and shape filling operations.

    Use StaticVoxelMap for large, unchanging voxel structures, or
    DynamicVoxelMap for voxels that change frequently.

    \sa StaticVoxelMap, DynamicVoxelMap
*/
Model {

    id: _voxelMap

    /*!
        \qmlproperty real VoxelMap::voxelSize
        \brief Size of each voxel cube in world units.

        Defaults to 1.0.
    */
    property real voxelSize: 1.0

    /*!
        \qmlproperty real VoxelMap::spacing
        \brief Gap between adjacent voxels in world units.

        Defaults to 0.0 for solid voxel structures.
    */
    property real spacing: 0.0

    /*!
        \qmlproperty real VoxelMap::width
        \readonly
        \brief Total width of the voxel map in world units.

        Computed as: voxelCountX * (voxelSize + spacing) - spacing
    */
    readonly property real width: _voxelMap.voxelCountX > 0
        ? _voxelMap.voxelCountX * (_voxelMap.voxelSize + _voxelMap.spacing) - _voxelMap.spacing
        : 0

    /*!
        \qmlproperty real VoxelMap::height
        \readonly
        \brief Total height of the voxel map in world units.
    */
    readonly property real height: _voxelMap.voxelCountY > 0
        ? _voxelMap.voxelCountY * (_voxelMap.voxelSize + _voxelMap.spacing) - _voxelMap.spacing
        : 0

    /*!
        \qmlproperty real VoxelMap::depth
        \readonly
        \brief Total depth of the voxel map in world units.
    */
    readonly property real depth: _voxelMap.voxelCountZ > 0
        ? _voxelMap.voxelCountZ * (_voxelMap.voxelSize + _voxelMap.spacing) - _voxelMap.spacing
        : 0

    /*!
        \qmlproperty int VoxelMap::voxelCountX
        \brief Number of voxels along the X axis.
    */
    property int voxelCountX: 0

    /*!
        \qmlproperty int VoxelMap::voxelCountY
        \brief Number of voxels along the Y axis (height).
    */
    property int voxelCountY: 0

    /*!
        \qmlproperty int VoxelMap::voxelCountZ
        \brief Number of voxels along the Z axis.
    */
    property int voxelCountZ: 0

    /*!
        \qmlproperty vector3d VoxelMap::voxelOffset
        \brief Offset applied to voxel edge calculations.
    */
    property vector3d voxelOffset: Qt.vector3d(0, 0, 0)

    /*!
        \qmlproperty real VoxelMap::edgeThickness
        \brief Thickness of grid edge lines.

        Defaults to 0.05.
    */
    property real edgeThickness: 0.05

    /*!
        \qmlproperty real VoxelMap::edgeColorFactor
        \brief Darkening factor for edges.

        Defaults to 1.0.
    */
    property real edgeColorFactor: 1.0

    /*!
        \qmlproperty bool VoxelMap::showEdges
        \brief Whether to render voxel grid lines.

        Defaults to true.
    */
    property bool showEdges: true

    /*!
        \qmlproperty bool VoxelMap::useToonShading
        \brief Enables cartoon-style rendering.

        Creates a Minecraft-like aesthetic with distinct light/shadow
        boundaries. Works best with strong directional light shadows.
    */
    property alias useToonShading: voxelMaterial.useToonShading

    /*!
        \qmlproperty var VoxelMap::model
        \brief The underlying voxel data model.
    */
    property var model: undefined

    /*!
        \qmlproperty bool VoxelMap::autoCommit
        \brief Whether to automatically commit changes.

        Defaults to true.
    */
    property bool autoCommit: true

    /*!
        \qmlmethod color VoxelMap::get(int x, int y, int z)
        \brief Returns the color of the voxel at the specified coordinates.
    */
    function get(x, y, z) {
        return model.voxel(x,y,z);
    }

    /*!
        \qmlmethod void VoxelMap::set(int x, int y, int z, color color)
        \brief Sets the color of the voxel at the specified coordinates.
    */
    function set(x, y, z, color) {
        model.setVoxel(x,y,z,color);
    }

    /*!
        \qmlmethod void VoxelMap::load(string path)
        \brief Loads voxel data from a file.
    */
    function load(path) {
        model.loadFromFile(path);
    }

    /*!
        \qmlmethod void VoxelMap::save(string path)
        \brief Saves voxel data to a file.
    */
    function save(path) {
        model.saveToFile(path);
    }

    /*!
        \qmlmethod void VoxelMap::fill(var shapes)
        \brief Fills the voxel map with shapes.

        Accepts a single shape or an array of shapes. Each shape can be
        specified as an object or array with type and parameters.

        Supported shapes: "sphere", "cylinder", "box"

        A colour may be written as a string or as a \c color value - a bound
        property, a Qt.rgba(), anything - and both forms accept the same
        spellings of \c colors:

        \list
        \li a single colour: \c {colors: "red"} or \c {colors: theme.body}
        \li a list of colours, evenly weighted: \c {colors: ["red", "green"]}
        \li a colour and its weight: \c {colors: ["red", 0.5]}
        \li a list of weighted pairs: \c {colors: [["red", 0.3], ["green", 0.7]]}
        \li the written out form: \c {colors: [{ color: "red", weight: 0.3 }]},
            where \c weight defaults to 1
        \endlist

        Example:
        \qml
        fill([
            { sphere: { pos: Qt.vector3d(5,5,5), radius: 3, colors: ["red"] } },
            ["box", [0, 0, 0, 10, 1, 10, "green"]]
        ])
        \endqml
    */
    function fill(shapes) {
        // Handle single shape case
        if (!Array.isArray(shapes)) {
            shapes = [shapes];
        }

        // A QML `color` value reaches JS as an object with numeric channels,
        // not as a string - telling the two apart is what keeps a bound
        // `color` property from being mistaken for a record or a pair (#178).
        function isColorValue(c) {
            return c !== null && typeof c === 'object'
                && typeof c.r === 'number' && typeof c.g === 'number' && typeof c.b === 'number';
        }

        function isColorLike(c) {
            return typeof c === 'string' || isColorValue(c);
        }

        function toEntry(color, weight) {
            return { color: color, weight: (weight === undefined || weight === null) ? 1 : weight };
        }

        // Normalizes every accepted colour spelling - a single colour, a
        // [colour, weight] pair, a list of colours, a list of pairs, or the
        // fully written out [{ color, weight }] form - into the
        // { color, weight } list the C++ side reads. Colours themselves are
        // passed through untouched, string or value alike.
        function processColorData(colorData) {
            if (colorData === undefined || colorData === null) return [];
            if (isColorLike(colorData)) return [toEntry(colorData)];

            if (!Array.isArray(colorData)) {
                // A lone { color, weight } record
                return ('color' in colorData) ? [toEntry(colorData.color, colorData.weight)] : [colorData];
            }
            if (colorData.length === 0) return [];

            // A single [colour, weight] pair, e.g. ["red", 0.5]
            if (isColorLike(colorData[0]) && colorData.length === 2 && typeof colorData[1] === 'number')
                return [toEntry(colorData[0], colorData[1])];

            return colorData.map(c => {
                if (isColorLike(c)) return toEntry(c);
                if (Array.isArray(c)) return toEntry(c[0], c[1]);
                return toEntry(c.color, c.weight);
            });
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
                            processColorData(s.colors),
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
                            processColorData(c.colors),
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
                            processColorData(b.colors),
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

            // Toon shading control
            // When true, applies cartoon-style lighting with half-lambert formula
            // Creates blocky shadow patterns perfect for voxel aesthetics
            property bool useToonShading: false

            // Is expose to allows drawing edges in pixels instead of
            // of world units or pure relative voxel size - this allows
            // same edgethickness across voxelmaps with different voxel
            // sizes - TODO: Don't use
            property real viewportHeight: Screen.desktopAvailableHeight

        }
    ]

}
