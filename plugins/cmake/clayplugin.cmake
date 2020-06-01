include(CMakeParseArguments)

function(FindQmlPluginDump)
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
        message(ERROR "VERSION must be set, no files generated")
        return()
    endif()

    set(CMAKE_AUTOMOC ON)
    set(CMAKE_AUTORCC ON)

    add_library(${PLUGIN_NAME} SHARED ${CLAYPLUGIN_SOURCES})
    target_link_libraries(${PLUGIN_NAME} PRIVATE ${CLAYPLUGIN_LINK_LIBS})
    target_compile_features(${PLUGIN_NAME} PUBLIC cxx_std_17)

    set_target_properties(${PLUGIN_NAME}
    PROPERTIES
        LIBRARY_OUTPUT_DIRECTORY "${CLAYPLUGIN_DEST_DIR}"
        RUNTIME_OUTPUT_DIRECTORY "${CLAYPLUGIN_DEST_DIR}"
    )

    FindQmlPluginDump()

    add_custom_command(TARGET ${PLUGIN_NAME} POST_BUILD
        COMMAND ${CMAKE_COMMAND} -E copy
        ${CMAKE_CURRENT_SOURCE_DIR}/qmldir.in
        $<TARGET_FILE_DIR:${PLUGIN_NAME}>/qmldir
    )

    # Generate type info, so that types are available in Qt Creator ...
    add_custom_command( TARGET ${PLUGIN_NAME} POST_BUILD
        COMMAND  ${QTPLUGINDUMP_BIN} -nonrelocatable
        ${CLAYPLUGIN_URI} ${CLAYPLUGIN_VERSION}
        $<TARGET_FILE_DIR:${PLUGIN_NAME}>/../.. > $<TARGET_FILE_DIR:${PLUGIN_NAME}>/plugin.qmltypes
    )

endfunction()
