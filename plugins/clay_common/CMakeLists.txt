cmake_minimum_required(VERSION 3.16)
include (clayplugin)

import_qt_components(Core Quick Qml)

clay_p( ClayCommon
#{
    VERSION 1.0
    DEST_DIR  "${CLAY_PLUGIN_BASE_DIR}/Common"
    URI Clayground.Common
    SOURCES
        claycommonplugin.cpp 
        claystopwatch.cpp
        clay_common.qrc 
        qmldir.in
    LINK_LIBS
        Qt::Core Qt::Quick Qt::Qml
#}
)
