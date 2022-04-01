# (c) Clayground Contributors - MIT License, see "LICENSE" file
include (clayexample)
clay_example (sbx_plugin
    VERSION 1.0
    SOURCES main.cpp res.qrc
)
add_subdirectory (plugin)
