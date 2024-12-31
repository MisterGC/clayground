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

        Box3D.qml
        Box3DBody.qml
        BoxLine3D.qml
        ClayWorld2d.qml
        ClayWorld3d.qml
        ClayWorldBase.qml
        Line3D.qml
        Minimap2d.qml
        MultiLine3D.qml
        Sandbox.qml
        Sandbox2d.qml
        Sandbox3d.qml
        ScaleByDimensions.qml
        SceneLoader2d.qml
        SceneLoader3d.qml
        SceneLoaderBase.qml

    LINK_LIBS
        Qt::Core
        Qt::Quick
        Qt::Quick3D
        Qt::Qml
        ClayPhysics
)
