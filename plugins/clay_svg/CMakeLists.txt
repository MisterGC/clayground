cmake_minimum_required(VERSION 3.19)
include (clayplugin)
find_package(Qt6 REQUIRED COMPONENTS Core Quick Qml Svg)

set (CMAKE_AUTOMOC ON)
set (CMAKE_AUTORCC ON)

# Doesn't use clay_p as advanced, workaround options of
# qt_add_qml_module have to be used to get image provider working
qt_add_qml_module( ClaySvg
    VERSION 1.0
    OUTPUT_DIRECTORY  "${CLAY_PLUGIN_BASE_DIR}/Svg"
    URI Clayground.Svg
    SOURCES imageprovider.cpp svgplugin.cpp svgreader.cpp svgwriter.cpp
    QML_FILES Sandbox.qml SvgImageSource.qml

    # TODO: There is not yet a clean way to support for image providers, just
    # following the workaround described in  https://www.qt.io/blog/qml-modules-in-qt-6.2
    NO_PLUGIN_OPTIONAL
    NO_GENERATE_PLUGIN_SOURCE
    CLASS_NAME SvgPlugin
    PLUGIN_TARGET ClaySvg
)

target_compile_features(ClaySvg PUBLIC cxx_std_17)
target_link_libraries(ClaySvg PRIVATE Qt::Core Qt::Quick Qt::Qml Qt::Svg simple-svg-writer )
