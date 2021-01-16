cmake_minimum_required(VERSION 3.16)
include (clayplugin)

find_package(Qt6 REQUIRED COMPONENTS Core Quick Qml Svg)

clay_p( ClaySvg
#{
    VERSION 1.0
    DEST_DIR  "${CLAY_PLUGIN_BASE_DIR}/Svg"
    URI Clayground.Svg
    SOURCES
        imageprovider.cpp svgplugin.cpp svgreader.cpp svgwriter.cpp svg.qrc qmldir.in
        Sandbox.qml
    LINK_LIBS
        simple-svg-writer Qt6::Core Qt6::Quick Qt6::Qml Qt6::Svg
#}
)
