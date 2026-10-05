# (c) Clayground Contributors - MIT License, see "LICENSE" file
#
# Packages an app built with clay_app for a machine without Qt. Run by the
# <app>_package target that clay_app_package() defines, which passes:
#   PLATFORM   macos | windows | linux
#   APP, EXE   the app's target name and executable; BUNDLE its .app (macOS)
#   NAME, FILE_NAME, ARCH, ICON, OUT_DIR   see clay_app_package()
#   QML_DIR    the build's bin/qml, every Clayground QML module
#   BIN_DIR, LIB_DIR   where the build put executables and libraries
#   SCAN_DIRS  directories with QML the deploy tool scans for imports (|-separated)
#   SEARCH_DIRS  more directories with libraries the app links (|-separated)
#   TOOL       macdeployqt, windeployqt, or qmake (Linux)
#   QT_BINS, QT_LIBS, QT_PLUGINS   the Qt the app is built with
#   LINUXDEPLOY  linuxdeploy, if not on PATH
#
# The deploy tools leave gaps a player's machine shows at once; each repair
# below names the gap it closes. They were found by starting packages on
# machines without Qt (MisterGC/shapes-and-stone#41).

cmake_minimum_required(VERSION 3.20)

string(REPLACE "|" ";" SCAN_DIRS "${SCAN_DIRS}")
string(REPLACE "|" ";" SEARCH_DIRS "${SEARCH_DIRS}")
file(MAKE_DIRECTORY "${OUT_DIR}")

function(_clay_run)
    execute_process(COMMAND ${ARGN} RESULT_VARIABLE _result)
    if(NOT _result EQUAL 0)
        list(JOIN ARGN " " _cmd)
        message(FATAL_ERROR "clay_app_package: failed (${_result}): ${_cmd}")
    endif()
endfunction()

# Qt's SQL drivers other than SQLite link client libraries (PostgreSQL,
# MySQL, ODBC ...) a player does not have. Clayground.Storage needs SQLite.
function(_clay_drop_sql_drivers dir keep)
    file(GLOB _drivers "${dir}/*")
    foreach(_d ${_drivers})
        get_filename_component(_n "${_d}" NAME)
        if(NOT _n STREQUAL keep)
            file(REMOVE "${_d}")
        endif()
    endforeach()
endfunction()

