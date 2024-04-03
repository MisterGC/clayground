# (c) Clayground Contributors - MIT License, see "LICENSE" file
include (clayapp)

clay_app( sbx_visualfx
    VERSION 1.0
    SOURCES main.cpp
    QML_FILES
        Main.qml
        Sandbox.qml
        AbsorptionFx.qml
        ExplosionFx.qml
    RES_FILES explosion.png
)
