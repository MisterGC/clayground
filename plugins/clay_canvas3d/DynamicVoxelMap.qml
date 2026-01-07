import QtQuick
import QtQuick3D
import QtQuick.Window

/*!
    \qmltype DynamicVoxelMap
    \inqmlmodule Clayground.Canvas3D
    \brief Voxel map optimized for frequent updates using GPU instancing.

    DynamicVoxelMap renders each voxel as a separate GPU instance, making
    it efficient to update individual voxels without regenerating the
    entire mesh. This is ideal for voxel structures that change frequently,
    such as destructible terrain or building systems.

    For large, static voxel structures, use StaticVoxelMap instead for
    better rendering performance.

    Example usage:
    \qml
    import Clayground.Canvas3D

    DynamicVoxelMap {
        id: voxels
        voxelCountX: 20
        voxelCountY: 20
        voxelCountZ: 20
        voxelSize: 1.0

        Timer {
            running: true
            interval: 100
            repeat: true
            onTriggered: {
                var x = Math.floor(Math.random() * 20)
                var y = Math.floor(Math.random() * 20)
                var z = Math.floor(Math.random() * 20)
                voxels.set(x, y, z, Qt.rgba(Math.random(), Math.random(), Math.random(), 1))
            }
        }
    }
    \endqml

    \sa StaticVoxelMap, VoxelMapInstancing
*/
VoxelMap {
    id: _voxelMap
    model: _voxelInstancing

    /*!
        \qmlproperty int DynamicVoxelMap::voxelCountX
        \brief Number of voxels along the X axis.
    */
    property alias voxelCountX: _voxelInstancing.voxelCountX

    /*!
        \qmlproperty int DynamicVoxelMap::voxelCountY
        \brief Number of voxels along the Y axis (height).
    */
    property alias voxelCountY: _voxelInstancing.voxelCountY

    /*!
        \qmlproperty int DynamicVoxelMap::voxelCountZ
        \brief Number of voxels along the Z axis.
    */
    property alias voxelCountZ: _voxelInstancing.voxelCountZ

    voxelOffset: Qt.vector3d(_voxelMap.voxelSize * 0.5, 0, _voxelMap.voxelSize * 0.5)

    instancing: VoxelMapInstancing {
        id: _voxelInstancing
        voxelSize: _voxelMap.voxelSize
        spacing: _voxelMap.spacing
    }

    // Use a built-in cube model as the source.
    geometry: Box3DGeometry {
        id: _geometry
        size: Qt.vector3d(_voxelMap.voxelSize, _voxelMap.voxelSize, _voxelMap.voxelSize)
    }

    // Override material to use unshaded mode for more vibrant colors
    materials: [
        CustomMaterial {
            id: dynamicVoxelMaterial
            vertexShader: "voxel_map.vert"
            fragmentShader: "voxel_map.frag"
            shadingMode: CustomMaterial.Unshaded  // Unshaded for vibrant colors

            property real voxelSize: _voxelMap.voxelSize
            property real voxelSpacing: _voxelMap.spacing
            property vector3d voxelOffset: _voxelMap.voxelOffset

            // Edge properties
            property real edgeThickness: _voxelMap.edgeThickness
            property real edgeColorFactor: _voxelMap.edgeColorFactor
            property bool showEdges: _voxelMap.showEdges

            property real viewportHeight: Screen.desktopAvailableHeight
        }
    ]
}
