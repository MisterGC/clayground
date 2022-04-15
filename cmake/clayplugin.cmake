# (c) Clayground Contributors - MIT License, see "LICENSE" file
include(CMakeParseArguments)

# Thanks to https://github.com/xarxer/cmake-qmlplugin for initial inspiration

# TODO Think about to get rid of this function completly as soon
# as Qt6.3 has been released and qt_add_qml_module is more mature
function(clay_p PLUGIN_NAME)

    set (CMAKE_AUTOMOC ON)
    set (CMAKE_AUTORCC ON)

    set(oneValueArgs DEST_DIR VERSION URI)
    set(multiValueArgs SOURCES QML_FILES LINK_LIBS)
    cmake_parse_arguments(CLAYPLUGIN "${options}" "${oneValueArgs}" "${multiValueArgs}" ${ARGN})

    extend_static_plugin_cfg("Clay${PLUGIN_NAME}plugin" "Clayground_${PLUGIN_NAME}Plugin")

    if(NOT CLAYPLUGIN_DEST_DIR AND NOT CLAYPLUGIN_URI)
        set(CLAYPLUGIN_DEST_DIR "${CLAY_PLUGIN_BASE_DIR}/${PLUGIN_NAME}")
        set(CLAYPLUGIN_URI "Clayground.${PLUGIN_NAME}")
        set(PLUGIN_NAME "Clay${PLUGIN_NAME}")
    endif()

    qt_add_qml_module(${PLUGIN_NAME}
            URI ${CLAYPLUGIN_URI}
            OUTPUT_DIRECTORY ${CLAYPLUGIN_DEST_DIR}
            VERSION ${CLAYPLUGIN_VERSION}
            ${CLAYPLUGIN_LINKING}
            SOURCES ${CLAYPLUGIN_SOURCES}
            QML_FILES ${CLAYPLUGIN_QML_FILES}
            NO_CACHEGEN
            )

    target_compile_features(${PLUGIN_NAME} PUBLIC cxx_std_17)
    target_link_libraries(${PLUGIN_NAME} PRIVATE ${CLAYPLUGIN_LINK_LIBS})

endfunction()


function(init_static_plugin_cfg)
    set(CLAYGROUND_STATIC_PLUGINS "" CACHE INTERNAL "")
    set(CLAYGROUND_IMPORT_PLUGINS "" CACHE INTERNAL "")
    if ("${CLAYPLUGIN_LINKING}" STREQUAL "STATIC")
        set(CLAYGROUND_IMPORT_PLUGINS "#include<QtQml/qqmlextensionplugin.h>" CACHE INTERNAL "")
    endif()
endfunction()


function(extend_static_plugin_cfg plugin_target plugin_import)
    if ("${CLAYPLUGIN_LINKING}" STREQUAL "STATIC")
        set(CLAYGROUND_STATIC_PLUGINS "${CLAYGROUND_STATIC_PLUGINS};${plugin_target}" CACHE INTERNAL "")
        set(CLAYGROUND_IMPORT_PLUGINS "${CLAYGROUND_IMPORT_PLUGINS} Q_IMPORT_QML_PLUGIN(${plugin_import})" CACHE INTERNAL "")
    endif()
endfunction()
