// (c) Clayground Contributors - MIT License, see "LICENSE" file

import QtQuick
import QtQuick3D

/*!
    \qmltype StaticVoxelMap
    \inqmlmodule Clayground.Canvas3D
    \brief Optimized voxel map for large, static structures.

    StaticVoxelMap uses greedy meshing to combine adjacent voxels of the
    same color into larger quads, significantly reducing vertex count.
    This makes it ideal for large voxel structures that don't change
    frequently.

    The geometry is regenerated when voxels change, so use DynamicVoxelMap
    for frequently changing voxel data.

    Example usage:
    \qml
    import Clayground.Canvas3D

    StaticVoxelMap {
        voxelCountX: 50
        voxelCountY: 20
        voxelCountZ: 50
        voxelSize: 1.0
        useToonShading: true

        Component.onCompleted: {
            fill({ sphere: { pos: Qt.vector3d(25, 10, 25), radius: 8,
                            colors: ["red", "orange"] } })
        }
    }
    \endqml

    \sa DynamicVoxelMap, VoxelMapGeometry
*/
VoxelMap {
    id: _voxelMap
    model: _voxelMesh

    /*!
        \qmlproperty int StaticVoxelMap::voxelCountX
        \brief Number of voxels along the X axis.
    */
    property alias voxelCountX: _voxelMesh.voxelCountX

    /*!
        \qmlproperty int StaticVoxelMap::voxelCountY
        \brief Number of voxels along the Y axis (height).
    */
    property alias voxelCountY: _voxelMesh.voxelCountY

    /*!
        \qmlproperty int StaticVoxelMap::voxelCountZ
        \brief Number of voxels along the Z axis.
    */
    property alias voxelCountZ: _voxelMesh.voxelCountZ

    voxelOffset: Qt.vector3d(
                     (_voxelMap.voxelCountX % 2 == 0) ? 0 : (_voxelMap.voxelSize * 0.5),
                     0,
                     (_voxelMap.voxelCountZ % 2 == 0) ? 0 : (_voxelMap.voxelSize * 0.5)
                     )

    function load(path) {_voxelMesh.loadFromFile(path);}
    function save(path) {_voxelMesh.saveToFile(path);}

    geometry: VoxelMapGeometry {
        id: _voxelMesh
        voxelSize: _voxelMap.voxelSize
        spacing: _voxelMap.spacing
    }
}
