cmake_minimum_required(VERSION 3.19)
include (clayplugin)
find_package(Qt6 REQUIRED COMPONENTS Core Quick Qml)

# Needs to be told first otherwise clay_p / qml_add_module don't generate
# instructions for singletons
set_source_files_properties(Clayground.qml PROPERTIES QT_QML_SINGLETON_TYPE TRUE)

clay_p( Common
    VERSION 1.0
    SOURCES claystopwatch.cpp
    QML_FILES Clayground.qml
    LINK_LIBS Qt::Core Qt::Quick Qt::Qml
)
