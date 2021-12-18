include(CMakeParseArguments)

macro(import_qt_components)
    find_package(Qt6 COMPONENTS ${ARGN} REQUIRED)
endmacro()

macro(fetch_qt_version)
    find_package(QT NAMES Qt6 Qt5 COMPONENTS Core REQUIRED)
endmacro()
