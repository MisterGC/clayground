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
        Light2d.qml
        LightLayer2d.qml
        lightregistry.js
        Minimap2d.qml
        SceneLoader2d.qml
        SceneLoader3d.qml
        SceneLoaderBase.qml
        ScreenFx2d.qml

    LINK_LIBS
        Qt::Core
        Qt::Quick
        Qt::Quick3D
        Qt::Qml
        ClayPhysics
)

# Qt's default GLSL list plus 300 es: WebGL2's vertex shaders are 300 es and
# it refuses to link a fragment shader of another version, so without it
# lights and screen effects drew nothing in the browser (#330).
qt6_add_shaders(ClayWorld "clay_world_shaders"
    PREFIX
        "/qt/qml/Clayground/World"
    GLSL
        "100 es,120,150,300 es"
    FILES
        anchored_mask.frag
        light_layer.frag
        screen_grade.frag
        screen_overlay.frag
)

# QML checks on the loaders and the world types. They run against the built
# module in bin/qml, so the suite needs nothing beyond the default import dir.
include(claytest)
# IMPORTS_BUILT_MODULE: this suite needs the C++ SvgReader, so it loads the
# built Clayground.World plugin rather than importing QML sources (#192).
clay_add_qml_test(world_qml IMPORTS_BUILT_MODULE
    DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR}/tests/qml)
# RENDERS: the hit stop suite compares grabbed frames, which the default
# "minimal" platform leaves empty.
clay_add_qml_test(world_render_qml IMPORTS_BUILT_MODULE RENDERS
    DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR}/tests/render)
