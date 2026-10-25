# (c) Clayground Contributors - MIT License, see "LICENSE" file
include (clayplugin)
include (claybuildcache)

# Physical pads are read through SDL3 on the desktop and on iOS. The browser
# has a Gamepad API of its own and Android would need SDL's Java side, so
# those builds take no SDL. Without a backend GameController still works with
# keyboard, touch and the Dojo, and reports no gamepads.
if(EMSCRIPTEN OR ANDROID)
    set(_clay_gamepad_sdl_default OFF)
else()
    set(_clay_gamepad_sdl_default ON)
endif()
option(CLAY_GAMEPAD_SDL "GameController reads physical gamepads through SDL3"
    ${_clay_gamepad_sdl_default})

set(GAMEPAD_SOURCES
    gamepadbackend.h
    gamepadhub.cpp
    gamepadhub.h
)
set(GAMEPAD_LIBS)

if(CLAY_GAMEPAD_SDL)
    # Only the gamepad part of SDL, linked statically: no window, video,
    # audio or rendering - Qt owns all of those. HIDAPI stays, it carries the
    # drivers for the Steam Deck, PlayStation and Switch pads and the virtual
    # pads the tests plug in.
    set(SDL_SHARED OFF CACHE BOOL "" FORCE)
    set(SDL_STATIC ON CACHE BOOL "" FORCE)
    set(SDL_TEST_LIBRARY OFF CACHE BOOL "" FORCE)
    set(SDL_TESTS OFF CACHE BOOL "" FORCE)
    set(SDL_EXAMPLES OFF CACHE BOOL "" FORCE)
    set(SDL_INSTALL OFF CACHE BOOL "" FORCE)
    set(SDL_UNINSTALL OFF CACHE BOOL "" FORCE)
    foreach(_sdl_off AUDIO VIDEO GPU RENDER CAMERA HAPTIC POWER SENSOR DIALOG TRAY DBUS IBUS)
        set(SDL_${_sdl_off} OFF CACHE BOOL "" FORCE)
    endforeach()
    # On iOS the pads come through Apple's GameController framework (MFi,
    # Xbox, PlayStation, Switch Pro). HIDAPI would add only the Steam
    # Controller over Bluetooth, and it links CoreBluetooth, for which App
    # Store review wants a Bluetooth usage text in every app's Info.plist.
    # Without HIDAPI SDL has no virtual pads there; the tests run on desktop.
    if(IOS)
        set(SDL_HIDAPI OFF CACHE BOOL "" FORCE)
    endif()
    # The static library ends up inside the shared plugin
    set(CMAKE_POSITION_INDEPENDENT_CODE ON)

    clay_fetch(SDL3
        GIT_REPOSITORY https://github.com/libsdl-org/SDL
        GIT_TAG release-3.4.18
        GIT_SHALLOW TRUE
    )

    list(APPEND GAMEPAD_SOURCES
        gamepadbackend_sdl.cpp
        gamepadbackend_sdl.h
    )
    list(APPEND GAMEPAD_LIBS SDL3::SDL3-static)
endif()

clay_plugin( GameController

    VERSION 1.0

    SOURCES
            ${GAMEPAD_SOURCES}

    QML_FILES
            GameController.qml
            GameControllerDV.qml
            InputAction.qml
            KeyboardGamepad.qml
            PhysicalGamepad.qml
            SyntheticGamepad.qml
            TouchscreenGamepad.qml

    LINK_LIBS
        Qt::Core
        Qt::Quick
        Qt::Qml
        ${GAMEPAD_LIBS}
)

if(CLAY_GAMEPAD_SDL)
    target_compile_definitions(ClayGameController PRIVATE CLAY_GAMEPAD_SDL)
endif()

include(claytest)
clay_add_qml_test(gamecontroller_qml IMPORTS_BUILT_MODULE
    DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR}/tests/qml)
