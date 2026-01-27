include (clayplugin)

clay_plugin( Character3D

    VERSION 1.0

    QML_FILES
        # Core Components
        Character.qml
        CharacterEditor.qml
        ParametricCharacter.qml
        RatioBasedCharacter.qml
        ThoughtBubble.qml
        
        # Body System
        bodyparts/BodyPart.qml
        bodyparts/BodyPartsGroup.qml
        bodyparts/Head.qml
        bodyparts/Arm.qml
        bodyparts/Leg.qml
        bodyparts/Hand.qml
        bodyparts/Foot.qml
        
        # Animation System
        animation/ProceduralAnim.qml
        animation/WalkAnim.qml
        animation/RunAnim.qml
        animation/IdleAnim.qml
        animation/UseAnim.qml
        animation/FightAnim.qml
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
)
