cmake_minimum_required (VERSION 3.12.0 FATAL_ERROR)
include (clayplugin)

find_package(Qt5 5.14 REQUIRED COMPONENTS Core Quick Qml)

clay_p( ClayNetwork
#{
    VERSION 1.0
    DEST_DIR  "${CLAY_PLUGIN_BASE_DIR}/Network"
    URI Clayground.Network
    SOURCES
        claynetworkplugin.h claynetworkplugin.cpp qmldir.in
    LINK_LIBS
        Qt5::Core Qt5::Quick Qt5::Qml
#}
)
