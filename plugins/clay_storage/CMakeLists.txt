include (clayplugin)

clay_plugin( Storage

    VERSION 1.0

    SOURCES
        storagesync.cpp
        storagesync.h

    QML_FILES KeyValueStore.qml

    LINK_LIBS
        Qt::Core
        Qt::Quick
        Qt::Qml
)

# On the web the files a KeyValueStore writes live in memory: the pre-js keeps
# them in IndexedDB instead, so they survive a page reload (#341). INTERFACE,
# because these are options of the final link - every app that links this
# plugin, not the plugin's own static library.
if(EMSCRIPTEN)
    set(_clay_storage_prejs ${CMAKE_CURRENT_SOURCE_DIR}/wasm/persist.pre.js)
    target_link_options(ClayStorage INTERFACE
        "-lidbfs.js"
        "SHELL:--pre-js ${_clay_storage_prejs}")
    # The pre-js is no input of any build step, so editing it would relink
    # nothing; rebuilding this plugin's library makes every app relink.
    set_source_files_properties(storagesync.cpp PROPERTIES
        OBJECT_DEPENDS ${_clay_storage_prejs})
endif()

include(claytest)
# IMPORTS_BUILT_MODULE: StorageSync is C++, so the suite loads the built
# module from bin/qml (#192).
clay_add_qml_test(storage_qml IMPORTS_BUILT_MODULE
    DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR}/tests/qml)
