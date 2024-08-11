include (clayplugin)

clay_plugin( World

    VERSION 1.0

    SOURCES
        line3dgeometry.h
        line3dinstancing.cpp
        line3dinstancing.h
        line3dgeometry.cpp

    QML_FILES
        ClayWorldBase.qml
        ClayWorld2d.qml
        ClayWorld3d.qml
        ScaleByDimensions.qml
        SceneLoaderBase.qml
        SceneLoader2d.qml
        SceneLoader3d.qml
        Minimap2d.qml
        Sandbox.qml

    LINK_LIBS
        Qt::Core
        Qt::Quick
        Qt::Quick3D
        Qt::Qml
        ClayPhysics
)
