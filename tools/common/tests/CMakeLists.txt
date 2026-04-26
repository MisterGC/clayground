# (c) Clayground Contributors - MIT License, see "LICENSE" file
#
# Tests for tools/common utilities

find_package(Qt6 REQUIRED COMPONENTS Core Test)

add_executable(tst_dojoignore tst_dojoignore.cpp)
set_target_properties(tst_dojoignore PROPERTIES AUTOMOC ON)
target_link_libraries(tst_dojoignore PRIVATE
    claytoolscommon
    Qt6::Core
    Qt6::Test
)
add_test(NAME dojoignore_unit COMMAND tst_dojoignore)
set_tests_properties(dojoignore_unit PROPERTIES LABELS "dojo;unit")
