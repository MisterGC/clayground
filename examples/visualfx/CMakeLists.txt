# (c) Clayground Contributors - MIT License, see "LICENSE" file
include (clayapp)

clay_app( sbx_visualfx

    VERSION 1.0

    SOURCES main.cpp

    LINK_LIBS
        Qt::Core
        Qt::Qml
        Qt::Quick

    QML_FILES
        Main.qml
        Sandbox.qml
        AbsorptionFx.qml
        ExplosionFx.qml

    RES_FILES explosion.png
)

# Skip test on Windows - QtQuick.Particles fails with software OpenGL in headless mode
if(WIN32)
    set_tests_properties(testsbx_visualfx PROPERTIES DISABLED TRUE)
endif()
