# (c) Clayground Contributors - MIT License, see "LICENSE" file
include(CMakeParseArguments)

# Thanks to https://github.com/xarxer/cmake-qmlplugin for initial inspiration

function(clay_plugin PLUGIN_NAME)

    cmake_minimum_required(VERSION ${CLAY_MIN_CMAKE_VERSION})

    set (CMAKE_AUTOMOC ON)
    set (CMAKE_AUTORCC ON)

    set(oneValueArgs DEST_DIR VERSION URI)
    set(multiValueArgs
        SOURCES
        QML_FILES
        QT_LIBS
        LINK_LIBS)
    cmake_parse_arguments(CLAY_PLUGIN "${options}" "${oneValueArgs}" "${multiValueArgs}" ${ARGN})

    extend_static_plugin_cfg("Clay${PLUGIN_NAME}plugin" "Clayground_${PLUGIN_NAME}Plugin")

    # Extract Qt libraries from LINK_LIBS
    # Letting the user provide the Qt:: prefix also allows the Qt Creator to
    # offer jump to for the depdendency.
    set(QT_LIB_PREFIX "Qt::")
    set(CLAY_PLUGIN_QT_LIBS "")
    foreach(lib ${CLAY_PLUGIN_LINK_LIBS})
        if(lib MATCHES "^${QT_LIB_PREFIX}")
            string(REPLACE "${QT_LIB_PREFIX}" "" qt_lib ${lib})
            list(APPEND CLAY_PLUGIN_QT_LIBS ${qt_lib})
        endif()
    endforeach()

    # Find the necessary Qt packages
    foreach(QT_LIB ${CLAY_PLUGIN_QT_LIBS})
        find_package(Qt6 COMPONENTS ${QT_LIB} REQUIRED)
    endforeach()


    if(NOT CLAY_PLUGIN_DEST_DIR AND NOT CLAY_PLUGIN_URI)
        set(CLAY_PLUGIN_DEST_DIR "${CLAY_PLUGIN_BASE_DIR}/${PLUGIN_NAME}")
        set(CLAY_PLUGIN_URI "Clayground.${PLUGIN_NAME}")
        set(PLUGIN_NAME "Clay${PLUGIN_NAME}")
    endif()

    qt_add_qml_module(${PLUGIN_NAME}
            URI ${CLAY_PLUGIN_URI}
            OUTPUT_DIRECTORY ${CLAY_PLUGIN_DEST_DIR}
            VERSION ${CLAY_PLUGIN_VERSION}
            ${CLAY_PLUGIN_LINKING}
            SOURCES ${CLAY_PLUGIN_SOURCES}
            QML_FILES ${CLAY_PLUGIN_QML_FILES}
            NO_CACHEGEN
            )

    target_compile_features(${PLUGIN_NAME} PUBLIC cxx_std_17)

    # Custom depdendencies
    target_link_libraries(${PLUGIN_NAME} PRIVATE ${CLAY_PLUGIN_LINK_LIBS})

endfunction()


function(init_static_plugin_cfg)
    set(CLAYGROUND_STATIC_PLUGINS "" CACHE INTERNAL "")
    set(CLAYGROUND_IMPORT_PLUGINS "" CACHE INTERNAL "")
    if ("${CLAY_PLUGIN_LINKING}" STREQUAL "STATIC")
        set(CLAYGROUND_IMPORT_PLUGINS "#include<QtQml/qqmlextensionplugin.h>" CACHE INTERNAL "")
    endif()
endfunction()


function(extend_static_plugin_cfg plugin_target plugin_import)
    if ("${CLAY_PLUGIN_LINKING}" STREQUAL "STATIC")
        set(CLAYGROUND_STATIC_PLUGINS "${CLAYGROUND_STATIC_PLUGINS};${plugin_target}" CACHE INTERNAL "")
        set(CLAYGROUND_IMPORT_PLUGINS "${CLAYGROUND_IMPORT_PLUGINS} Q_IMPORT_QML_PLUGIN(${plugin_import})" CACHE INTERNAL "")
    endif()
endfunction()
