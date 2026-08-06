include (clayplugin)
find_package(Qt6 COMPONENTS ShaderTools REQUIRED)

clay_plugin( World

    VERSION 1.0

    QML_FILES
        AnchoredMask.qml
        Box3DBody.qml
        ClayWorld2d.qml
        ClayWorld2dCamera.qml
        ClayWorld3d.qml
        ClayWorldBase.qml
        Minimap2d.qml
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

qt6_add_shaders(ClayWorld "clay_world_shaders"
    PREFIX
        "/qt/qml/Clayground/World"
    FILES
        anchored_mask.frag
)

# QML checks on the loaders and the world types. They run against the built
# module in bin/qml, so the suite needs nothing beyond the default import dir.
include(claytest)
# IMPORTS_BUILT_MODULE: this suite needs the C++ SvgReader, so it loads the
# built Clayground.World plugin rather than importing QML sources (#192).
clay_add_qml_test(world_qml IMPORTS_BUILT_MODULE
    DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR}/tests/qml)
