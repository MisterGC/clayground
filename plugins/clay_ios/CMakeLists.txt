cmake_minimum_required(VERSION 3.19)
include (clayplugin)
find_package(Qt6 REQUIRED COMPONENTS Core Quick Qml)

set (CMAKE_AUTOMOC ON)
set (CMAKE_AUTORCC ON)

find_library(STOREKIT_LIBRARY StoreKit)

# Doesn't use clay_p as advanced, workaround options of
# qt_add_qml_module have to be used to get image provider working
qt_add_qml_module( ClayIos
    VERSION 1.0
    URI Clayground.Ios
    PLUGIN_TARGET ClayIos
    ${CLAYPLUGIN_LINKING}
    OUTPUT_DIRECTORY  "${CLAY_PLUGIN_BASE_DIR}/Ios"

    SOURCES
        iosplugin.cpp
        iosplugin.h
        clayiosbridge.h
        clayiosbridge.mm
        clayiosbridgewrapper.h
        clayiosbridgewrapper.mm

    # TODO: There is not yet a clean way to support for image providers, just
    # following the workaround described in  https://www.qt.io/blog/qml-modules-in-qt-6.2
    NO_PLUGIN_OPTIONAL
    NO_GENERATE_PLUGIN_SOURCE
    NO_CACHEGEN
    CLASS_NAME Clayground_IosPlugin
)

extend_static_plugin_cfg("ClayIos" "Clayground_IosPlugin")
set_target_properties(ClayIos PROPERTIES AUTOMOC TRUE)
target_compile_features(ClayIos PUBLIC cxx_std_17)
target_link_libraries(ClayIos PRIVATE Qt::Core Qt::Quick Qt::Qml ${STOREKIT_LIBRARY})
