cmake_minimum_required(VERSION 3.16)
include (clayplugin)

find_package(Qt6 REQUIRED COMPONENTS Core Quick Qml)

clay_p( ClayStorage
#{
    VERSION 1.0
    DEST_DIR  "${CLAY_PLUGIN_BASE_DIR}/Storage"
    URI Clayground.Storage
    SOURCES
        claystorageplugin.cpp clay_storage.qrc qmldir.in
    LINK_LIBS
        Qt6::Core Qt6::Quick Qt6::Qml
#}
)
