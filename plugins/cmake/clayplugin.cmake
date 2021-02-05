# Thanks to https://github.com/xarxer/cmake-qmlplugin for inspiration
include(CMakeParseArguments)

if (NOT QML_PLUGIN_LINK_TYPE)
  set(QML_PLUGIN_LINK_TYPE SHARED)
endif()

function(FindQmlPluginDump)
    if(NOT QT_QMAKE_EXECUTABLE)
        message(FATAL_ERROR
                "Cannot find qmlplugindump because QT_QMAKE_EXECUTABLE is not set.")
    endif()
    execute_process(
        COMMAND ${QT_QMAKE_EXECUTABLE} -query QT_INSTALL_BINS
        OUTPUT_VARIABLE QT_BIN_DIR
        OUTPUT_STRIP_TRAILING_WHITESPACE
    )
    set(QTPLUGINDUMP_BIN ${QT_BIN_DIR}/qmlplugindump PARENT_SCOPE)
endfunction()

function(clay_p PLUGIN_NAME)

    set(oneValueArgs DEST_DIR VERSION URI)
    set(multiValueArgs SOURCES LINK_LIBS)
    cmake_parse_arguments(CLAYPLUGIN "${options}" "${oneValueArgs}" "${multiValueArgs}" ${ARGN})

    if(NOT CLAYPLUGIN_VERSION)
        message(FATAL_ERROR "VERSION must be set, no files generated")
    endif()

    set(CMAKE_AUTOMOC ON)
    set(CMAKE_AUTORCC ON)

    #qt_add_plugin(${PLUGIN_NAME} TYPE ${PLUGIN_TYPE} ${CLAYPLUGIN_SOURCES})
    set(output_name ${PLUGIN_NAME})
    add_library(${PLUGIN_NAME} ${QML_PLUGIN_LINK_TYPE} ${CLAYPLUGIN_SOURCES})
    set_property(TARGET ${PLUGIN_NAME} PROPERTY OUTPUT_NAME "${output_name}")
    if (ANDROID)
        qt6_android_apply_arch_suffix("${PLUGIN_NAME}")
        string(REPLACE "." "_" PLUGIN_TYPE "${CLAYPLUGIN_URI}")
        set_target_properties(${PLUGIN_NAME}
            PROPERTIES
            LIBRARY_OUTPUT_NAME "plugins_${PLUGIN_TYPE}_${output_name}"
            )
    endif()

    target_link_libraries(${PLUGIN_NAME} PRIVATE ${CLAYPLUGIN_LINK_LIBS})
    target_compile_features(${PLUGIN_NAME} PUBLIC cxx_std_17)
    set(QML_IMPORT_PATH ${QML_IMPORT_PATH} ${CMAKE_CURRENT_SOURCE_DIR} CACHE STRING "" FORCE)
    target_compile_definitions(${PLUGIN_NAME}
    PRIVATE
        $<$<STREQUAL:${QML_PLUGIN_LINK_TYPE},STATIC>:QT_STATICPLUGIN>
    PUBLIC
        $<$<STREQUAL:${QML_PLUGIN_LINK_TYPE},STATIC>:CLAY_STATIC_PLUGIN>)

    if(ANDROID)
        set(CLAYPLUGIN_LIB_OUT_DIR "${CLAYPLUGIN_DEST_DIR}/../..")
    else()
        set(CLAYPLUGIN_LIB_OUT_DIR "${CLAYPLUGIN_DEST_DIR}")
    endif()
    set_target_properties(${PLUGIN_NAME}
    PROPERTIES
        LIBRARY_OUTPUT_DIRECTORY "${CLAYPLUGIN_LIB_OUT_DIR}"
        RUNTIME_OUTPUT_DIRECTORY "${CLAYPLUGIN_LIB_OUT_DIR}"
    )

    add_custom_command(TARGET ${PLUGIN_NAME} POST_BUILD
        COMMAND ${CMAKE_COMMAND} -E copy
        ${CMAKE_CURRENT_SOURCE_DIR}/qmldir.in
        ${CLAYPLUGIN_DEST_DIR}/qmldir
    )

    if (${QML_PLUGIN_LINK_TYPE} STREQUAL SHARED AND NOT ANDROID)
        FindQmlPluginDump()

        # Generate type info, so that types are available in Qt Creator ...
        add_custom_command( TARGET ${PLUGIN_NAME} POST_BUILD
            COMMAND  ${QTPLUGINDUMP_BIN} -nonrelocatable
            ${CLAYPLUGIN_URI} ${CLAYPLUGIN_VERSION}
            ${CLAYPLUGIN_DEST_DIR}/../.. ${CLAYPLUGIN_DEST_DIR}/plugin.qmltypes
        )
    endif()

endfunction()
