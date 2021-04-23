include(CMakeParseArguments)

macro(import_qt_components)
    find_package(Qt6 COMPONENTS ${ARGN})
    if (NOT Qt6_FOUND)
        find_package(Qt5 5.15 COMPONENTS ${ARGN} REQUIRED)
    endif()
endmacro()
