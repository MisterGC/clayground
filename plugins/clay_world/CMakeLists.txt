include (clayplugin)

clay_plugin( World

    VERSION 1.0

    QML_FILES
        Box3DBody.qml
        ClayWorld2d.qml
        ClayWorld3d.qml
        ClayWorldBase.qml
        Minimap2d.qml
        Sandbox.qml
        Sandbox2d.qml
        Sandbox3d.qml
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
