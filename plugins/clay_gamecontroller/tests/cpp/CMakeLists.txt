# (c) Clayground Contributors - MIT License, see "LICENSE" file
#
# The browser backend reads navigator.getGamepads() only on WASM; everywhere
# else its sample() is empty, so a test can override it with the slots a
# browser would return and check what the backend makes of them.

find_package(Qt6 REQUIRED COMPONENTS Core Test)

add_executable(tst_gamepad_browser
    tst_gamepad_browser.cpp
    ../../gamepadbackend.h
    ../../gamepadbackend_browser.cpp
    ../../gamepadbackend_browser.h
)
set_target_properties(tst_gamepad_browser PROPERTIES AUTOMOC ON)
target_include_directories(tst_gamepad_browser PRIVATE ${CMAKE_CURRENT_SOURCE_DIR}/../..)
target_link_libraries(tst_gamepad_browser PRIVATE Qt6::Core Qt6::Test)

add_test(NAME gamecontroller_browser COMMAND tst_gamepad_browser)
