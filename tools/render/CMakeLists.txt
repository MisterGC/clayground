cmake_minimum_required(VERSION 3.16)
project(clayrender LANGUAGES CXX)

# One sandbox, one picture, no session (issue #164). Deliberately not a mode of
# clayliveloader: that one is a widget application with overlays, shortcuts and
# a supervisor, none of which a one-shot render wants.
if(EMSCRIPTEN)
    message(STATUS "clayrender: skipping (native tool)")
    return()
endif()

set(CMAKE_INCLUDE_CURRENT_DIR ON)
set(CMAKE_AUTOMOC ON)
# GuiPrivate: QRhi is where the offscreen render target lives.
find_package(Qt6 REQUIRED COMPONENTS Core Gui GuiPrivate Qml Quick)

add_executable(${PROJECT_NAME}
    main.cpp
    renderhost.cpp
    renderhost.h
)

target_compile_features(${PROJECT_NAME} PUBLIC cxx_std_17)
target_compile_definitions(${PROJECT_NAME}
    PRIVATE CLAY_RENDER_VERSION="${CLAYGROUND_PROJECT_VERSION}")

target_link_libraries(${PROJECT_NAME}
PRIVATE
  clayscene
  Qt::Core
  Qt::Gui
  Qt::GuiPrivate
  Qt::Qml
  Qt::Quick
)

if(BUILD_TESTING)
    find_package(Python3 COMPONENTS Interpreter)
    if(Python3_FOUND)
        add_test(NAME clayrender
            COMMAND ${Python3_EXECUTABLE}
                    ${CMAKE_CURRENT_SOURCE_DIR}/tests/run_render_tests.py
                    --clayrender $<TARGET_FILE:clayrender>)
        # Needs a GPU session; the script reports 77 when it cannot get one.
        set_tests_properties(clayrender PROPERTIES
            LABELS "render;integration"
            SKIP_RETURN_CODE 77
            TIMEOUT 180)
    endif()
endif()
