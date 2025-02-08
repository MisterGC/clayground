include (clayplugin)

clay_plugin( Canvas3D

    VERSION 1.0

    SOURCES
        box3dgeometry.cpp
        box3dgeometry.h
        customlinegeometry.cpp
        customlinegeometry.h
        line3dgeometry.cpp
        line3dgeometry.h
        line3dinstancing.cpp
        line3dinstancing.h
        voxelmapdata.cpp
        voxelmapdata.h
        voxelmapgeometry.cpp
        voxelmapgeometry.h
        voxelmapinstancing.cpp
        voxelmapinstancing.h

    RESOURCES
        custom_line.frag
        custom_line.vert
        voxel_map.frag
        voxel_map.vert

    QML_FILES
        Box3D.qml
        BoxLine3D.qml
        Line3D.qml
        MultiLine3D.qml
        Sandbox.qml
        VoxelMap.qml
        DynamicVoxelMap.qml
        StaticVoxelMap.qml

    LINK_LIBS
        Qt::Core
        Qt::Quick
        Qt::Quick3D
        Qt::Qml
)
