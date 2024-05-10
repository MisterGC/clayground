# (c) Clayground Contributors - MIT License, see "LICENSE" file
include(CMakeParseArguments)

##
# `clay_app` macro defines the necessary setup to configure and
#  build a Qt application named `CLAY_APP_NAME`.
#
# Arguments:
#   CLAY_APP_NAME - The name of the application. This will be used
#                   as the project name and the executable name.
#
# Options (to be passed with ARGN):
#   VERSION     - Specify the version of the application.
#   SOURCES     - List of source files for the application.
#   LINK_LIBS   - List of libraries to link against.
#   QML_FILES   - List of QML files to be included in the application.
#   RES_FILES   - List of resource files.
#   IOS_DIR     - Custom directory for iOS-specific files.
#   ANDROID_DIR - Custom directory for Android-specific files.
#
# Requirements:
#   Qt6 with components Core, Qml, and Quick.
#
# Example usage:
#   clay_app(MyApp
#       VERSION "1.0.0"
#       SOURCES main.cpp MyApp.cpp
#       LINK_LIBS MyLib
#       QML_FILES main.qml Component.qml
#       RES_FILES some_image.jpg
#       IOS_DIR "./ios"
#       ANDROID_DIR "./android"
#   )
#
# Notes:
#   - This macro configures a Qt executable with the given parameters and handles platform-specific adjustments.
#   - IOS and ANDROID blocks handle specific customizations for those platforms.
#   - The macro sets up a test target for non-mobile platforms.
##
macro(clay_app CLAY_APP_NAME)

    cmake_minimum_required(VERSION 3.16)
    project (${CLAY_APP_NAME} VERSION ${CLAY_APP_VERSION})

    # Argument Parsing
    set (oneValueArgs VERSION)
    set (multiValueArgs
            SOURCES
            LINK_LIBS
            QML_FILES
            RES_FILES
            IOS_DIR
            ANDROID_DIR
        )
    cmake_parse_arguments(CLAY_APP
                            "${options}"
                            "${oneValueArgs}"
                            "${multiValueArgs}"
                            ${ARGN})

    set(CMAKE_INCLUDE_CURRENT_DIR ON)
    set(CMAKE_AUTOUIC ON)
    set(CMAKE_AUTOMOC ON)
    set(CMAKE_AUTORCC ON)
    set(CMAKE_CXX_STANDARD_REQUIRED ON)

    # Default Qt dependencies for any clay app
    find_package(Qt6 REQUIRED COMPONENTS Core Qml Quick)

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

        if(NOT DEFINED CLAY_APP_IOS_DIR)
            set(CLAY_APP_IOS_DIR "${CLAY_APP_TEMPLATE_DIR}/ios")
        endif()

        message("clay_app: Target platform iOS with ios dir: ${CLAY_APP_IOS_DIR}")

        # Assets like app icon
        set(asset_catalog_path "${CLAY_APP_IOS_DIR}/Assets.xcassets")
        target_sources(${PROJECT_NAME} PRIVATE "${asset_catalog_path}")
        set_source_files_properties(${asset_catalog_path} PROPERTIES MACOSX_PACKAGE_LOCATION Resources)
        set_target_properties(${PROJECT_NAME}
            PROPERTIES XCODE_ATTRIBUTE_ASSETCATALOG_COMPILER_APPICON_NAME AppIcon)

    elseif(ANDROID) # FIXME so that it works with Qt6.6+

        if(NOT DEFINED CLAY_APP_ANDROID_DIR)
            set(CLAY_APP_ANDROID_DIR "${CLAY_APP_TEMPLATE_DIR}/android")
        endif()

        message("clay_app: Target platform Android with Android dir: ${CLAY_APP_ANDROID_DIR}")

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
