cmake_minimum_required(VERSION 3.16)
include (clayplugin)

find_package(Qt5 5.15 REQUIRED COMPONENTS Core Quick Qml Svg)

clay_p( ClaySvg
#{
    VERSION 1.0
    DEST_DIR  "${CLAY_PLUGIN_BASE_DIR}/Svg"
    URI Clayground.Svg
    SOURCES
        imageprovider.cpp svgplugin.cpp svgreader.cpp svgwriter.cpp svg.qrc qmldir.in
        Sandbox.qml
    LINK_LIBS
        simple-svg-writer Qt5::Core Qt5::Quick Qt5::Qml Qt5::Svg
#}
)
