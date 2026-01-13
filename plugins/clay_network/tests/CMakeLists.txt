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
