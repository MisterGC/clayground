cmake_minimum_required (VERSION 3.12.0 FATAL_ERROR)
project (ClayCanvas)

find_package(Qt5 5.14 REQUIRED COMPONENTS Core Quick Qml)

set (CMAKE_AUTOMOC ON)
set (CMAKE_AUTORCC ON)

add_library(${PROJECT_NAME} SHARED
    claycanvasplugin.cpp
    qmldir.in
    res.qrc
    Sandbox.qml
)

target_compile_features(${PROJECT_NAME} PUBLIC cxx_std_17)

set (PLUGIN_DEST_DIR "${CLAY_PLUGIN_BASE_DIR}/Canvas")
set_target_properties(${PROJECT_NAME}
PROPERTIES
    LIBRARY_OUTPUT_DIRECTORY "${PLUGIN_DEST_DIR}"
    RUNTIME_OUTPUT_DIRECTORY "${PLUGIN_DEST_DIR}"
)

target_link_libraries(
${PROJECT_NAME}
PRIVATE
    Qt5::Core
    Qt5::Quick
    Qt5::Qml
)

add_custom_command(TARGET ${PROJECT_NAME} POST_BUILD
    COMMAND ${CMAKE_COMMAND} -E copy
    ${CMAKE_CURRENT_SOURCE_DIR}/qmldir.in
    $<TARGET_FILE_DIR:${PROJECT_NAME}>/qmldir
)
