# (c) Clayground Contributors - MIT License, see "LICENSE" file
#
# Unit tests for clay_canvas3d.
#
# The voxel store is a plain QObject, so it is tested straight rather than
# through the QML module: on macOS the Qt-signed qmltestrunner cannot dlopen a
# locally built plugin, which is why the .qml suite next door only ever imports
# the plugin's QML sources.

find_package(Qt6 REQUIRED COMPONENTS Test Gui Qml Quick3D)

add_executable(tst_voxelmapdata
    tst_voxelmapdata.cpp
    ../src/voxelmapdata.cpp
)

set_target_properties(tst_voxelmapdata PROPERTIES AUTOMOC ON)

target_include_directories(tst_voxelmapdata PRIVATE ${CMAKE_CURRENT_SOURCE_DIR}/../src)

target_link_libraries(tst_voxelmapdata PRIVATE
    Qt6::Core
    Qt6::Gui
    Qt6::Test
)

add_test(NAME canvas3d_voxelmapdata COMMAND tst_voxelmapdata)
set_tests_properties(canvas3d_voxelmapdata PROPERTIES LABELS "canvas3d;unit")

# The polygon mesh builder is a free function on plain Qt types, so it is
# tested the same way. Quick3D is linked only because poly3dgeometry.cpp also
# holds the QQuick3DGeometry wrapper - no scene, no window, no RHI is needed.
add_executable(tst_poly3dgeometry
    tst_poly3dgeometry.cpp
    ../src/poly3dgeometry.cpp
)

set_target_properties(tst_poly3dgeometry PROPERTIES AUTOMOC ON)

target_include_directories(tst_poly3dgeometry PRIVATE ${CMAKE_CURRENT_SOURCE_DIR}/../src)

target_link_libraries(tst_poly3dgeometry PRIVATE
    earcut
    Qt6::Core
    Qt6::Gui
    Qt6::Qml
    Qt6::Quick3D
    Qt6::Test
)

add_test(NAME canvas3d_poly3dgeometry COMMAND tst_poly3dgeometry)
set_tests_properties(canvas3d_poly3dgeometry PROPERTIES LABELS "canvas3d;unit")

# The one test that actually renders. It guards the attribute contract behind
# the Poly3D wireframe - that barycentric coordinates smuggled through
# TangentSemantic arrive in the fragment shader untouched - which no amount of
# CPU-side checking can establish. It builds its own tiny QML module rather than
# importing Clayground.Canvas3D so that it needs no installed plugin, and points
# CustomMaterial straight at the shader sources next door.
find_package(Qt6 REQUIRED COMPONENTS Quick)

add_executable(tst_poly3dwireframe
    tst_poly3dwireframe.cpp
    ../src/poly3dgeometry.cpp
)

set_target_properties(tst_poly3dwireframe PROPERTIES AUTOMOC ON)

target_include_directories(tst_poly3dwireframe PRIVATE ${CMAKE_CURRENT_SOURCE_DIR}/../src)

target_compile_definitions(tst_poly3dwireframe PRIVATE
    POLY3D_SHADER_DIR="${CMAKE_CURRENT_SOURCE_DIR}/.."
)

target_link_libraries(tst_poly3dwireframe PRIVATE
    earcut
    Qt6::Core
    Qt6::Gui
    Qt6::Qml
    Qt6::Quick
    Qt6::Quick3D
    Qt6::Test
)

add_test(NAME canvas3d_poly3dwireframe COMMAND tst_poly3dwireframe)
set_tests_properties(canvas3d_poly3dwireframe PROPERTIES LABELS "canvas3d;render")