# ---------------------------------------------------------------- macOS
if(PLATFORM STREQUAL "macos")

    set(app "${OUT_DIR}/${NAME}.app")
    set(zip "${OUT_DIR}/${FILE_NAME}-macos-${ARCH}.zip")
    file(REMOVE_RECURSE "${app}")
    file(REMOVE "${zip}")
    _clay_run(ditto "${BUNDLE}" "${app}")

    # clay_app copies bin/qml into the bundle only when the app links, so a
    # plugin rebuilt since then would ship as it was. Copied again from the
    # finished build.
    file(REMOVE_RECURSE "${app}/Contents/Resources/qml")
    _clay_run(ditto "${QML_DIR}" "${app}/Contents/Resources/qml")

    set(args "${app}" "-qmlimport=${QML_DIR}" -verbose=1)
    foreach(d ${SCAN_DIRS})
        list(APPEND args "-qmldir=${d}")
    endforeach()
    _clay_run("${TOOL}" ${args})

    _clay_drop_sql_drivers("${app}/Contents/PlugIns/sqldrivers" libqsqlite.dylib)

    # Qt's headless platform, so the app's start check (QT_QPA_PLATFORM=
    # minimal) runs on the package too; macdeployqt takes only cocoa along.
    file(COPY "${QT_PLUGINS}/platforms/libqminimal.dylib"
         DESTINATION "${app}/Contents/PlugIns/platforms")

    # Every Mach-O file in the bundle
    file(GLOB_RECURSE files LIST_DIRECTORIES false "${app}/*")
    set(machos "")
    foreach(f ${files})
        if(IS_SYMLINK "${f}")
            continue()
        endif()
        file(READ "${f}" magic LIMIT 4 HEX)
        if(magic MATCHES "^(cffaedfe|cefaedfe|cafebabe)$")
            list(APPEND machos "${f}")
        endif()
    endforeach()

    # Clayground's libraries keep the build's rpaths, into the Qt kit and the
    # build tree: on the build machine they would load Qt from outside the
    # package. The executable's @executable_path/../Frameworks is all they need.
    foreach(f ${machos})
        execute_process(COMMAND otool -l "${f}" OUTPUT_VARIABLE out)
        string(REGEX MATCHALL "cmd LC_RPATH\n[^\n]*\n *path [^\n]*" rpaths "${out}")
        foreach(r ${rpaths})
            string(REGEX REPLACE "^.*\n *path (.*) \\(offset [0-9]+\\)$" "\\1" r "${r}")
            if(NOT r MATCHES "^@")
                _clay_run(install_name_tool -delete_rpath "${r}" "${f}")
            endif()
        endforeach()
    endforeach()

    # A changed binary loses its signature, and Apple Silicon starts nothing
    # unsigned. Signed ad hoc: without an Apple developer id Gatekeeper asks
    # the player once.
    _clay_run(codesign --force --deep --sign - "${app}")

    # Nothing may link to or search a library outside the bundle and the system
    set(offenders "")
    foreach(f ${machos})
        file(RELATIVE_PATH rel "${app}" "${f}")
        execute_process(COMMAND otool -L "${f}" OUTPUT_VARIABLE out)
        string(REPLACE "\n" ";" lines "${out}")
        foreach(l ${lines})
            # "<file>:" or "<file> (architecture arm64):" heads each listing
            if(l MATCHES ":$")
                continue()
            endif()
            string(STRIP "${l}" l)
            string(REGEX REPLACE " \\(compatibility.*$" "" dep "${l}")
            if(dep STREQUAL "" OR dep MATCHES "^(@|/System/|/usr/lib/)")
                continue()
            endif()
            list(APPEND offenders "${rel} links to ${dep}")
        endforeach()
        execute_process(COMMAND otool -l "${f}" OUTPUT_VARIABLE out)
        string(REGEX MATCHALL "cmd LC_RPATH\n[^\n]*\n *path [^\n]*" rpaths "${out}")
        foreach(r ${rpaths})
            string(REGEX REPLACE "^.*\n *path (.*) \\(offset [0-9]+\\)$" "\\1" r "${r}")
            if(NOT r MATCHES "^@")
                list(APPEND offenders "${rel} has rpath ${r}")
            endif()
        endforeach()
    endforeach()
    list(LENGTH machos n)
    list(LENGTH offenders bad)
    foreach(o ${offenders})
        message("FAIL ${o}")
    endforeach()
    message(STATUS "clay_app_package: ${n} binaries, ${bad} reach outside the app")
    if(bad GREATER 0)
        message(FATAL_ERROR "clay_app_package: the package would load libraries from outside itself")
    endif()

    _clay_run(ditto -c -k --sequesterRsrc --keepParent "${app}" "${zip}")
    message(STATUS "clay_app_package: ${zip}")

