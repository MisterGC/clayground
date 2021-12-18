cmake_minimum_required(VERSION 3.19)
include (clayplugin)

import_qt_components(Core Quick Qml)

clay_p( ClayPhysics
    VERSION 1.0
    DEST_DIR  "${CLAY_PLUGIN_BASE_DIR}/Physics"
    URI Clayground.Physics
    QML_FILES
            CollisionTracker.qml
            ImageBoxBody.qml
            PhysicsItem.qml
            PhysicsUtils.qml
            RectBoxBody.qml
            VisualizedPolyBody.qml
    LINK_LIBS
        Qt::Core Qt::Quick Qt::Qml
)
