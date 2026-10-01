# (c) Clayground Contributors - MIT License, see "LICENSE" file
#
# Clay Network Plugin - P2P networking for games, apps, and distributed systems
# Uses WebRTC for all platforms:
#   WASM: WebRTC via browser APIs + PeerJS signaling
#   Desktop/Mobile: WebRTC via libdatachannel + PeerJS signaling (cloud) or local signaling (LAN)
#
include(clayplugin)
include(FetchContent)

# Common sources (all platforms)
set(COMMON_SOURCES
    claywebaccess.cpp
    claywebaccess.h
    link_conditioner.cpp
    link_conditioner.h
    sender.h
)

set(COMMON_QML
    Network.qml
    ClayHttpClient.qml
    StateInterpolator.qml
    NetworkMonitor.qml
)

if(EMSCRIPTEN)
    # WASM: WebRTC via browser + PeerJS signaling
    set(PLATFORM_SOURCES
        claynetwork_wasm.cpp
        claynetwork_wasm.h
    )

    # The browser's link conditioner is plain JS, so node can test it
    # (link_conditioner.test.js); the backend embeds it as a string and
    # evaluates it in the page. COPYONLY rewrites the header only when the
    # script changed, so an unrelated reconfigure rebuilds nothing.
    file(READ ${CMAKE_CURRENT_SOURCE_DIR}/link_conditioner.js CLAY_LINK_CONDITIONER_JS)
    file(WRITE ${CMAKE_CURRENT_BINARY_DIR}/link_conditioner_js.h.tmp
        "// Generated from link_conditioner.js - do not edit\n"
        "#pragma once\n"
        "static const char kLinkConditionerJs[] = R\"CLAYJS(${CLAY_LINK_CONDITIONER_JS})CLAYJS\";\n")
    configure_file(${CMAKE_CURRENT_BINARY_DIR}/link_conditioner_js.h.tmp
                   ${CMAKE_CURRENT_BINARY_DIR}/link_conditioner_js.h COPYONLY)
    set_property(DIRECTORY APPEND PROPERTY CMAKE_CONFIGURE_DEPENDS
                 ${CMAKE_CURRENT_SOURCE_DIR}/link_conditioner.js)
else()
    # Native: WebRTC via libdatachannel
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

    set(PLATFORM_SOURCES
        claynetwork_native.cpp
        claynetwork_native.h
        signaling_peerjs.cpp
        signaling_peerjs.h
        signaling_local.cpp
        signaling_local.h
    )
endif()

set(LINK_LIBRARIES
    Qt::Core
    Qt::Quick
    Qt::Qml
    Qt::Network
)

if(NOT EMSCRIPTEN)
    list(APPEND LINK_LIBRARIES LibDataChannel::LibDataChannel)
endif()

clay_plugin(Network
    VERSION 2.0

    SOURCES
        ${COMMON_SOURCES}
        ${PLATFORM_SOURCES}

    QML_FILES
        ${COMMON_QML}

    LINK_LIBS
        ${LINK_LIBRARIES}
)

if(EMSCRIPTEN)
    target_include_directories(ClayNetwork PRIVATE ${CMAKE_CURRENT_BINARY_DIR})
endif()

# Add tests (only for native builds, not WASM)
if(NOT EMSCRIPTEN AND BUILD_TESTING)
    add_subdirectory(tests)
endif()
