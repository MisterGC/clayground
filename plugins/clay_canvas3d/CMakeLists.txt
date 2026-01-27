include (clayplugin)

clay_plugin( Canvas3D

    VERSION 1.0

    SOURCES
        src/box3dgeometry.cpp
        src/box3dgeometry.h
        src/customlinegeometry.cpp
        src/customlinegeometry.h
        src/line3dgeometry.cpp
        src/line3dgeometry.h
        src/line3dinstancing.cpp
        src/line3dinstancing.h
        src/voxelmapdata.cpp
        src/voxelmapdata.h
        src/voxelmapgeometry.cpp
        src/voxelmapgeometry.h
        src/voxelmapinstancing.cpp
        src/voxelmapinstancing.h

    RESOURCES
        custom_line.frag
        custom_line.vert
        voxel_map.frag
        voxel_map.vert
        box3d.frag
        box3d.vert

    QML_FILES
        Box3D.qml
        BoxLine3D.qml
        Line3D.qml
        MultiLine3D.qml
        VoxelMap.qml
        DynamicVoxelMap.qml
        StaticVoxelMap.qml

    LINK_LIBS
        Qt::Core
        Qt::Quick
        Qt::Quick3D
        Qt::Qml
)

# Add src directory to include paths for the generated code
# TODO: Make this an option of the clay_plugin macro, so that
# we don't have to always write this explicitly
target_include_directories(ClayCanvas3D PRIVATE ${CMAKE_CURRENT_SOURCE_DIR}/src)
