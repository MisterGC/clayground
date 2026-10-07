# (c) Clayground Contributors - MIT License, see "LICENSE" file
#
# What a fresh checkout's first build can take from the builds before it
# (#385): every change starts in a fresh worktree, and without these its first
# build cloned llama.cpp and libdatachannel again and compiled everything
# again, as ccache keys on absolute paths and every worktree has its own.
#
# - CLAY_CCACHE (default ON): when ccache is installed and no compiler
#   launcher was given (CI gives its own), compile through it with base_dir at
#   the source dir, so the same file in another worktree hits the same entry.
# - CLAY_FETCH_CACHE (default: a clayground directory in the user's cache
#   dir; empty turns it off): the FetchContent sources go there once per pinned
#   tag and patch, and every checkout builds from that one copy. Off on CI
#   (the CI environment variable is set), which caches build/_deps itself.

include_guard(GLOBAL)
include(FetchContent)

option(CLAY_CCACHE "Compile through ccache, shared across checkouts" ON)

if(CLAY_CCACHE AND NOT DEFINED CMAKE_CXX_COMPILER_LAUNCHER
        AND NOT DEFINED CMAKE_C_COMPILER_LAUNCHER)
    find_program(CLAY_CCACHE_PROGRAM ccache)
    if(CLAY_CCACHE_PROGRAM)
        # CCACHE_BASEDIR through the environment, not ccache's key=value
        # arguments: those need ccache 4.8. A compiler that already is a ccache
        # symlink is not compiled twice - ccache skips itself.
        set(_clay_launcher ${CMAKE_COMMAND} -E env
            "CCACHE_BASEDIR=${CMAKE_SOURCE_DIR}" ${CLAY_CCACHE_PROGRAM})
        set(CMAKE_C_COMPILER_LAUNCHER ${_clay_launcher})
        set(CMAKE_CXX_COMPILER_LAUNCHER ${_clay_launcher})
        set(CMAKE_OBJC_COMPILER_LAUNCHER ${_clay_launcher})
        set(CMAKE_OBJCXX_COMPILER_LAUNCHER ${_clay_launcher})
    endif()
endif()

if(NOT DEFINED CLAY_FETCH_CACHE)
    if(DEFINED ENV{CLAY_FETCH_CACHE})
        set(_clay_fetch_default "$ENV{CLAY_FETCH_CACHE}")
    elseif(DEFINED ENV{CI})
        set(_clay_fetch_default "")
    elseif(WIN32 AND DEFINED ENV{LOCALAPPDATA})
        set(_clay_fetch_default "$ENV{LOCALAPPDATA}/clayground/fetch")
    elseif(APPLE)
        set(_clay_fetch_default "$ENV{HOME}/Library/Caches/clayground/fetch")
    elseif(DEFINED ENV{XDG_CACHE_HOME})
        set(_clay_fetch_default "$ENV{XDG_CACHE_HOME}/clayground/fetch")
    else()
        set(_clay_fetch_default "$ENV{HOME}/.cache/clayground/fetch")
    endif()
    file(TO_CMAKE_PATH "${_clay_fetch_default}" _clay_fetch_default)
    set(CLAY_FETCH_CACHE "${_clay_fetch_default}" CACHE PATH
        "Where FetchContent sources are kept for every checkout; empty = in the build dir")
endif()

# clay_fetch(<name> <FetchContent_Declare args> [CACHE_KEY_FILES <file>...])
#
# FetchContent_Declare + FetchContent_MakeAvailable, with the source taken from
# CLAY_FETCH_CACHE when it is set. The cached copy is named after a hash of the
# arguments (the tag, the patch command) and the content of CACHE_KEY_FILES
# (the patches; the keyword comes last, it takes every argument after it),
# so changing either fetches a new copy instead of building a
# stale one. Populated under a lock: two checkouts configuring at once fetch it
# once. An explicit FETCHCONTENT_SOURCE_DIR_<NAME> wins over the cache.
function(clay_fetch name)
    cmake_parse_arguments(PARSE_ARGV 1 arg "" "" "CACHE_KEY_FILES")
    set(declare ${arg_UNPARSED_ARGUMENTS})
    string(TOUPPER "${name}" upper)

    if(CLAY_FETCH_CACHE AND NOT FETCHCONTENT_SOURCE_DIR_${upper})
        # The checkout's own path is in the arguments (the patch script); it
        # must not make every worktree a copy of its own
        string(REPLACE "${CMAKE_SOURCE_DIR}" "<src>" key "${declare}")
        foreach(f IN LISTS arg_CACHE_KEY_FILES)
            file(SHA256 "${f}" fhash)
            string(APPEND key ";${fhash}")
        endforeach()
        string(SHA256 key "${key}")
        string(SUBSTRING "${key}" 0 12 key)
        set(src "${CLAY_FETCH_CACHE}/${name}-${key}")

        file(MAKE_DIRECTORY "${CLAY_FETCH_CACHE}")
        file(LOCK "${src}.lock" GUARD FUNCTION TIMEOUT 1800)
        if(NOT EXISTS "${src}/.clay-fetched")
            message(STATUS "clay_fetch: ${name} into ${src}")
            # A copy without the stamp was cut off midway
            file(REMOVE_RECURSE "${src}")
            set(work "${CMAKE_BINARY_DIR}/_deps/${name}-cache")
            FetchContent_Populate(${name}_cache
                ${declare}
                SOURCE_DIR "${src}"
                SUBBUILD_DIR "${work}/subbuild"
                BINARY_DIR "${work}/build")
            file(TOUCH "${src}/.clay-fetched")
        endif()
        set(FETCHCONTENT_SOURCE_DIR_${upper} "${src}")
    endif()

    FetchContent_Declare(${name} ${declare})
    FetchContent_MakeAvailable(${name})
    # MakeAvailable sets these in the scope it is called from, this function's
    foreach(v SOURCE_DIR BINARY_DIR POPULATED)
        set(${name}_${v} "${${name}_${v}}" PARENT_SCOPE)
    endforeach()
endfunction()
