cmake_minimum_required (VERSION 3.12.0 FATAL_ERROR)
include (clayplugin)

find_package(Qt5 5.15 REQUIRED COMPONENTS Core Quick Qml)

clay_p( ClayGameController
#{
    VERSION 1.0
    DEST_DIR  "${CLAY_PLUGIN_BASE_DIR}/GameController"
    URI Clayground.GameController
    SOURCES
        claygamectrlplugin.cpp clay_controller.qrc qmldir.in Sandbox.qml
    LINK_LIBS
        Qt5::Core Qt5::Quick Qt5::Qml
#}
)
