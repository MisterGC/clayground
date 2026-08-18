include (clayplugin)

# Text-to-speech is optional: when the Qt module is available, spoken text
# gets real audio; otherwise Speech falls back to silent, timed lip-sync.
find_package(Qt6 COMPONENTS TextToSpeech QUIET)

set(SPEECH_LIBS Qt::Multimedia)
if(Qt6TextToSpeech_FOUND)
    list(APPEND SPEECH_LIBS Qt::TextToSpeech)
endif()

clay_plugin( Character3D

    VERSION 1.0

    SOURCES
        src/speech.cpp src/speech.h

    QML_FILES
        # Core Components
        Character.qml
        CharacterEditor.qml
        ParametricCharacter.qml
        RatioBasedCharacter.qml
        ThoughtBubble.qml
        Performance.qml

        # Performance Scripting
        scripting/performancescript.js

        # Body System
        bodyparts/BodyPart.qml
        bodyparts/BodyPartsGroup.qml
        bodyparts/Head.qml
        bodyparts/Arm.qml
        bodyparts/Leg.qml
        bodyparts/Hand.qml
        bodyparts/DetailedHand.qml
        bodyparts/Foot.qml

        # Animation System
        animation/ProceduralAnim.qml
        animation/WalkAnim.qml
        animation/RunAnim.qml
        animation/IdleAnim.qml
        animation/UseAnim.qml
        animation/FightAnim.qml
        animation/TalkGestureAnim.qml
        animation/GestureAnim.qml
        animation/PosAnim.qml
        animation/EulerAnim.qml
        animation/PosAndEulerAnim.qml

        # Control System
        control/CharacterCamera.qml
        control/CharacterController.qml
        control/PatrolController.qml

    LINK_LIBS
        Qt::Core
        Qt::Quick
        Qt::Quick3D
        Qt::Qml
        ${SPEECH_LIBS}
)

target_include_directories(ClayCharacter3D PRIVATE ${CMAKE_CURRENT_SOURCE_DIR}/src)

if(Qt6TextToSpeech_FOUND)
    target_compile_definitions(ClayCharacter3D PRIVATE CLAY_CHARACTER3D_HAS_TTS)
endif()

if(NOT EMSCRIPTEN)
    add_subdirectory(tests)
endif()
