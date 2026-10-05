# (c) Clayground Contributors - MIT License, see "LICENSE" file
include (clayapp)

clay_app( sbx_world3d

    VERSION 1.0

    SOURCES main.cpp

    LINK_LIBS
        Qt::Core
        Qt::Qml
        Qt::Quick

    QML_FILES
        Main.qml
        Sandbox.qml
        Sandbox2d.qml
        Sandbox3d.qml
        Player2d.qml
        Player3d.qml
        Wall2d.qml
        Wall3d.qml

    RES_FILES map.svg
)

# A package that starts on a machine without Qt; CI builds and starts it
# (.github/workflows/package.yml): cmake --build build --target sbx_world3d_package
clay_app_package(sbx_world3d NAME "Clay Topdown" FILE_NAME ClayTopdown)
