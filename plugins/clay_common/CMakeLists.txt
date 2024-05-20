include (clayplugin)

# Needs to be told first otherwise clay_p / qml_add_module don't generate
# instructions for singletons
set_source_files_properties(Clayground.qml PROPERTIES QT_QML_SINGLETON_TYPE TRUE)

clay_plugin( Common

    VERSION 1.0

    SOURCES
        claystopwatch.cpp
        claystopwatch.h

    QML_FILES Clayground.qml

    LINK_LIBS
        Qt::Core
        Qt::Quick
        Qt::Qml
)
