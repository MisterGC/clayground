import QtQuick
import QtQuick3D
import QtQuick.Window

VoxelMap {
    id: _voxelMap
    model: _voxelInstancing

    // Dimensions of the voxel map
    property alias width: _voxelInstancing.width
    property alias height: _voxelInstancing.height
    property alias depth: _voxelInstancing.depth

    // Individual cubes + instancing are use, for each voxel, the offset
    // is half its dimension, cause Box3DGeometry has its origin in the bottom face
    voxelOffset: Qt.vector3d(_voxelMap.voxelSize * 0.5, 0, _voxelMap.voxelSize * 0.5)

    instancing: VoxelMapInstancing {
        id: _voxelInstancing
        width: _voxelMap.width
        height: _voxelMap.height
        depth: _voxelMap.depth
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
