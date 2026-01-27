# (c) Clayground Contributors - MIT License, see "LICENSE" file
#
# CMake module for building the Clayground website with WASM demos
#
# Usage:
#   ~/Qt/6.x.x/wasm_multithread/bin/qt-cmake -B build -DCLAY_BUILD_WEBSITE=ON .
#   cmake --build build --target website      # Production build (baseurl: /clayground)
#   cmake --build build --target website-dev  # Local dev build (baseurl: empty)
#
# Provides:
#   - clay_website_check_prerequisites() - Verify all requirements at configure time
#   - clay_website_register_demo(name) - Register a WASM demo for website inclusion
#   - clay_website_create_target() - Create the 'website' and 'website-dev' build targets

set(CLAY_WEBSITE_DEMOS "" CACHE INTERNAL "List of WASM demos to include in website")
set(CLAY_WEBDOJO_EXAMPLES "" CACHE INTERNAL "WebDojo example registrations")

# Register a webdojo example - auto-detects file vs directory
# SOURCE: Path to file or directory (e.g., plugins/clay_canvas3d/demo)
# DEST_DIR: Directory name in webdojo-examples (e.g., canvas3d)
# DISPLAY_NAME: Human-readable name for the example selector
# ENTRY_FILE: (optional) Entry point filename, defaults to Sandbox.qml
function(clay_website_register_webdojo_example SOURCE DEST_DIR DISPLAY_NAME)
    if(ARGC GREATER 3)
        set(ENTRY_FILE "${ARGV3}")
    else()
        set(ENTRY_FILE "Sandbox.qml")
    endif()

    # Detect if source is file or directory
    if(IS_DIRECTORY ${CMAKE_SOURCE_DIR}/${SOURCE})
        set(SOURCE_TYPE "dir")
    else()
        set(SOURCE_TYPE "file")
    endif()

    set(CLAY_WEBDOJO_EXAMPLES ${CLAY_WEBDOJO_EXAMPLES}
        "${SOURCE}:${DEST_DIR}:${DISPLAY_NAME}:${ENTRY_FILE}:${SOURCE_TYPE}" CACHE INTERNAL "")
    message(STATUS "WebDojo example: ${DISPLAY_NAME} (${SOURCE_TYPE}) <- ${SOURCE}")
endfunction()

# Check all prerequisites at configure time (fail fast)
function(clay_website_check_prerequisites)
    # Must be building for WASM
    if(NOT EMSCRIPTEN)
        message(FATAL_ERROR
            "CLAY_BUILD_WEBSITE=ON requires WASM target.\n"
            "Configure with: ~/Qt/6.x.x/wasm_multithread/bin/qt-cmake -B build -DCLAY_BUILD_WEBSITE=ON .")
    endif()

    # Check for Ruby (prefer homebrew on macOS)
    find_program(RUBY_EXECUTABLE ruby
        HINTS /opt/homebrew/opt/ruby/bin /usr/local/opt/ruby/bin)
    if(NOT RUBY_EXECUTABLE)
        message(FATAL_ERROR
            "Website build requires Ruby.\n"
            "Install Ruby and ensure it's in your PATH.")
    endif()

    # Check for Bundler (prefer homebrew on macOS, using bundle not bundler)
    find_program(BUNDLER_EXECUTABLE bundle
        HINTS /opt/homebrew/opt/ruby/bin /usr/local/opt/ruby/bin)
    if(NOT BUNDLER_EXECUTABLE)
        message(FATAL_ERROR
            "Website build requires Bundler.\n"
            "Install with: gem install bundler")
    endif()

    # Check Jekyll gems are installed
    execute_process(
        COMMAND ${BUNDLER_EXECUTABLE} check
        WORKING_DIRECTORY ${CMAKE_SOURCE_DIR}/docs
        RESULT_VARIABLE BUNDLE_RESULT
        OUTPUT_QUIET ERROR_QUIET
    )
    if(NOT BUNDLE_RESULT EQUAL 0)
        message(FATAL_ERROR
            "Jekyll dependencies missing.\n"
            "Run: cd docs && bundle install")
    endif()

    message(STATUS "Website prerequisites: OK (using ${BUNDLER_EXECUTABLE})")
endfunction()

# Register a demo for inclusion in the website
# The demo target must produce: {name}.html, {name}.js, {name}.wasm
function(clay_website_register_demo DEMO_NAME)
    set(CLAY_WEBSITE_DEMOS ${CLAY_WEBSITE_DEMOS} ${DEMO_NAME} CACHE INTERNAL "")
    message(STATUS "Website demo registered: ${DEMO_NAME}")
endfunction()

