include (clayplugin)

clay_plugin( Character3D

    VERSION 1.0

    QML_FILES
        Sandbox.qml
        # Core Components
        Character.qml
        RatioBasedCharacter.qml
        CharacterCamera.qml
        CharacterController.qml
        # Body System
        BodyPart.qml
        BodyPartsGroup.qml
        Head.qml
        Arm.qml
        Leg.qml
        Hand.qml
        Foot.qml
        # Animation System
        ProceduralAnim.qml
        WalkAnim.qml
        IdleAnim.qml
        PosAnim.qml
        EulerAnim.qml
        PosAndEulerAnim.qml
        # Configuration UI
        #CharacterConfigGui.qml
        #ColorControl.qml
        #ThoughtBubble.qml
        # Examples
        #BasicCharacterExample.qml
        #AnimationShowcase.qml
        #CharacterCustomization.qml

    LINK_LIBS
        Qt::Core
        Qt::Quick
        Qt::Quick3D
        Qt::Qml
)
