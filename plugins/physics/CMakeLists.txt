project (Physics)
set (CMAKE_AUTOMOC on)
set (CMAKE_AUTORCC on)
set (CMAKE_LIBRARY_OUTPUT_DIRECTORY ${CMAKE_RUNTIME_OUTPUT_DIRECTORY}/plugins/Clayground/${PROJECT_NAME})
set (CMAKE_RUNTIME_OUTPUT_DIRECTORY ${CMAKE_RUNTIME_OUTPUT_DIRECTORY}/plugins/Clayground/${PROJECT_NAME})
find_package(Qt5 REQUIRED COMPONENTS Core Quick Qml)

add_library(${PROJECT_NAME} SHARED
    physicsplugin.cpp
    physicsplugin.h
    qmldir.in
    res.qrc
    PhysicsItem.qml
    VisualizedBoxBody.qml
)

set_target_properties(
${PROJECT_NAME}
PROPERTIES
    CXX_STANDARD 11
    CXX_STANDARD_REQUIRED on
    CXX_EXTENSIONS NO
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
    ${CMAKE_RUNTIME_OUTPUT_DIRECTORY}/qmldir
)
