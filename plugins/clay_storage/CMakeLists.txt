cmake_minimum_required (VERSION 3.12.0 FATAL_ERROR)
include (clayplugin)

find_package(Qt5 5.14 REQUIRED COMPONENTS Core Quick Qml)

clay_p( ClayStorage
#{
    VERSION 1.0
    DEST_DIR  "${CLAY_PLUGIN_BASE_DIR}/Storage"
    URI Clayground.Storage
    SOURCES
        claystorageplugin.cpp clay_storage.qrc qmldir.in
    LINK_LIBS
        Qt5::Core Qt5::Quick Qt5::Qml
#}
)
