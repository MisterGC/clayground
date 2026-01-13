# (c) Clayground Contributors - MIT License, see "LICENSE" file
#
# Clay Network Plugin - P2P networking for games, apps, and distributed systems
# WASM: WebRTC via browser + PeerJS signaling
# Desktop/Mobile: WebRTC via libdatachannel + PeerJS signaling
#
include(clayplugin)
include(FetchContent)

# Common sources (all platforms)
set(COMMON_SOURCES
    claywebaccess.cpp
    claywebaccess.h
)

set(COMMON_QML
    Network.qml
    ClayHttpClient.qml
    SandboxHttpClient.qml
)

if(EMSCRIPTEN)
    # WASM: WebRTC via browser + PeerJS signaling
    set(PLATFORM_SOURCES
        claynetwork_wasm.cpp
        claynetwork_wasm.h
    )
    set(PLATFORM_QML
        SandboxNetwork.qml
    )
    set(WEBRTC_AVAILABLE ON)
else()
    # Native: WebRTC via libdatachannel
    option(CLAYGROUND_USE_WEBRTC "Enable WebRTC networking via libdatachannel" ON)

    if(CLAYGROUND_USE_WEBRTC)
        FetchContent_Declare(
            libdatachannel
            GIT_REPOSITORY https://github.com/paullouisageneau/libdatachannel
            GIT_TAG v0.21.2
            GIT_SHALLOW TRUE
        )
        # Disable unneeded features
        set(NO_MEDIA ON CACHE BOOL "" FORCE)
        set(NO_WEBSOCKET OFF CACHE BOOL "" FORCE)  # We need WebSocket for signaling
        set(NO_EXAMPLES ON CACHE BOOL "" FORCE)
        set(NO_TESTS ON CACHE BOOL "" FORCE)

        FetchContent_MakeAvailable(libdatachannel)
        set(WEBRTC_AVAILABLE ON)

        set(PLATFORM_SOURCES
            claynetwork_native.cpp
            claynetwork_native.h
            signaling_peerjs.cpp
            signaling_peerjs.h
        )
    else()
        set(WEBRTC_AVAILABLE OFF)
        # Fallback to existing LAN-only networking
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
    endif()

    set(PLATFORM_QML
        ClayNetworkUser.qml
        SandboxNetwork.qml
        Sandbox.qml
    )
endif()

set(LINK_LIBRARIES
    Qt::Core
    Qt::Quick
    Qt::Qml
    Qt::Network
)

if(WEBRTC_AVAILABLE AND NOT EMSCRIPTEN)
    list(APPEND LINK_LIBRARIES LibDataChannel::LibDataChannel)
endif()

clay_plugin(Network
    VERSION 2.0

    SOURCES
        ${COMMON_SOURCES}
        ${PLATFORM_SOURCES}

    QML_FILES
        ${COMMON_QML}
        ${PLATFORM_QML}

    LINK_LIBS
        ${LINK_LIBRARIES}
)

# Add tests (only for native builds, not WASM)
if(NOT EMSCRIPTEN AND BUILD_TESTING)
    add_subdirectory(tests)
endif()
