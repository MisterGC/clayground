cmake_minimum_required(VERSION 3.19)
include (clayplugin)
find_package(Qt6 REQUIRED COMPONENTS Core Quick Qml)

clay_p( Text
    VERSION 1.0
    SOURCES csvreader.cpp csvwriter.cpp
    QML_FILES CsvModel.qml
    LINK_LIBS Qt::Core Qt::Quick Qt::Qml csv-parser
)
