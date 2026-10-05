# (c) Clayground Contributors - MIT License, see "LICENSE" file

##
# `clay_app_package` gives an app built with `clay_app` a target that
#  packages it for a machine without Qt: `<app>_package`.
#
#  The package carries the app, Qt, and every Clayground plugin with the
#  libraries they link, and starts from wherever it is unpacked:
#   - macOS:   <FILE_NAME>-macos-<arch>.zip holding "<NAME>.app"
#   - Windows: <FILE_NAME>-windows-x64.zip holding the folder "<NAME>"
#   - Linux:   <FILE_NAME>-linux-<arch>.AppImage
#  The target is not part of `all`; build it by name. Opt-in: an app that
#  does not call this gets no target and builds as before.
#
# Arguments:
#   APP        - the target name given to clay_app
#
# Options:
#   NAME       - what a player sees: the .app's name, the Windows folder,
#                the Linux desktop entry. Default: APP.
#   FILE_NAME  - first part of the package's file name. Default: NAME
#                without spaces.
#   ICON       - a square PNG (at most 512 px) for the Linux desktop entry.
#                Default: Clayground's app icon.
#   OUTPUT_DIR - where the package is written. Default: <build dir>/package.
#
# What each platform needs at build time:
#   - macOS: macdeployqt of the Qt the app is built with (found from it).
#   - Windows: windeployqt (found from Qt) and an MSVC developer shell, for
#     dumpbin and the compiler runtime.
#   - Linux: linuxdeploy and linuxdeploy-plugin-qt on PATH, or
#     CLAY_LINUXDEPLOY pointing at linuxdeploy with the plugin beside it.
#
# Example:
#   clay_app(shapes_and_stone VERSION 0.1 ...)
#   clay_app_package(shapes_and_stone NAME "Shapes and Stone"
#                    FILE_NAME ShapesAndStone ICON packaging/icon.png)
#   # cmake --build build --target shapes_and_stone_package
##
function(clay_app_package APP)

    set(oneValueArgs NAME FILE_NAME ICON OUTPUT_DIR)
    cmake_parse_arguments(CLAY_PKG "" "${oneValueArgs}" "" ${ARGN})

    if(ANDROID OR IOS OR EMSCRIPTEN)
        message(STATUS "clay_app_package: ${APP} - packages exist for desktop platforms only")
        return()
    endif()
    if(NOT TARGET ${APP})
        message(FATAL_ERROR "clay_app_package: there is no target ${APP}; call clay_app(${APP} ...) first")
    endif()

    if(NOT CLAY_PKG_NAME)
        set(CLAY_PKG_NAME "${APP}")
    endif()
    if(NOT CLAY_PKG_FILE_NAME)
        string(REPLACE " " "" CLAY_PKG_FILE_NAME "${CLAY_PKG_NAME}")
    endif()
    if(NOT CLAY_PKG_ICON)
        set(CLAY_PKG_ICON "${CLAY_CMAKE_SCRIPT_DIR}/clay_app/linux/clayground_app.png")
    endif()
    get_filename_component(CLAY_PKG_ICON "${CLAY_PKG_ICON}" ABSOLUTE)
    if(NOT CLAY_PKG_OUTPUT_DIR)
        set(CLAY_PKG_OUTPUT_DIR "${CMAKE_BINARY_DIR}/package")
    endif()
    get_filename_component(CLAY_PKG_OUTPUT_DIR "${CLAY_PKG_OUTPUT_DIR}" ABSOLUTE
                           BASE_DIR "${CMAKE_BINARY_DIR}")

    # What the deploy tools scan for imports: the app's QML, and all of
    # Clayground's, since the package carries every Clayground module and each
    # of them has to find the Qt modules it imports.
    get_target_property(_scan ${APP} CLAY_APP_QML_DIRS)
    if(NOT _scan)
        set(_scan "")
    endif()
    list(APPEND _scan "${CLAY_PLUGIN_BASE_DIR}")

    find_package(Qt6 COMPONENTS Core REQUIRED)
    set(_qt_bins "${QT6_INSTALL_PREFIX}/${QT6_INSTALL_BINS}")
    set(_qt_libs "${QT6_INSTALL_PREFIX}/${QT6_INSTALL_LIBS}")
    set(_qt_plugins "${QT6_INSTALL_PREFIX}/${QT6_INSTALL_PLUGINS}")

    # The architecture in the file name, spelled the way players see it
    if(APPLE AND CMAKE_OSX_ARCHITECTURES)
        string(REPLACE ";" "-" _arch "${CMAKE_OSX_ARCHITECTURES}")
    else()
        string(TOLOWER "${CMAKE_SYSTEM_PROCESSOR}" _arch)
    endif()
    if(_arch STREQUAL "amd64" OR (WIN32 AND _arch STREQUAL "x86_64"))
        set(_arch "x64")
    elseif(_arch STREQUAL "aarch64" AND APPLE)
        set(_arch "arm64")
    endif()

    # The deploy tool of the Qt the app is built with (on Linux its qmake,
    # which tells linuxdeploy where that Qt is)
    set(_bundle "")
    if(APPLE)
        set(_platform macos)
        set(_tool macdeployqt)
        set(_bundle $<TARGET_BUNDLE_DIR:${APP}>)
    elseif(WIN32)
        set(_platform windows)
        set(_tool windeployqt)
    else()
        set(_platform linux)
        set(_tool qmake)
    endif()
    if(TARGET Qt6::${_tool})
        set(_tool $<TARGET_FILE:Qt6::${_tool}>)
    else()
        set(_tool "${_qt_bins}/${_tool}${CMAKE_EXECUTABLE_SUFFIX}")
    endif()

    # libdatachannel links OpenSSL, which the build found outside Qt; on
    # Windows nothing records where its DLLs are but where its headers were
    # found (a cache entry, unlike the libraries found). Searched before PATH,
    # where other programs' copies of OpenSSL come first.
    set(_search "")
    if(OPENSSL_INCLUDE_DIR)
        list(APPEND _search "${OPENSSL_INCLUDE_DIR}/../bin" "${OPENSSL_INCLUDE_DIR}/../lib")
    endif()

    # Lists pass through the custom command as one argument each
    string(REPLACE ";" "|" _scan "${_scan}")
    string(REPLACE ";" "|" _search "${_search}")

    add_custom_target(${APP}_package
        COMMAND ${CMAKE_COMMAND}
            -DPLATFORM=${_platform}
            -DAPP=${APP}
            -DEXE=$<TARGET_FILE:${APP}>
            -DBUNDLE=${_bundle}
            "-DNAME=${CLAY_PKG_NAME}"
            -DFILE_NAME=${CLAY_PKG_FILE_NAME}
            -DARCH=${_arch}
            -DICON=${CLAY_PKG_ICON}
            -DOUT_DIR=${CLAY_PKG_OUTPUT_DIR}
            -DQML_DIR=${QML_IMPORT_PATH}
            -DBIN_DIR=${CMAKE_RUNTIME_OUTPUT_DIRECTORY}
            -DLIB_DIR=${CMAKE_LIBRARY_OUTPUT_DIRECTORY}
            "-DSCAN_DIRS=${_scan}"
            "-DSEARCH_DIRS=${_search}"
            -DTOOL=${_tool}
            -DQT_BINS=${_qt_bins}
            -DQT_LIBS=${_qt_libs}
            -DQT_PLUGINS=${_qt_plugins}
            -DLINUXDEPLOY=${CLAY_LINUXDEPLOY}
            -P ${CLAY_CMAKE_SCRIPT_DIR}/clay_app/package.cmake
        COMMENT "Packaging ${APP} into ${CLAY_PKG_OUTPUT_DIR}"
        USES_TERMINAL
        VERBATIM
    )
    # The package copies bin/qml, so every Clayground module has to be built
    if(TARGET clay_qml_modules)
        add_dependencies(${APP}_package ${APP} clay_qml_modules)
    else()
        add_dependencies(${APP}_package ${APP})
    endif()

endfunction()
