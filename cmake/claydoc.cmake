# claydoc.cmake - Documentation generation using QDoc
#
# Provides the clay_docs() function to generate API documentation
# from QDoc comments in Clayground plugins.

# Find QDoc executable
find_program(QDOC_EXECUTABLE
    NAMES qdoc qdoc-qt6
    HINTS
        ${QT_HOST_PATH}/bin
        ${Qt6_DIR}/../../../bin
        $ENV{QTDIR}/bin
    DOC "Path to the QDoc documentation generator"
)

if(NOT QDOC_EXECUTABLE)
    message(WARNING "QDoc not found. Documentation generation will be disabled.")
    return()
endif()

message(STATUS "Found QDoc: ${QDOC_EXECUTABLE}")

# clay_docs()
# Generate API documentation using QDoc
#
# This creates a 'docs' target that runs QDoc with the configuration
# file at docs/clayground.qdocconf
function(clay_docs)
    set(QDOCCONF_FILE "${CMAKE_SOURCE_DIR}/docs/clayground.qdocconf")
    set(OUTPUT_DIR "${CMAKE_SOURCE_DIR}/docs/api")
    set(VERSION_FILE "${CMAKE_SOURCE_DIR}/VERSION")

    if(NOT EXISTS "${QDOCCONF_FILE}")
        message(WARNING "QDoc configuration file not found: ${QDOCCONF_FILE}")
        return()
    endif()

    # Read version from VERSION file
    if(EXISTS "${VERSION_FILE}")
        file(READ "${VERSION_FILE}" CLAYGROUND_VERSION)
        string(STRIP "${CLAYGROUND_VERSION}" CLAYGROUND_VERSION)
    else()
        set(CLAYGROUND_VERSION "dev")
    endif()
    message(STATUS "  Version: ${CLAYGROUND_VERSION}")

    # Create output directory
    file(MAKE_DIRECTORY "${OUTPUT_DIR}")

    # Generate version.json for the API docs
    file(WRITE "${OUTPUT_DIR}/version.json" "{\"version\": \"${CLAYGROUND_VERSION}\"}")

    # Find Qt host include path for C++ parsing
    get_filename_component(QT_HOST_INCLUDE "${QT_HOST_PATH}/include" ABSOLUTE)
    if(NOT EXISTS "${QT_HOST_INCLUDE}")
        # Fallback: derive from QDoc executable path
        get_filename_component(QDOC_DIR "${QDOC_EXECUTABLE}" DIRECTORY)
        get_filename_component(QT_HOST_INCLUDE "${QDOC_DIR}/../include" ABSOLUTE)
    endif()
    message(STATUS "  Qt includes: ${QT_HOST_INCLUDE}")

    # Add documentation target
    # QDoc requires empty output directory, so we use a temp dir and copy results
    set(TEMP_OUTPUT_DIR "${CMAKE_BINARY_DIR}/qdoc-temp")
    set(README_OUTPUT_DIR "${OUTPUT_DIR}/readme")
    set(PLUGINS_DIR "${CMAKE_SOURCE_DIR}/plugins")

    add_custom_target(docs
        COMMAND ${CMAKE_COMMAND} -E rm -rf "${TEMP_OUTPUT_DIR}"
        COMMAND ${CMAKE_COMMAND} -E make_directory "${TEMP_OUTPUT_DIR}"
        COMMAND ${QDOC_EXECUTABLE}
            -I${QT_HOST_INCLUDE}
            -I${QT_HOST_INCLUDE}/QtCore
            -I${QT_HOST_INCLUDE}/QtQml
            --outputdir "${TEMP_OUTPUT_DIR}"
            "${QDOCCONF_FILE}"
        # Copy all generated files (index + all HTML files)
        COMMAND ${CMAKE_COMMAND} -E copy_if_different
            "${TEMP_OUTPUT_DIR}/clayground.index"
            "${OUTPUT_DIR}/clayground.index"
        COMMAND sh -c "cp '${TEMP_OUTPUT_DIR}'/qml-*.html '${OUTPUT_DIR}/' 2>/dev/null || true"
        # Generate README HTML files for each plugin using external script
        COMMAND ${CMAKE_COMMAND} -E make_directory "${README_OUTPUT_DIR}"
        COMMAND bash "${OUTPUT_DIR}/readme/convert-readmes.sh"
        WORKING_DIRECTORY "${CMAKE_SOURCE_DIR}/docs"
        COMMENT "Generating API documentation with QDoc..."
        VERBATIM
    )

    message(STATUS "Documentation target 'docs' configured")
    message(STATUS "  Config: ${QDOCCONF_FILE}")
    message(STATUS "  Output: ${OUTPUT_DIR}")
endfunction()
