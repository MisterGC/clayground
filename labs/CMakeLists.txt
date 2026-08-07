# (c) Clayground Contributors - MIT License, see "LICENSE" file

# labs/ builds nothing - a lab is QML and Markdown, loaded by the dojo or the
# web runtime, never compiled. This file exists so the kits' pure-JS suites
# reach CTest: each kit's model code is deliberately Qt-free (`.pragma
# library`) so it can be verified in a second by node, and until #199 nothing
# turned a failing assertion red.
include(claytest)

clay_add_node_test(kit_circuit
    SCRIPT ${CMAKE_CURRENT_SOURCE_DIR}/kits/circuit/circuit.test.js)
clay_add_node_test(kit_traffic
    SCRIPT ${CMAKE_CURRENT_SOURCE_DIR}/kits/traffic/traffic.test.js)
clay_add_node_test(kit_sensor
    SCRIPT ${CMAKE_CURRENT_SOURCE_DIR}/kits/sensor/sensor.test.js)
