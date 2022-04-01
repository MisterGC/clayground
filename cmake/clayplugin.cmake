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
            ${CLAYPLUGIN_LINKING}
            SOURCES ${CLAYPLUGIN_SOURCES}
            QML_FILES ${CLAYPLUGIN_QML_FILES}
            NO_CACHEGEN
            )

    target_compile_features(${PLUGIN_NAME} PUBLIC cxx_std_17)
    target_link_libraries(${PLUGIN_NAME} PRIVATE ${CLAYPLUGIN_LINK_LIBS})

endfunction()

function(fetch_all_static_clay_plugins)

    if ("${CLAYPLUGIN_LINKING}" STREQUAL "SHARED")
        set(ALL_STATIC_CLAY_PLUGIN_TARGETS "" PARENT_SCOPE)
        set(LOAD_ALL_STATIC_CLAY_PLUGINS "" PARENT_SCOPE)
        return()
    endif()

    set(load_all_plugins "#include <QtQml/qqmlextensionplugin.h>")

    if (TARGET Box2Dplugin)
        list(APPEND all_static_clay_plugins Box2Dplugin)
        set(load_all_plugins "${load_all_plugins}\nQ_IMPORT_QML_PLUGIN(Box2DPlugin)")
    endif()

    if (TARGET ClayCommonplugin)
        list(APPEND all_static_clay_plugins ClayCommonplugin)
        set(load_all_plugins "${load_all_plugins}\nQ_IMPORT_QML_PLUGIN(Clayground_CommonPlugin)")
    endif()

    if (TARGET ClayCanvasplugin)
        list(APPEND all_static_clay_plugins ClayCanvasplugin)
        set(load_all_plugins "${load_all_plugins}\nQ_IMPORT_QML_PLUGIN(Clayground_CanvasPlugin)")
    endif()

    if (TARGET ClayGameControllerplugin)
        list(APPEND all_static_clay_plugins ClayGameControllerplugin)
        set(load_all_plugins "${load_all_plugins}\nQ_IMPORT_QML_PLUGIN(Clayground_GameControllerPlugin)")
    endif()

    if (TARGET ClayStorageplugin)
        list(APPEND all_static_clay_plugins ClayStorageplugin)
        set(load_all_plugins "${load_all_plugins}\nQ_IMPORT_QML_PLUGIN(Clayground_StoragePlugin)")
    endif()

    if (TARGET ClaySvg)
        list(APPEND all_static_clay_plugins ClaySvg)
        set(load_all_plugins "${load_all_plugins}\nQ_IMPORT_QML_PLUGIN(Clayground_SvgPlugin)")
    endif()

    if (TARGET ClayNetworkplugin)
        list(APPEND all_static_clay_plugins ClayNetworkplugin)
        set(load_all_plugins "${load_all_plugins}\nQ_IMPORT_QML_PLUGIN(Clayground_NetworkPlugin)")
    endif()

    if (TARGET ClayPhysicsplugin)
        list(APPEND all_static_clay_plugins ClayPhysicsplugin)
        set(load_all_plugins "${load_all_plugins}\nQ_IMPORT_QML_PLUGIN(Clayground_PhysicsPlugin)")
    endif()

    if (TARGET ClayWorldplugin)
        list(APPEND all_static_clay_plugins ClayWorldplugin)
        set(load_all_plugins "${load_all_plugins}\nQ_IMPORT_QML_PLUGIN(Clayground_WorldPlugin)")
    endif()

    if (TARGET ClayBehaviorplugin)
        list(APPEND all_static_clay_plugins ClayBehaviorplugin)
        set(load_all_plugins "${load_all_plugins}\nQ_IMPORT_QML_PLUGIN(Clayground_BehaviorPlugin)")
    endif()

    set(ALL_STATIC_CLAY_PLUGIN_TARGETS ${all_static_clay_plugins} PARENT_SCOPE)
    set(LOAD_ALL_STATIC_CLAY_PLUGINS ${load_all_plugins} PARENT_SCOPE)

endfunction()
