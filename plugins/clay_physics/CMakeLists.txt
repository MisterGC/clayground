include (clayplugin)

# Needs to be told first otherwise clay_p / qml_add_module don't generate
# instructions for singletons
set_source_files_properties(PhysicsUtils.qml PROPERTIES QT_QML_SINGLETON_TYPE TRUE)

clay_plugin( Physics

    VERSION 1.0

    QML_FILES
            CollisionTracker.qml
            ImageBoxBody.qml
            PhysicsItem.qml
            PhysicsUtils.qml
            RectBoxBody.qml
            VisualizedPolyBody.qml

    LINK_LIBS
        Qt::Core
        Qt::Quick
        Qt::Qml
)
