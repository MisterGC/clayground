cmake_minimum_required (VERSION 3.12.0 FATAL_ERROR)
include (clayplugin)

find_package(Qt5 5.14 REQUIRED COMPONENTS Core Quick Qml Svg)

clay_p( ClaySvg
#{
    VERSION 1.0
    DEST_DIR  "${CLAY_PLUGIN_BASE_DIR}/Svg"
    URI Clayground.Svg
    SOURCES
        imageprovider.cpp svgplugin.cpp svgreader.cpp svgwriter.cpp qmldir.in
    LINK_LIBS
        simple-svg-writer Qt5::Core Qt5::Quick Qt5::Qml Qt5::Svg
#}
)
