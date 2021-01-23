include(CMakeParseArguments)

macro(import_qt_components)
    find_package(Qt6 COMPONENTS ${ARGN})
    if (NOT Qt6_FOUND)
        find_package(Qt5 5.15 COMPONENTS ${ARGN} REQUIRED)
    endif()
endmacro()

macro(fetch_qt_version)
    find_package(QT NAMES Qt6 Qt5 COMPONENTS Core REQUIRED)
endmacro()
