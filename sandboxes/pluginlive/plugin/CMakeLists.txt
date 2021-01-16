project (MyPlugin)
set (CMAKE_AUTOMOC on)

find_package(Qt6 REQUIRED COMPONENTS Core Quick Qml)

add_library(${PROJECT_NAME} SHARED
    myplugin.cpp
    myplugin.h
    mycomponent.cpp
    mycomponent.h
    qmldir.in
)

set (PLUGIN_DEST_DIR "${CMAKE_BINARY_DIR}/bin/plugins/${PROJECT_NAME}")

set_target_properties(
${PROJECT_NAME}
PROPERTIES
    CXX_STANDARD 11
    CXX_STANDARD_REQUIRED on
    CXX_EXTENSIONS NO
    LIBRARY_OUTPUT_DIRECTORY "${PLUGIN_DEST_DIR}"
    RUNTIME_OUTPUT_DIRECTORY "${PLUGIN_DEST_DIR}"
)

target_link_libraries(
${PROJECT_NAME}
PRIVATE
    Qt6::Core
    Qt6::Quick
    Qt6::Qml
)

add_custom_command(TARGET ${PROJECT_NAME} POST_BUILD
    COMMAND ${CMAKE_COMMAND} -E copy
    ${CMAKE_CURRENT_SOURCE_DIR}/qmldir.in
    ${PLUGIN_DEST_DIR}/qmldir
)
