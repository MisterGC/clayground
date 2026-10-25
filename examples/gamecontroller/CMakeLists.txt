# (c) Clayground Contributors - MIT License, see "LICENSE" file
include (clayapp)

# The GameController demo as an app of its own: the demo is a sandbox the
# Dojo loads, and a phone has no Dojo. Built for iOS it is how a pad is
# checked on a device (#465).
set(_clay_gc_demo "${CMAKE_CURRENT_SOURCE_DIR}/../../plugins/clay_gamecontroller/demo/Sandbox.qml")
set_source_files_properties("${_clay_gc_demo}" PROPERTIES QT_RESOURCE_ALIAS Sandbox.qml)

clay_app( gamecontroller

    VERSION 1.0

    LINK_LIBS
        Qt::Core
        Qt::Qml
        Qt::Quick

    QML_FILES
        Main.qml
        "${_clay_gc_demo}"
)
