project (ClaySvg)

set (CMAKE_AUTOMOC on)
set (CMAKE_AUTORCC on)

find_package(Qt5 REQUIRED COMPONENTS Core Quick Qml)

add_library(${PROJECT_NAME} SHARED
    svgplugin.cpp
    svgplugin.h
    svgreader.cpp
    svgreader.h
    svgwriter.cpp
    svgwriter.h
    Sandbox.qml
    qmldir
)

target_compile_features(${PROJECT_NAME} PUBLIC cxx_std_17)

set (PLUGIN_DEST_DIR "${CLAY_PLUGIN_BASE_DIR}/Svg")
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
    simple-svg-writer
)

add_custom_command(TARGET ${PROJECT_NAME} POST_BUILD
    COMMAND ${CMAKE_COMMAND} -E copy
    ${CMAKE_CURRENT_SOURCE_DIR}/qmldir.in
    $<TARGET_FILE_DIR:${PROJECT_NAME}>/qmldir
)
