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
