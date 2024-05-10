# (c) Clayground Contributors - MIT License, see "LICENSE" file
include(CMakeParseArguments)

macro(clay_app CLAY_APP_NAME)

    set (oneValueArgs VERSION)
    set (multiValueArgs SOURCES LINK_LIBS QML_FILES RES_FILES)
    cmake_parse_arguments(CLAY_APP "${options}" "${oneValueArgs}" "${multiValueArgs}" ${ARGN})

    cmake_minimum_required(VERSION 3.16)
    project (${CLAY_APP_NAME} VERSION ${CLAY_APP_VERSION})

    set(CMAKE_INCLUDE_CURRENT_DIR ON)
    set(CMAKE_AUTOUIC ON)
    set(CMAKE_AUTOMOC ON)
    set(CMAKE_AUTORCC ON)
    set(CMAKE_CXX_STANDARD_REQUIRED ON)

    find_package(Qt6 REQUIRED COMPONENTS Core5Compat Core Qml Quick Multimedia Sql)

    set(CLAY_APP_TEMPLATE_DIR ${CLAY_CMAKE_SCRIPT_DIR}/clay_app)
    set(CLAYGROUND_IMPORT_PLUGINS $CACHE{CLAYGROUND_IMPORT_PLUGINS})
    if(${CLAYGROUND_IMPORT_PLUGINS})
        string(REPLACE " " "\n" CLAYGROUND_IMPORT_PLUGINS ${CLAYGROUND_IMPORT_PLUGINS})
    endif()

    set(CLAY_APP_NAME ${CLAY_APP_NAME})
    configure_file(${CLAY_APP_TEMPLATE_DIR}/main.cpp.in main.cpp)
    qt_add_executable(${PROJECT_NAME} WIN32 MACOSX_BUNDLE
        ${CMAKE_CURRENT_BINARY_DIR}/main.cpp
        ${CLAY_APP_SOURCES} )

    # Define the default resource path if not provided
    if(NOT DEFINED CLAY_APP_IOS_RESOURCE_DIR)
        set(CLAY_APP_IOS_RESOURCE_DIR "${CLAY_APP_TEMPLATE_DIR}/ios")
    endif()
    if(NOT DEFINED CLAY_APP_ANDROID_RESOURCE_DIR)
        set(CLAY_APP_ANDROID_RESOURCE_DIR "${CLAY_APP_TEMPLATE_DIR}/android")
    endif()

    target_compile_definitions(${PROJECT_NAME}
        PRIVATE
            $<$<OR:$<CONFIG:Debug>,$<CONFIG:RelWithDebInfo>>:QT_QML_DEBUG>
            $<$<STREQUAL:"${CLAYPLUGIN_LINKING}","STATIC">:CLAYPLUGIN_LINKING_STATIC>
    )
    target_compile_features(${PROJECT_NAME} PUBLIC cxx_std_17)
    target_link_libraries(${PROJECT_NAME}
        PRIVATE
            Qt6::Core
            Qt6::Qml
            Qt6::Quick
            ${CLAY_APP_LINK_LIBS}
            $CACHE{CLAYGROUND_STATIC_PLUGINS})

    qt6_policy(SET QTP0001 NEW)
    qt_add_qml_module(${PROJECT_NAME}
        URI ${PROJECT_NAME}
        RESOURCE_PREFIX /
        NO_RESOURCE_TARGET_PATH
        VERSION   ${CLAY_APP_VERSION}
        QML_FILES ${CLAY_APP_QML_FILES}
        RESOURCES ${CLAY_APP_RES_FILES}
    )

    if (IOS)
        set(asset_catalog_path "${CLAY_APP_TEMPLATE_DIR}/ios/Assets.xcassets")
        target_sources(${PROJECT_NAME} PRIVATE "${asset_catalog_path}")
        set_source_files_properties(${asset_catalog_path} PROPERTIES MACOSX_PACKAGE_LOCATION Resources)
        set_target_properties(${PROJECT_NAME}
            PROPERTIES XCODE_ATTRIBUTE_ASSETCATALOG_COMPILER_APPICON_NAME AppIcon)
    elseif(ANDROID) # FIXME so that it works with Qt6.6+
        set(CLAY_APP_TARGET "${PROJECT_NAME}")
        set(CLAY_APP_VERSION "${CLAY_APP_VERSION}")
        set(android_templ_dir ${CLAY_APP_TEMPLATE_DIR}/android)
        configure_file(${android_templ_dir}/android_manifest.xml.in android/AndroidManifest.xml)
        if (NOT CLAY_ANDROID_BUILD_TOOLS_VERSION STREQUAL "DO_NOT_USE")
            configure_file(${android_templ_dir}/gradle.properties.in android/gradle.properties)
        endif()
        file(COPY ${android_templ_dir}/res DESTINATION android)
        set_target_properties(${PROJECT_NAME} PROPERTIES
            QT_ANDROID_PACKAGE_SOURCE_DIR ${CMAKE_CURRENT_BINARY_DIR}/android)
    else() # Desktop targets (and WASM!?)
        add_test(NAME test${PROJECT_NAME} COMMAND ${PROJECT_NAME})
        set_tests_properties(test${PROJECT_NAME} PROPERTIES
            ENVIRONMENT "QSG_INFO=1;QT_OPENGL=software;QT_QPA_PLATFORM=minimal")
    endif()

    qt_import_qml_plugins(${PROJECT_NAME})
endmacro()
