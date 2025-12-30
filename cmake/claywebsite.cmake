# (c) Clayground Contributors - MIT License, see "LICENSE" file
#
# CMake module for building the Clayground website with WASM demos
#
# Usage:
#   ~/Qt/6.x.x/wasm_multithread/bin/qt-cmake -B build -DCLAY_BUILD_WEBSITE=ON .
#   cmake --build build --target website
#
# Provides:
#   - clay_website_check_prerequisites() - Verify all requirements at configure time
#   - clay_website_register_demo(name) - Register a WASM demo for website inclusion
#   - clay_website_create_target() - Create the 'website' build target

set(CLAY_WEBSITE_DEMOS "" CACHE INTERNAL "List of WASM demos to include in website")

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

    # Jekyll build (depends on sync-docs)
    add_custom_target(website-jekyll
        COMMAND ${BUNDLER_EXECUTABLE} exec jekyll build --baseurl "/clayground"
        WORKING_DIRECTORY ${CMAKE_SOURCE_DIR}/docs
        DEPENDS website-sync-docs
        COMMENT "Building Jekyll site..."
    )

    # Copy WASM artifacts for each registered demo (separate target per demo)
    set(COPY_TARGETS "")
    foreach(DEMO IN LISTS CLAY_WEBSITE_DEMOS)
        set(COPY_TARGET website-copy-${DEMO})
        add_custom_target(${COPY_TARGET}
            COMMAND ${CMAKE_COMMAND} -E make_directory
                ${CMAKE_SOURCE_DIR}/docs/_site/demo/${DEMO}
            COMMAND ${CMAKE_COMMAND} -E copy_if_different
                ${CMAKE_BINARY_DIR}/bin/${DEMO}.html
                ${CMAKE_BINARY_DIR}/bin/${DEMO}.js
                ${CMAKE_BINARY_DIR}/bin/${DEMO}.wasm
                ${CMAKE_BINARY_DIR}/bin/qtloader.js
                ${CMAKE_SOURCE_DIR}/docs/_site/demo/${DEMO}/
            DEPENDS ${DEMO} website-jekyll
            COMMENT "Copying ${DEMO} WASM artifacts to website..."
        )
        list(APPEND COPY_TARGETS ${COPY_TARGET})
    endforeach()

    # Main target: depends on all copy targets (which depend on demos + jekyll)
    add_custom_target(website
        DEPENDS ${COPY_TARGETS}
        COMMENT "Website build complete: docs/_site/"
    )
endfunction()
