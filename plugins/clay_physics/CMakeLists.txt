include (clayplugin)

# Needs to be told first otherwise clay_p / qml_add_module don't generate
# instructions for singletons
set_source_files_properties(PhysicsUtils.qml PROPERTIES QT_QML_SINGLETON_TYPE TRUE)

clay_plugin( Physics

    VERSION 1.0

    QML_FILES
            CircleBody.qml
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

# QML checks on the body types. The suite drives a Box2D World by hand
# (running: false + step()) so the outcome does not depend on frame timing.
include(claytest)
# IMPORTS_BUILT_MODULE: Box2D and Clayground.Physics are loaded as built
# plugins from bin/qml, not imported as QML sources (#192).
clay_add_qml_test(physics_qml IMPORTS_BUILT_MODULE
    DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR}/tests/qml)
