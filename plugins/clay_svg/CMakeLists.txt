cmake_minimum_required(VERSION 3.16)
include (clayplugin)

import_qt_components(Core Quick Qml Svg)

clay_p( ClaySvg
#{
    VERSION 1.0
    DEST_DIR  "${CLAY_PLUGIN_BASE_DIR}/Svg"
    URI Clayground.Svg
    SOURCES
        imageprovider.cpp svgplugin.cpp svgreader.cpp svgwriter.cpp svg.qrc qmldir.in
        Sandbox.qml
    LINK_LIBS
        simple-svg-writer Qt::Core Qt::Quick Qt::Qml Qt::Svg
#}
)
