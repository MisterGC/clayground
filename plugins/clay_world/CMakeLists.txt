include (clayplugin)

clay_plugin( World

    VERSION 1.0

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
        Qt::Qml
        ClayPhysics
)
