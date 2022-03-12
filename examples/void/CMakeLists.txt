# (c) Clayground Contributors - MIT License, see "LICENSE" file
include (clayexample)
clay_example( sbx_void
    VERSION 1.0
    SOURCES main.cpp res.qrc
    #QML_FILES res.qrc
)


#    project (sbx_void VERSION 1.0)

#    set(CMAKE_INCLUDE_CURRENT_DIR ON)

#    set(CMAKE_AUTOUIC ON)
#    set(CMAKE_AUTOMOC ON)
#    set(CMAKE_AUTORCC ON)

#    set(CMAKE_CXX_STANDARD_REQUIRED ON)

#    find_package(Qt6 REQUIRED COMPONENTS Core Quick)

#    configure_file(${CMAKE_SOURCE_DIR}/cmake/main_example.cpp.in main.cpp)
#    qt_add_executable(${PROJECT_NAME} MANUAL_FINALIZATION ${CMAKE_CURRENT_BINARY_DIR}/main.cpp )

#    qt_add_qml_module(${PROJECT_NAME}
#        URI ${PROJECT_NAME}
#        VERSION  1.0
#        QML_FILES main.qml Sandbox.qml
#        RESOURCES ${CLAYEXAMPLE_RES_FILES}
#    )

#    target_compile_definitions(${PROJECT_NAME}
#        PRIVATE $<$<OR:$<CONFIG:Debug>,$<CONFIG:RelWithDebInfo>>:QT_QML_DEBUG>)
#    target_compile_features(${PROJECT_NAME} PUBLIC cxx_std_17)

#    target_link_libraries(${PROJECT_NAME} PRIVATE Qt::Core Qt::Quick)
#    qt_import_qml_plugins(${PROJECT_NAME})
#    qt_finalize_executable(${PROJECT_NAME})
