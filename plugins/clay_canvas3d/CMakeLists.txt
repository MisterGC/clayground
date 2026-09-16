include (clayplugin)
include (clayshader)

# Needs to be told first otherwise clay_plugin / qt_add_qml_module don't
# generate the singleton instructions in the qmldir.
set_source_files_properties(Label3DRegistry.qml PROPERTIES QT_QML_SINGLETON_TYPE TRUE)

# box3d.frag is composed, not written: two of its three parts are also used by
# ClayCharacter3D, whose face material has to outline and light a box exactly
# the way this one does. Edit box3d_main.glsl and the two parts, never the
# generated box3d.frag in the build directory.
clay_compose_shader(box3d.frag
    PARTS
        box3d_edges.glsl        # shared - the cartoon outline
        box3d_main.glsl         # this material's own MAIN()
        box3d_toon.glsl         # shared - half-lambert lighting
)

# Where the shared parts live, for the plugins that compose their own shaders
# out of them. A cache variable rather than a relative path in the consumer, so
# a plugin does not have to know how many directories up canvas3d sits.
set(CLAY_SHADER_PARTS_DIR "${CMAKE_CURRENT_SOURCE_DIR}"
    CACHE INTERNAL "GLSL parts Canvas3D publishes for other plugins to compose with")

clay_plugin( Canvas3D

    VERSION 1.0

    SOURCES
        src/box3dgeometry.cpp
        src/box3dgeometry.h
        src/dynamicinstancing.cpp
        src/dynamicinstancing.h
        src/perfregistry.cpp
        src/perfregistry.h
        src/poly3dgeometry.cpp
        src/poly3dgeometry.h
        src/line3dinstancing.cpp
        src/line3dinstancing.h
        src/linebatchgeometry.cpp
        src/linebatchgeometry.h
        src/linebatchinstancing.cpp
        src/linebatchinstancing.h
        src/linestyletexturedata.cpp
        src/linestyletexturedata.h
        src/labelglyphatlas.cpp
        src/labelglyphatlas.h
        src/labelbatchinstancing.cpp
        src/labelbatchinstancing.h
        src/voxelmapdata.cpp
        src/voxelmapdata.h
        src/voxelchunk.cpp
        src/voxelchunk.h
        src/voxelmapgeometry.cpp
        src/voxelmapgeometry.h
        src/voxelmapinstancing.cpp
        src/voxelmapinstancing.h
        src/benchcsvwriter.cpp
        src/benchcsvwriter.h

    RESOURCES
        line_batch.frag
        line_batch.vert
        line_batch_shadow.frag
        label_batch.frag
        label_batch.vert
        label_pill.frag
        label_pill.vert
        path_word.frag
        path_word.vert
        voxel_map.frag
        voxel_map.vert
        ${box3d_SHADER}
        box3d.vert
        poly3d.frag
        poly3d.vert

    QML_FILES
        Box3D.qml
        BoxLine3D.qml
        Connector3D.qml
        ConnectorLayer3D.qml
        Label3D.qml
        OrbitCamera3D.qml
        OrbitInput3D.qml
        Label3DRegistry.qml
        LabelBatch3D.qml
        PathLabel3D.qml
        Line3D.qml
        LineBatch3D.qml
        MultiLine3D.qml
        Poly3D.qml
        VoxelMap.qml
        DynamicVoxelMap.qml
        StaticVoxelMap.qml
        PerfHud.qml
        BenchLogger.qml

    LINK_LIBS
        earcut
        Qt::Core
        Qt::Quick
        Qt::Quick3D
        Qt::Qml
        Qt::Concurrent
)

# Add src directory to include paths for the generated code
# TODO: Make this an option of the clay_plugin macro, so that
# we don't have to always write this explicitly
target_include_directories(ClayCanvas3D PRIVATE ${CMAKE_CURRENT_SOURCE_DIR}/src)

# Pure-QML checks on the types that carry logic. The suite imports the sources
# by directory rather than the built module, so it needs no compiled plugin.
include(claytest)
clay_add_qml_test(canvas3d_qml DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR}/tests)

# C++ unit tests for the types the QML suite cannot reach.
add_subdirectory(tests)
