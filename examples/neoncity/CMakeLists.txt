# (c) Clayground Contributors - MIT License, see "LICENSE" file
include (clayapp)

clay_app( neoncity

    VERSION 1.0

    LINK_LIBS
        Qt::Core
        Qt::Qml
        Qt::Quick
        Qt::Quick3D

    QML_FILES
        Main.qml
        Sandbox.qml
        CityView3D.qml
        TileManager.qml
        CityTile.qml
        citygen.js
)

if(CLAY_BUILD_WEBSITE)
    clay_website_register_demo(neoncity)
endif()
