# (c) Clayground Contributors - MIT License, see "LICENSE" file
#
# Unit tests for clay_network plugin

find_package(Qt6 REQUIRED COMPONENTS Test)
include(claytest)

# Serialization tests (no network required)
add_executable(tst_network_serialization
    tst_network_serialization.cpp
)

set_target_properties(tst_network_serialization PROPERTIES AUTOMOC ON)

# sender.h - the sender attribution both backends share
target_include_directories(tst_network_serialization PRIVATE ${CMAKE_CURRENT_SOURCE_DIR}/..)

target_link_libraries(tst_network_serialization PRIVATE
    Qt6::Core
    Qt6::Test
)

add_test(NAME network_serialization COMMAND tst_network_serialization)
set_tests_properties(network_serialization PROPERTIES LABELS "network;unit")

# Link conditioner (#301): what loss, latency, jitter, a bandwidth cap and a
# blackout do to a packet, on a test clock. Qt Core only.
add_executable(tst_link_conditioner
    tst_link_conditioner.cpp
    ${CMAKE_CURRENT_SOURCE_DIR}/../link_conditioner.cpp
)

set_target_properties(tst_link_conditioner PROPERTIES AUTOMOC ON)

target_include_directories(tst_link_conditioner PRIVATE ${CMAKE_CURRENT_SOURCE_DIR}/..)

target_link_libraries(tst_link_conditioner PRIVATE
    Qt6::Core
    Qt6::Test
)

add_test(NAME network_link_conditioner COMMAND tst_link_conditioner)
set_tests_properties(network_link_conditioner PROPERTIES LABELS "network;unit")

# The browser's twin of it, link_conditioner.js, against the same cases
clay_add_node_test(network_link_conditioner
    SCRIPT ${CMAKE_CURRENT_SOURCE_DIR}/link_conditioner.test.js)

# HTTP auth tests - drive ClayHttpClient against a local echo server and assert
# the headers that actually go out. ClayWebAccess is compiled in and registered
# by hand and the QML file is loaded from the source tree, so this needs
# neither the built plugin nor a QML import path (#85).
find_package(Qt6 REQUIRED COMPONENTS Gui Network Qml Quick)

add_executable(tst_http_auth
    tst_http_auth.cpp
    ${CMAKE_CURRENT_SOURCE_DIR}/../claywebaccess.cpp
)

set_target_properties(tst_http_auth PROPERTIES AUTOMOC ON)

target_include_directories(tst_http_auth PRIVATE ${CMAKE_CURRENT_SOURCE_DIR}/..)

target_compile_definitions(tst_http_auth PRIVATE
    CLAY_HTTP_CLIENT_QML="${CMAKE_CURRENT_SOURCE_DIR}/../ClayHttpClient.qml"
)

target_link_libraries(tst_http_auth PRIVATE
    Qt6::Core
    Qt6::Gui
    Qt6::Network
    Qt6::Qml
    Qt6::Quick
    Qt6::Test
)

add_test(NAME network_http_auth COMMAND tst_http_auth)
set_tests_properties(network_http_auth PROPERTIES
    LABELS "network;unit"
    ENVIRONMENT "QT_QPA_PLATFORM=offscreen"
)

# Net Gym - multi-instance state-sync integration test driven through the
# inspector protocol (needs the loader binary and Python). The loader target
# is defined after the plugins dir, so gate on the tools condition - the
# $<TARGET_FILE:...> genex resolves at generate time when it exists.
find_package(Python3 COMPONENTS Interpreter)
if(Python3_FOUND AND CLAYGROUND_WITH_TOOLS AND NOT (ANDROID OR IOS OR EMSCRIPTEN))
    add_test(NAME network_sync_gym
        COMMAND ${Python3_EXECUTABLE} ${CMAKE_CURRENT_SOURCE_DIR}/gym/run_net_gym.py
                --loader $<TARGET_FILE:clayliveloader>
    )
    set_tests_properties(network_sync_gym PROPERTIES
        LABELS "network;integration;gym"
        ENVIRONMENT "QT_QPA_PLATFORM=offscreen"
        TIMEOUT 180
    )
endif()

# Native Cloud signaling against an in-process PeerJS server: certificate
# check and its opt-out, the heartbeat that keeps a host joinable past the
# server's idle timeout, a dropped connection as signalingLost (#320). The
# backend is compiled in, so neither the plugin nor a QML engine is needed.
# The hold takes the full 120 s the issue asks for; CLAY_NET_HOLD_MS shortens
# it for a quick local run.
find_package(OpenSSL REQUIRED)

add_executable(tst_cloud_signaling
    tst_cloud_signaling.cpp
    ${CMAKE_CURRENT_SOURCE_DIR}/../claynetwork_native.cpp
    ${CMAKE_CURRENT_SOURCE_DIR}/../link_conditioner.cpp
    ${CMAKE_CURRENT_SOURCE_DIR}/../signaling_peerjs.cpp
    ${CMAKE_CURRENT_SOURCE_DIR}/../signaling_local.cpp
)

set_target_properties(tst_cloud_signaling PROPERTIES AUTOMOC ON)

target_include_directories(tst_cloud_signaling PRIVATE ${CMAKE_CURRENT_SOURCE_DIR}/..)

target_link_libraries(tst_cloud_signaling PRIVATE
    Qt6::Core
    Qt6::Network
    Qt6::Qml
    Qt6::Test
    LibDataChannel::LibDataChannel
    OpenSSL::Crypto
)

add_test(NAME network_cloud_signaling COMMAND tst_cloud_signaling)
set_tests_properties(network_cloud_signaling PROPERTIES
    LABELS "network;integration"
    TIMEOUT 300
)

# LAN signaling (#321): a taken id is refused, closed sockets are dropped
# after connect/close cycles, a malformed LAN code fails before it connects.
# Same compiled-in backend as tst_cloud_signaling.
add_executable(tst_local_signaling
    tst_local_signaling.cpp
    ${CMAKE_CURRENT_SOURCE_DIR}/../claynetwork_native.cpp
    ${CMAKE_CURRENT_SOURCE_DIR}/../link_conditioner.cpp
    ${CMAKE_CURRENT_SOURCE_DIR}/../signaling_peerjs.cpp
    ${CMAKE_CURRENT_SOURCE_DIR}/../signaling_local.cpp
)

set_target_properties(tst_local_signaling PROPERTIES AUTOMOC ON)

target_include_directories(tst_local_signaling PRIVATE ${CMAKE_CURRENT_SOURCE_DIR}/..)

target_link_libraries(tst_local_signaling PRIVATE
    Qt6::Core
    Qt6::Network
    Qt6::Qml
    Qt6::Test
    LibDataChannel::LibDataChannel
)

add_test(NAME network_local_signaling COMMAND tst_local_signaling)
set_tests_properties(network_local_signaling PROPERTIES
    LABELS "network;integration"
    TIMEOUT 120
)
