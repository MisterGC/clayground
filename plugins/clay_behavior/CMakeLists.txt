include (clayplugin)

clay_plugin( Behavior

    VERSION 1.0

    QML_FILES
        FollowPath.qml
        MoveTo.qml
        NavigateTo.qml
        RectTrigger.qml
        WorldChangedConnections.qml
        DoorBuilder.qml

    LINK_LIBS
        Qt::Core
        Qt::Quick
        Qt::Qml
        ClayWorld
        ClayAlgorithm
)

include(claytest)
# IMPORTS_BUILT_MODULE: MoveTo needs a ClayWorld2d and the C++ Box2D types,
# so the suite loads the built modules from bin/qml (#192).
clay_add_qml_test(behavior_qml IMPORTS_BUILT_MODULE
    DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR}/tests/qml)
