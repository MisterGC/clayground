# (c) Clayground Contributors - MIT License, see "LICENSE" file
#
# Clay Network Plugin - Multiplayer networking for games
# WASM: WebRTC via PeerJS for P2P multiplayer
# Desktop/Mobile: TCP/UDP sockets for local network P2P
#
include(clayplugin)

# Common sources (all platforms)
set(COMMON_SOURCES
    claywebaccess.cpp
    claywebaccess.h
)

set(COMMON_QML
    ClayHttpClient.qml
    SandboxHttpClient.qml
)

if(EMSCRIPTEN)
    # WASM: WebRTC/PeerJS-based P2P
    set(PLATFORM_SOURCES
        claymultiplayer.cpp
        claymultiplayer.h
    )
    set(PLATFORM_QML
        ClayMultiplayer.qml
        SandboxMultiplayer.qml
    )
else()
    # Native: TCP/UDP P2P (existing implementation)
    set(PLATFORM_SOURCES
        claynetworknode.cpp
        claynetworknode.h
        connection.cpp
        connection.h
        peermanager.cpp
        peermanager.h
        server.cpp
        server.h
    )
    set(PLATFORM_QML
        ClayNetworkUser.qml
        Sandbox.qml
    )
endif()

clay_plugin(Network
    VERSION 1.2

    SOURCES
        ${COMMON_SOURCES}
        ${PLATFORM_SOURCES}

    QML_FILES
        ${COMMON_QML}
        ${PLATFORM_QML}

    LINK_LIBS
        Qt::Core
        Qt::Quick
        Qt::Qml
        Qt::Network
)