# -------------------------------------------------------------- Windows
elseif(PLATFORM STREQUAL "windows")

    set(pkg "${OUT_DIR}/${NAME}")
    set(zip "${OUT_DIR}/${FILE_NAME}-windows-${ARCH}.zip")
    file(REMOVE_RECURSE "${pkg}")
    file(REMOVE "${zip}")
    file(MAKE_DIRECTORY "${pkg}")

    # The app, Clayground's libraries and theirs (libdatachannel, ggml ...)
    # beside it, Clayground's QML modules in qml\ where clay_app's main looks
    # for them. The build's other executables stay out.
    file(COPY "${EXE}" DESTINATION "${pkg}")
    file(GLOB dlls "${BIN_DIR}/*.dll")
    file(COPY ${dlls} DESTINATION "${pkg}")
    file(COPY "${QML_DIR}/" DESTINATION "${pkg}/qml")

    # Qt and the Qt QML modules the app and Clayground import. Clayground's
    # libraries are named too: the app does not link them, so only that way
    # the Qt they link (Multimedia and its FFmpeg, Widgets, Concurrent) comes
    # along. The compiler runtime is copied below, as DLLs and not as an
    # installer to run first.
    get_filename_component(exe_name "${EXE}" NAME)
    file(GLOB clay_dlls "${pkg}/Clay*.dll")
    set(args --dir "${pkg}" --qmlimport "${pkg}/qml" --no-translations
             --no-compiler-runtime)
    foreach(d ${SCAN_DIRS})
        list(APPEND args --qmldir "${d}")
    endforeach()
    _clay_run("${TOOL}" ${args} "${pkg}/${exe_name}" ${clay_dlls})

    _clay_drop_sql_drivers("${pkg}/sqldrivers" qsqlite.dll)
    # Qt's headless platform, for the app's start check (see macOS)
    file(COPY "${QT_PLUGINS}/platforms/qminimal.dll" DESTINATION "${pkg}/platforms")

    # What the package's binaries import and windeployqt did not bring: the
    # OpenSSL libdatachannel links, the compiler runtime, ggml's OpenMP.
    # Everything else Windows has.
    find_program(DUMPBIN dumpbin)
    if(NOT DUMPBIN)
        message(FATAL_ERROR "clay_app_package: no dumpbin - run the build from an MSVC developer shell")
    endif()
    set(CMAKE_GET_RUNTIME_DEPENDENCIES_PLATFORM "windows+pe")
    set(CMAKE_GET_RUNTIME_DEPENDENCIES_TOOL "dumpbin")
    set(CMAKE_GET_RUNTIME_DEPENDENCIES_COMMAND "${DUMPBIN}")
    file(TO_CMAKE_PATH "$ENV{SystemRoot}" system)
    string(TOLOWER "${system}/" system)
    # The compiler runtime, which the build machine has in System32 and a
    # player's may not; not Windows' own msvcp_win.dll or msvcp110_win.dll
    set(runtime "^(vcruntime|msvcp|vcomp|concrt)[0-9]+(_[0-9]+)?\\.dll$")

    # resolved: what the package's binaries import, resolved in dirs;
    # unresolved: what none of them holds
    function(_clay_imports dirs resolved unresolved)
        file(GLOB_RECURSE libs "${pkg}/*.dll")
        file(GET_RUNTIME_DEPENDENCIES
            EXECUTABLES "${pkg}/${exe_name}"
            LIBRARIES ${libs}
            DIRECTORIES ${dirs}
            PRE_EXCLUDE_REGEXES "^api-ms-" "^ext-ms-"
            # Windows' own DLLs are not followed into, they import what only
            # Windows needs to hold; the compiler runtime is
            POST_EXCLUDE_REGEXES "^[A-Za-z]:[/\\\\][Ww][Ii][Nn][Dd][Oo][Ww][Ss][/\\\\]"
            POST_INCLUDE_REGEXES "[/\\\\](vcruntime|msvcp|vcomp|concrt)[0-9]+(_[0-9]+)?\\.dll$"
            RESOLVED_DEPENDENCIES_VAR res
            UNRESOLVED_DEPENDENCIES_VAR unres
            CONFLICTING_DEPENDENCIES_PREFIX conflict)
        set(${resolved} "${res}" PARENT_SCOPE)
        set(${unresolved} "${unres}" PARENT_SCOPE)
    endfunction()

    file(TO_CMAKE_PATH "$ENV{PATH}" path)
    _clay_imports("${pkg};${QT_BINS};${BIN_DIR};${LIB_DIR};${SEARCH_DIRS};${path}" res unres)
    string(TOLOWER "${pkg}/" pkg_lower)
    foreach(dep ${res})
        file(TO_CMAKE_PATH "${dep}" dep)
        string(TOLOWER "${dep}" lower)
        get_filename_component(n "${lower}" NAME)
        string(FIND "${lower}" "${pkg_lower}" in_pkg)
        string(FIND "${lower}" "${system}" in_system)
        if(in_pkg EQUAL 0 OR (in_system EQUAL 0 AND NOT n MATCHES "${runtime}"))
            continue()
        endif()
        message(STATUS "clay_app_package: adding ${dep}")
        file(COPY "${dep}" DESTINATION "${pkg}")
    endforeach()

    # Nothing may import a DLL from outside the package but Windows itself,
    # and the compiler runtime a player's machine may lack has to be inside
    _clay_imports("${pkg}" res unres)
    set(offenders "")
    foreach(dep ${unres})
        list(APPEND offenders "nothing holds ${dep}")
    endforeach()
    foreach(dep ${res})
        file(TO_CMAKE_PATH "${dep}" dep)
        string(TOLOWER "${dep}" lower)
        get_filename_component(n "${lower}" NAME)
        string(FIND "${lower}" "${pkg_lower}" in_pkg)
        string(FIND "${lower}" "${system}" in_system)
        if(in_pkg EQUAL 0 OR (in_system EQUAL 0 AND NOT n MATCHES "${runtime}"))
            continue()
        endif()
        list(APPEND offenders "${dep} is outside the package")
    endforeach()
    list(LENGTH offenders bad)
    foreach(o ${offenders})
        message("FAIL ${o}")
    endforeach()
    message(STATUS "clay_app_package: ${bad} imports from outside the package")
    if(bad GREATER 0)
        message(FATAL_ERROR "clay_app_package: the package would load DLLs from outside itself")
    endif()

    _clay_run("${CMAKE_COMMAND}" -E chdir "${OUT_DIR}"
              "${CMAKE_COMMAND}" -E tar cf "${zip}" --format=zip "${NAME}")
    message(STATUS "clay_app_package: ${zip}")