# Create the 'website' target that builds everything
function(clay_website_create_target)
    if(NOT CLAY_WEBSITE_DEMOS)
        message(WARNING "No demos registered for website. Use clay_website_register_demo() first.")
    endif()

    # Sync plugin documentation
    add_custom_target(website-sync-docs
        COMMAND chmod +x sync-plugin-docs.sh
        COMMAND ./sync-plugin-docs.sh
        WORKING_DIRECTORY ${CMAKE_SOURCE_DIR}/docs
        COMMENT "Syncing plugin documentation..."
    )

    # Generate enriched index.json for webdojo examples (at configure time)
    # Parses @brief and @tags from entry QML files
    set(EXAMPLES_JSON "{\n  \"version\": \"${PROJECT_VERSION}\",\n  \"examples\": [\n")
    set(FIRST_ENTRY TRUE)
    foreach(MAPPING IN LISTS CLAY_WEBDOJO_EXAMPLES)
        string(REPLACE ":" ";" PARTS "${MAPPING}")
        list(GET PARTS 0 SOURCE)
        list(GET PARTS 1 DEST_DIR)
        list(GET PARTS 2 DISPLAY_NAME)
        list(GET PARTS 3 ENTRY_FILE)
        list(GET PARTS 4 SOURCE_TYPE)

        # Determine entry file path
        if(SOURCE_TYPE STREQUAL "dir")
            set(ENTRY_PATH "${CMAKE_SOURCE_DIR}/${SOURCE}/${ENTRY_FILE}")
        else()
            set(ENTRY_PATH "${CMAKE_SOURCE_DIR}/${SOURCE}")
        endif()

        # Parse @brief and @tags from QML file
        set(BRIEF "")
        set(TAGS_JSON "[]")
        if(EXISTS "${ENTRY_PATH}")
            file(STRINGS "${ENTRY_PATH}" QML_LINES)
            foreach(LINE IN LISTS QML_LINES)
                # Stop parsing after first non-comment line
                string(STRIP "${LINE}" STRIPPED)
                if(STRIPPED AND NOT STRIPPED MATCHES "^//")
                    break()
                endif()
                if(LINE MATCHES "// @brief (.+)")
                    set(BRIEF "${CMAKE_MATCH_1}")
                endif()
                if(LINE MATCHES "// @tags (.+)")
                    set(TAGS_RAW "${CMAKE_MATCH_1}")
                    # Convert comma-separated to JSON array
                    string(REPLACE ", " "\", \"" TAGS_ITEMS "${TAGS_RAW}")
                    set(TAGS_JSON "[\"${TAGS_ITEMS}\"]")
                endif()
            endforeach()
        endif()

        if(NOT FIRST_ENTRY)
            string(APPEND EXAMPLES_JSON ",\n")
        endif()
        set(FIRST_ENTRY FALSE)
        string(APPEND EXAMPLES_JSON "    {\"name\": \"${DISPLAY_NAME}\", \"path\": \"${DEST_DIR}/${ENTRY_FILE}\", \"brief\": \"${BRIEF}\", \"tags\": ${TAGS_JSON}}")
    endforeach()
    string(APPEND EXAMPLES_JSON "\n  ]\n}")
    file(WRITE ${CMAKE_SOURCE_DIR}/docs/webdojo-examples/index.json "${EXAMPLES_JSON}")
    message(STATUS "Generated webdojo-examples/index.json")

    # Sync webdojo examples - auto-detect file vs directory
    set(WEBDOJO_COPY_COMMANDS "")
    foreach(MAPPING IN LISTS CLAY_WEBDOJO_EXAMPLES)
        string(REPLACE ":" ";" PARTS "${MAPPING}")
        list(GET PARTS 0 SOURCE)
        list(GET PARTS 1 DEST_DIR)
        list(GET PARTS 4 SOURCE_TYPE)

        if(SOURCE_TYPE STREQUAL "dir")
            # Copy entire directory
            list(APPEND WEBDOJO_COPY_COMMANDS
                COMMAND ${CMAKE_COMMAND} -E copy_directory
                    ${CMAKE_SOURCE_DIR}/${SOURCE}
                    ${CMAKE_SOURCE_DIR}/docs/webdojo-examples/${DEST_DIR}
            )
        else()
            # Copy single file into directory as Sandbox.qml
            list(APPEND WEBDOJO_COPY_COMMANDS
                COMMAND ${CMAKE_COMMAND} -E make_directory
                    ${CMAKE_SOURCE_DIR}/docs/webdojo-examples/${DEST_DIR}
                COMMAND ${CMAKE_COMMAND} -E copy_if_different
                    ${CMAKE_SOURCE_DIR}/${SOURCE}
                    ${CMAKE_SOURCE_DIR}/docs/webdojo-examples/${DEST_DIR}/Sandbox.qml
            )
        endif()
    endforeach()

    add_custom_target(website-sync-webdojo-examples
        ${WEBDOJO_COPY_COMMANDS}
        # Ensure files are world-readable for web server
        COMMAND chmod -R a+r ${CMAKE_SOURCE_DIR}/docs/webdojo-examples/
        COMMENT "Syncing webdojo examples from source..."
    )

    # Jekyll build for production (with /clayground baseurl for GitHub Pages)
    add_custom_target(website-jekyll
        COMMAND ${BUNDLER_EXECUTABLE} exec jekyll build --baseurl "/clayground"
        WORKING_DIRECTORY ${CMAKE_SOURCE_DIR}/docs
        DEPENDS website-sync-docs website-sync-webdojo-examples docs
        COMMENT "Building Jekyll site (production)..."
    )

    # Jekyll build for local development (no baseurl prefix)
    # Use a helper script to properly pass empty baseurl
    add_custom_target(website-jekyll-dev
        COMMAND ${CMAKE_SOURCE_DIR}/docs/build-dev.sh
        WORKING_DIRECTORY ${CMAKE_SOURCE_DIR}/docs
        DEPENDS website-sync-docs website-sync-webdojo-examples docs
        COMMENT "Building Jekyll site (local dev)..."
    )

    # Copy API documentation to _site
    add_custom_target(website-copy-api
        COMMAND ${CMAKE_COMMAND} -E copy_directory
            ${CMAKE_SOURCE_DIR}/docs/api
            ${CMAKE_SOURCE_DIR}/docs/_site/api
        DEPENDS website-jekyll
        COMMENT "Copying API documentation to website..."
    )

    add_custom_target(website-copy-api-dev
        COMMAND ${CMAKE_COMMAND} -E copy_directory
            ${CMAKE_SOURCE_DIR}/docs/api
            ${CMAKE_SOURCE_DIR}/docs/_site/api
        DEPENDS website-jekyll-dev
        COMMENT "Copying API documentation to website (dev)..."
    )

    # Copy WASM artifacts for each registered demo (separate target per demo)
    # Uses custom HTML from docs/demo/{demo}/ instead of Qt-generated HTML
    set(COPY_TARGETS "website-copy-api")
    set(COPY_TARGETS_DEV "website-copy-api-dev")
    foreach(DEMO IN LISTS CLAY_WEBSITE_DEMOS)
        # Production copy target
        set(COPY_TARGET website-copy-${DEMO})
        add_custom_target(${COPY_TARGET}
            COMMAND ${CMAKE_COMMAND} -E make_directory
                ${CMAKE_SOURCE_DIR}/docs/_site/demo/${DEMO}
            # Copy WASM artifacts (js, wasm, qtloader) from build
            COMMAND ${CMAKE_COMMAND} -E copy_if_different
                ${CMAKE_BINARY_DIR}/bin/${DEMO}.js
                ${CMAKE_BINARY_DIR}/bin/${DEMO}.wasm
                ${CMAKE_BINARY_DIR}/bin/qtloader.js
                ${CMAKE_SOURCE_DIR}/docs/_site/demo/${DEMO}/
            # Copy custom HTML from docs/demo (not Qt-generated)
            COMMAND ${CMAKE_COMMAND} -E copy_if_different
                ${CMAKE_SOURCE_DIR}/docs/demo/${DEMO}/${DEMO}.html
                ${CMAKE_SOURCE_DIR}/docs/_site/demo/${DEMO}/
            DEPENDS ${DEMO} website-jekyll
            COMMENT "Copying ${DEMO} WASM artifacts to website..."
        )
        list(APPEND COPY_TARGETS ${COPY_TARGET})

        # Dev copy target
        set(COPY_TARGET_DEV website-copy-${DEMO}-dev)
        add_custom_target(${COPY_TARGET_DEV}
            COMMAND ${CMAKE_COMMAND} -E make_directory
                ${CMAKE_SOURCE_DIR}/docs/_site/demo/${DEMO}
            # Copy WASM artifacts (js, wasm, qtloader) from build
            COMMAND ${CMAKE_COMMAND} -E copy_if_different
                ${CMAKE_BINARY_DIR}/bin/${DEMO}.js
                ${CMAKE_BINARY_DIR}/bin/${DEMO}.wasm
                ${CMAKE_BINARY_DIR}/bin/qtloader.js
                ${CMAKE_SOURCE_DIR}/docs/_site/demo/${DEMO}/
            # Copy custom HTML from docs/demo (not Qt-generated)
            COMMAND ${CMAKE_COMMAND} -E copy_if_different
                ${CMAKE_SOURCE_DIR}/docs/demo/${DEMO}/${DEMO}.html
                ${CMAKE_SOURCE_DIR}/docs/_site/demo/${DEMO}/
            DEPENDS ${DEMO} website-jekyll-dev
            COMMENT "Copying ${DEMO} WASM artifacts to website (dev)..."
        )
        list(APPEND COPY_TARGETS_DEV ${COPY_TARGET_DEV})
    endforeach()

    # Production target: depends on all copy targets (which depend on demos + jekyll)
    add_custom_target(website
        DEPENDS ${COPY_TARGETS}
        COMMENT "Website build complete: docs/_site/"
    )

    # Dev target: for local testing with empty baseurl
    add_custom_target(website-dev
        DEPENDS ${COPY_TARGETS_DEV}
        COMMENT "Website dev build complete: docs/_site/ (serve with: python3 -m http.server 8080)"
    )
endfunction()
