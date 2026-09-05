include (clayplugin)
include (clayshader)

# The face material. Its own MAIN() draws eyes and mouths; the outline and the
# lighting come from Canvas3D's parts, so a head is bordered and lit by exactly
# the code every other body part is bordered and lit by rather than by a copy
# of it that will drift. Edit face3d_main.glsl, never the generated .frag.
clay_compose_shader(face3d.frag
    PARTS
        ${CLAY_SHADER_PARTS_DIR}/box3d_edges.glsl
        face3d_main.glsl
        ${CLAY_SHADER_PARTS_DIR}/box3d_toon.glsl
)

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
        src/visemeanalysis.cpp src/visemeanalysis.h
        src/visemetimeline.h

    RESOURCES
        ${face3d_SHADER}
        face3d.vert

    QML_FILES
        # Core Components
        Character.qml
        Gait.qml
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
        bodyparts/FaceBox.qml
        bodyparts/Arm.qml
        bodyparts/Leg.qml
        bodyparts/Hand.qml
        bodyparts/DetailedHand.qml
        bodyparts/Foot.qml

        # Animation System
        animation/ProceduralAnim.qml
        animation/gait.js
        animation/GaitCycleAnim.qml
        animation/WalkAnim.qml
        animation/RunAnim.qml
        animation/IdleAnim.qml
        animation/UseAnim.qml
        animation/FightAnim.qml
        animation/TalkGestureAnim.qml
        animation/GestureAnim.qml
        animation/GazeAnim.qml
        animation/ListenAnim.qml
        animation/PosAnim.qml
        animation/EulerAnim.qml
        animation/HeadEulerAnim.qml
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

# The gait model is Qt-free on purpose, so node checks in a second that the
# all-neutral gait is the legacy walk and run to the digit - the one claim a
# screenshot cannot make.
clay_add_node_test(character3d_gait SCRIPT ${CMAKE_CURRENT_SOURCE_DIR}/animation/gait.test.js)

# Behaviour suites. GazeAnim and ListenAnim ask their head and speaker for a
# handful of properties and nothing else, so they are tested against stubs -
# no built module, no window, no GPU, and it runs on Windows, where a suite
# that needs the built module cannot (#192).
clay_add_qml_test(character3d_qml DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR}/tests/qml)

# The head itself needs Canvas3D's C++ Box3DGeometry, so this half loads the
# built module and is the half Windows has to skip.
# tst_headpose.qml and tst_torso.qml both live here: a Head and a Character
# are made of Box3D, whose geometry is C++ in Canvas3D.
clay_add_qml_test(character3d_head_qml IMPORTS_BUILT_MODULE
                  DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR}/tests/qml_head)

if(NOT EMSCRIPTEN)
    add_subdirectory(tests)
endif()