# ---------------------------------------------------------------- Linux
elseif(PLATFORM STREQUAL "linux")

    set(appdir "${OUT_DIR}/AppDir")
    set(image "${FILE_NAME}-linux-${ARCH}.AppImage")
    file(REMOVE_RECURSE "${appdir}")
    file(REMOVE "${OUT_DIR}/${image}")

    if(NOT LINUXDEPLOY)
        # A variable of its own: LINUXDEPLOY is passed, empty, and find_program
        # does not search for a variable that is set
        find_program(_linuxdeploy NAMES linuxdeploy linuxdeploy-${ARCH}.AppImage)
        set(LINUXDEPLOY "${_linuxdeploy}")
    endif()
    if(NOT LINUXDEPLOY)
        message(FATAL_ERROR "clay_app_package: no linuxdeploy - put linuxdeploy and "
            "linuxdeploy-plugin-qt on PATH (https://github.com/linuxdeploy/linuxdeploy/releases, "
            "https://github.com/linuxdeploy/linuxdeploy-plugin-qt/releases) or set CLAY_LINUXDEPLOY")
    endif()
    # linuxdeploy and its Qt plugin are AppImages themselves; extracted they
    # run without FUSE, which containers and CI runners often lack
    set(ENV{APPIMAGE_EXTRACT_AND_RUN} 1)

    # The desktop entry and its icon, named after the executable as
    # linuxdeploy wants it
    file(WRITE "${OUT_DIR}/${APP}.desktop"
        "[Desktop Entry]\nType=Application\nName=${NAME}\nExec=${APP}\n"
        "Icon=${APP}\nCategories=Game;\n")
    configure_file("${ICON}" "${OUT_DIR}/${APP}.png" COPYONLY)

    # A Qt plugin that links a library this system lacks stops linuxdeploy
    # (the Qt kit's TIFF plugin wants libtiff.so.5, which Ubuntu 24.04 has
    # no more). Such plugins are left out: linuxdeploy-plugin-qt is given a
    # qmake that names a plugin directory without them.
    set(qmake "${TOOL}")
    set(broken "")
    file(GLOB_RECURSE plugins "${QT_PLUGINS}/*.so")
    foreach(p ${plugins})
        execute_process(COMMAND ldd "${p}" OUTPUT_VARIABLE out ERROR_QUIET)
        if(out MATCHES "not found")
            list(APPEND broken "${p}")
        endif()
    endforeach()
    if(broken)
        set(view "${OUT_DIR}/qt-plugins")
        file(REMOVE_RECURSE "${view}")
        foreach(p ${plugins})
            if(p IN_LIST broken)
                file(RELATIVE_PATH rel "${QT_PLUGINS}" "${p}")
                message(STATUS "clay_app_package: leaving out ${rel}, it links a library this system lacks")
                continue()
            endif()
            file(RELATIVE_PATH rel "${QT_PLUGINS}" "${p}")
            get_filename_component(sub "${view}/${rel}" DIRECTORY)
            file(MAKE_DIRECTORY "${sub}")
            file(CREATE_LINK "${p}" "${view}/${rel}" SYMBOLIC)
        endforeach()
        set(qmake "${OUT_DIR}/qmake")
        file(WRITE "${qmake}" "#!/bin/sh\n\"${TOOL}\" \"$@\" | sed 's|^QT_INSTALL_PLUGINS:.*|QT_INSTALL_PLUGINS:${view}|'\n")
        file(CHMOD "${qmake}" PERMISSIONS OWNER_READ OWNER_WRITE OWNER_EXECUTE
             GROUP_READ GROUP_EXECUTE WORLD_READ WORLD_EXECUTE)
    endif()

    # The app's QML and all of Clayground's for the import scan, bin/qml as
    # where to find the modules; Clayground's libraries where the build put
    # them; Qt's headless platform for the app's start check (see macOS).
    list(JOIN SCAN_DIRS ":" scan)
    set(ENV{QMAKE} "${qmake}")
    set(ENV{QML_SOURCES_PATHS} "${scan}")
    set(ENV{QML_MODULES_PATHS} "${QML_DIR}")
    set(ENV{EXTRA_PLATFORM_PLUGINS} "libqminimal.so")
    set(ENV{LD_LIBRARY_PATH} "${LIB_DIR}:${BIN_DIR}:${QT_LIBS}:$ENV{LD_LIBRARY_PATH}")

    execute_process(COMMAND "${LINUXDEPLOY}" --appdir "${appdir}"
            --executable "${EXE}"
            --desktop-file "${OUT_DIR}/${APP}.desktop"
            --icon-file "${OUT_DIR}/${APP}.png"
            --plugin qt
        WORKING_DIRECTORY "${OUT_DIR}"
        RESULT_VARIABLE result)
    if(NOT result EQUAL 0)
        message(FATAL_ERROR "clay_app_package: linuxdeploy failed (${result})")
    endif()

    # clay_app's main adds <executable dir>/qml as an import path; the Qt
    # plugin put the modules in usr/qml.
    file(CREATE_LINK "../qml" "${appdir}/usr/bin/qml" SYMBOLIC)

    # Two plugins linuxdeploy-plugin-qt misses: SQLite, which
    # Clayground.Storage needs, and the FFmpeg backend of Qt Multimedia,
    # without which Clayground.Sound plays nothing. Copied in with what they
    # link, when the package carries the Qt library they belong to.
    set(extra "")
    file(GLOB has_sql "${appdir}/usr/lib/libQt6Sql.so*")
    if(has_sql AND EXISTS "${QT_PLUGINS}/sqldrivers/libqsqlite.so")
        list(APPEND extra sqldrivers/libqsqlite.so)
    endif()
    file(GLOB has_mm "${appdir}/usr/lib/libQt6Multimedia.so*")
    if(has_mm AND EXISTS "${QT_PLUGINS}/multimedia/libffmpegmediaplugin.so")
        list(APPEND extra multimedia/libffmpegmediaplugin.so)
    endif()
    set(deps_only "")
    foreach(p ${extra})
        get_filename_component(sub "${p}" DIRECTORY)
        file(COPY "${QT_PLUGINS}/${p}" DESTINATION "${appdir}/usr/plugins/${sub}")
        list(APPEND deps_only --deploy-deps-only "${appdir}/usr/plugins/${sub}")
    endforeach()
    if(EXISTS "${appdir}/usr/plugins/sqldrivers")
        _clay_drop_sql_drivers("${appdir}/usr/plugins/sqldrivers" libqsqlite.so)
    endif()

    set(ENV{LDAI_OUTPUT} "${image}")
    execute_process(COMMAND "${LINUXDEPLOY}" --appdir "${appdir}" ${deps_only}
            --output appimage
        WORKING_DIRECTORY "${OUT_DIR}"
        RESULT_VARIABLE result)
    if(NOT result EQUAL 0)
        message(FATAL_ERROR "clay_app_package: linuxdeploy failed to write the AppImage (${result})")
    endif()
    message(STATUS "clay_app_package: ${OUT_DIR}/${image}")

else()
    message(FATAL_ERROR "clay_app_package: unknown platform '${PLATFORM}'")
endif()
