# (c) Clayground Contributors - MIT License, see "LICENSE" file
#
# Unit tests for clay_canvas3d.
#
# The voxel store is a plain QObject, so it is tested straight rather than
# through the QML module: on macOS the Qt-signed qmltestrunner cannot dlopen a
# locally built plugin, which is why the .qml suite next door only ever imports
# the plugin's QML sources.

find_package(Qt6 REQUIRED COMPONENTS Test Gui)

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
