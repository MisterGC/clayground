# (c) Clayground Contributors - MIT License, see "LICENSE" file
#
# Unit tests for clay_network plugin

find_package(Qt6 REQUIRED COMPONENTS Test)

# Serialization tests (no network required)
add_executable(tst_network_serialization
    tst_network_serialization.cpp
)

set_target_properties(tst_network_serialization PROPERTIES AUTOMOC ON)

target_link_libraries(tst_network_serialization PRIVATE
    Qt6::Core
    Qt6::Test
)

add_test(NAME network_serialization COMMAND tst_network_serialization)
set_tests_properties(network_serialization PROPERTIES LABELS "network;unit")

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
