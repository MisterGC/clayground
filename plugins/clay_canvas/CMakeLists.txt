# (c) Clayground Contributors - MIT License, see "LICENSE" file
include (clayplugin)

clay_plugin( Canvas

    VERSION 1.0

    QML_FILES
        ClayCanvas.qml
        Axes.qml
        Connector.qml
        Image.qml
        Poly.qml
        Rectangle.qml
        Text.qml
        sketch.js

    # The hand font a sketched Text writes in. Shipped with the plugin so a
    # board looks the same on every machine - the lab kernel's handFont is a
    # list of families the host may or may not have (OFL, see Caveat-OFL.txt).
    RESOURCES
        fonts/Caveat.ttf

    LINK_LIBS
        Qt::Core
        Qt::Quick
        Qt::Qml
)

# The pen's geometry (wobble, arrow heads, box edges) and the ink split that
# lets an item draw itself part-way are arithmetic, so they are checked with
# no engine, the way the lab kits are (#199). A wrong split would otherwise
# only show as a picture that looks slightly off.
include(claytest)
clay_add_node_test(canvas_sketch SCRIPT ${CMAKE_CURRENT_SOURCE_DIR}/sketch.test.js)

# The items' own rules - a progress that trims, a pen that samples, an arrow
# that lands after its shaft, a text that writes whole letters - as a suite
# against the built module (the sketch import and the shipped font live in
# the plugin's resources, so a plain directory import would not find them).
clay_add_qml_test(canvas_qml IMPORTS_BUILT_MODULE
    DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR}/tests)
