cmake_minimum_required(VERSION 3.16)
include (clayplugin)

find_package(Qt6 REQUIRED COMPONENTS Core Quick Qml)

clay_p( ClayCommon
#{
    VERSION 1.0
    DEST_DIR  "${CLAY_PLUGIN_BASE_DIR}/Common"
    URI Clayground.Common
    SOURCES
        claycommonplugin.cpp clay_common.qrc qmldir.in
    LINK_LIBS
        Qt6::Core Qt6::Quick Qt6::Qml
#}
)
