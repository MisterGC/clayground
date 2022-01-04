# Thanks to https://github.com/xarxer/cmake-qmlplugin for inspiration
include(CMakeParseArguments)

# TODO Think about to get rid of this function completly as soon
# as Qt6.3 has been released and qt_add_qml_module is more mature
function(clay_p PLUGIN_NAME)

    set (CMAKE_AUTOMOC ON)
    set (CMAKE_AUTORCC ON)

    set(oneValueArgs DEST_DIR VERSION URI)
    set(multiValueArgs SOURCES QML_FILES LINK_LIBS)
    cmake_parse_arguments(CLAYPLUGIN "${options}" "${oneValueArgs}" "${multiValueArgs}" ${ARGN})

    if(NOT CLAYPLUGIN_DEST_DIR AND NOT CLAYPLUGIN_URI)
        set(CLAYPLUGIN_DEST_DIR "${CLAY_PLUGIN_BASE_DIR}/${PLUGIN_NAME}")
        set(CLAYPLUGIN_URI "Clayground.${PLUGIN_NAME}")
        set(PLUGIN_NAME "Clay${PLUGIN_NAME}")
        message("Fix names: ${PLUGIN_NAME} ${CLAYPLUGIN_DEST_DIR} ${CLAYPLUGIN_URI}")
    endif()

    qt_add_qml_module(${PLUGIN_NAME}
            URI ${CLAYPLUGIN_URI}
            OUTPUT_DIRECTORY ${CLAYPLUGIN_DEST_DIR}
            VERSION ${CLAYPLUGIN_VERSION}
            SOURCES ${CLAYPLUGIN_SOURCES}
            QML_FILES ${CLAYPLUGIN_QML_FILES}
            NO_CACHEGEN
            )

    target_compile_features(${PLUGIN_NAME} PUBLIC cxx_std_17)
    target_link_libraries(${PLUGIN_NAME} PRIVATE ${CLAYPLUGIN_LINK_LIBS})

endfunction()
