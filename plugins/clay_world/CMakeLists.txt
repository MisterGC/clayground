include (clayplugin)

clay_plugin( World

    VERSION 1.0

    SOURCES
        box3dgeometry.cpp
        box3dgeometry.h
        customlinegeometry.cpp
        customlinegeometry.h
        line3dgeometry.h
        line3dinstancing.cpp
        line3dinstancing.h
        line3dgeometry.cpp

    QML_FILES
        custom_line.frag
        custom_line.vert

        ClayWorldBase.qml
        ClayWorld2d.qml
        ClayWorld3d.qml
        Line3D.qml
        MultiLine3D.qml
        ScaleByDimensions.qml
        SceneLoaderBase.qml
        SceneLoader2d.qml
        SceneLoader3d.qml
        Minimap2d.qml
        Sandbox.qml
        Sandbox2d.qml
        Sandbox3d.qml

    LINK_LIBS
        Qt::Core
        Qt::Quick
        Qt::Quick3D
        Qt::Qml
        ClayPhysics
)

target_sources(ClayWorld
  PRIVATE
    BoxLine3d.qml
)
