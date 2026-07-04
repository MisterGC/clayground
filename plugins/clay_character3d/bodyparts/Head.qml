import QtQuick
import QtQuick3D
import Clayground.Canvas3D
import "../animation"

/*!
    \qmltype Head
    \inqmlmodule Clayground.Character3D
    \inherits BodyPartsGroup
    \brief A complete head with facial features and expressions.

    Head is a complex body part group containing upper head, lower head (jaw),
    hair, eyes, ears, nose, and mouth. It supports animated facial expressions
    including joy, anger, sadness, and talking.

    The mouth is driven by a small set of continuous shape parameters
    (\l mouthOpen, \l mouthWide, \l mouthRound, \l mouthCornerLift). The
    expression activities animate these parameters; a \l speechSource
    (typically a \l Speech instance) can take over open/wide/round for
    lip-synced talking while emotions keep control of the mouth corners.

    Example usage:
    \qml
    import Clayground.Character3D

    Head {
        skinColor: "#d38d5f"
        hairColor: "#734120"
        eyeColor: "#4a3728"
        hairVolume: 1.2
        activity: Head.Activity.ShowJoy
    }
    \endqml

    \sa Character, BodyPartsGroup, Speech
*/
BodyPartsGroup {
    id: _head

    /*!
        \qmlproperty color Head::skinColor
        \brief Color of the skin (face, ears, nose).
    */
    property color skinColor: "#d38d5f"

    /*!
        \qmlproperty color Head::hairColor
        \brief Color of the hair and eyebrows.
    */
    property color hairColor: "#734120"

    /*!
        \qmlproperty color Head::eyeColor
        \brief Color of the irises.
    */
    property color eyeColor: "#4a3728"

    // Don't set these properties directly as they
    // are derived from the head parts
    width: Math.max(upperHeadWidth, lowerHeadWidth)
    height: upperHeadHeight + lowerHeadHeight
    depth: Math.max(upperHeadDepth, lowerHeadDepth)

    /*!
        \qmlproperty real Head::upperHeadWidth
        \brief Width of the upper head (cranium).
    */
    property alias upperHeadWidth: _upperHead.width

    /*!
        \qmlproperty real Head::upperHeadHeight
        \brief Height of the upper head (cranium).
    */
    property alias upperHeadHeight: _upperHead.height

    /*!
        \qmlproperty real Head::upperHeadDepth
        \brief Depth of the upper head (cranium).
    */
    property alias upperHeadDepth: _upperHead.depth

    /*!
        \qmlproperty real Head::lowerHeadWidth
        \brief Width of the lower head (jaw).
    */
    property alias lowerHeadWidth: _lowerHead.width

    /*!
        \qmlproperty real Head::lowerHeadHeight
        \brief Height of the lower head (jaw).
    */
    property alias lowerHeadHeight: _lowerHead.height

    /*!
        \qmlproperty real Head::lowerHeadDepth
        \brief Depth of the lower head (jaw).
    */
    property alias lowerHeadDepth: _lowerHead.depth

    /*!
        \qmlproperty real Head::chinPointiness
        \brief How pointed the chin is (0-1).

        Controls the bottom face scaling of the jaw.
    */
    property alias chinPointiness: _lowerHead.chinPointiness

    /*!
        \qmlproperty real Head::eyeSize
        \brief Eye size multiplier (0.5 = small, 1.0 = normal, 1.5 = large).
    */
    property real eyeSize: 1.0

    /*!
        \qmlproperty real Head::noseSize
        \brief Nose size multiplier (0.5 = small, 1.0 = normal, 1.5 = large).
    */
    property real noseSize: 1.0

    /*!
        \qmlproperty real Head::mouthSize
        \brief Mouth size multiplier (0.5 = small, 1.0 = normal, 1.5 = large).
    */
    property real mouthSize: 1.0

    /*!
        \qmlproperty real Head::hairVolume
        \brief Hair volume multiplier (0 = bald, 1.0 = normal, 1.5 = voluminous).
    */
    property real hairVolume: 1.0

    /*!
        \qmlproperty int Head::toEmotionDuration
        \brief Duration of emotion transition animations in milliseconds.
    */
    property int toEmotionDuration: 1000

    /*!
        \qmlproperty int Head::talkDuration
        \brief Duration of mouth open/close cycle when talking in milliseconds.
    */
    property int talkDuration: 200

    // ============================================================================
    // MOUTH SHAPE PARAMETERS
    // ============================================================================

    /*!
        \qmlproperty real Head::mouthOpen
        \brief How far the mouth/jaw is opened (0 = closed, 1 = fully open).

        Driven by the Talk activity or a \l speechSource; can also be set
        manually for custom facial animation.
    */
    property real mouthOpen: speechActive ? speechSource.mouthOpen : _animMouthOpen

    /*!
        \qmlproperty real Head::mouthWide
        \brief How far the mouth is stretched sideways (0-1), e.g. for "ee" sounds.
    */
    property real mouthWide: speechActive ? speechSource.mouthWide : _animMouthWide

    /*!
        \qmlproperty real Head::mouthRound
        \brief How rounded/puckered the mouth is (0-1), e.g. for "oo" sounds.
    */
    property real mouthRound: speechActive ? speechSource.mouthRound : _animMouthRound

    /*!
        \qmlproperty real Head::mouthCornerLift
        \brief Mouth corner position from frown (-1) over neutral (0) to smile (1).

        Stays under emotion control even while a speechSource drives the
        other mouth parameters - characters can smile while talking.
    */
    property real mouthCornerLift: 0

    /*!
        \qmlproperty real Head::jawOpenAngle
        \brief Maximum jaw rotation in degrees when \l mouthOpen is 1.
    */
    property real jawOpenAngle: 9

    /*!
        \qmlproperty var Head::speechSource
        \brief Optional lip-sync driver, typically a \l Speech instance.

        While speechSource.speaking is true, its mouthOpen/mouthWide/mouthRound
        values control the mouth.
    */
    property var speechSource: null

    /*!
        \qmlproperty bool Head::speechActive
        \readonly
        \brief True while the speechSource is speaking and driving the mouth.
    */
    readonly property bool speechActive: speechSource !== null
                                         && speechSource !== undefined
                                         && speechSource.speaking === true

    // Values written by the activity animations; the public mouth params
    // fall back to these whenever no speechSource is driving the mouth.
    property real _animMouthOpen: 0
    property real _animMouthWide: 0
    property real _animMouthRound: 0

    /*!
        \qmlproperty enumeration Head::Activity
        \brief The current facial activity state.

        \value Head.Activity.Idle Neutral expression
        \value Head.Activity.ShowJoy Happy expression with smile
        \value Head.Activity.ShowAnger Angry expression with frown
        \value Head.Activity.ShowSadness Sad expression
        \value Head.Activity.Talk Animated talking mouth
    */
    enum Activity {
        ShowJoy,
        ShowAnger,
        ShowSadness,
        Talk,
        Idle
    }

    /*!
        \qmlproperty int Head::activity
        \brief Current facial expression activity.

        Use Head.Activity enum values.
    */
    property int activity: Head.Activity.Idle

    // property alias thoughts: _thoughtBubble.text
    // Node {
    //     id: _thoughts

    //     // TODO: Re-enable
    //     visible: false
    //     ThoughtBubble {
    //         id: _thoughtBubble
    //         anchors.horizontalCenter: parent.horizontalCenter
    //         anchors.bottom: parent.bottom
    //         text: "I'm thinking...\nblub\nblub"
    //     }
    //     y: _head.height * 1
    // }

    // Upper head part containing eyes and ears
    BodyPart {
        id: _upperHead

        // Default dimensions
        width: 1.0
        height: 0.8
        depth: 1.2

        showEdges: false

        basePos: Qt.vector3d(0, _lowerHead.height * 0.99, _head.depth * .09)
        color: _head.skinColor

        BodyPart {
            id: _topHair
            visible: _head.hairVolume > 0.1
            width: _upperHead.width * 1.1
            height: _upperHead.height * 0.5 * _head.hairVolume
            depth: _upperHead.depth * 1.1
            color: _head.hairColor
            basePos: Qt.vector3d(0,
                                 _upperHead.height * 0.8,
                                 0)
        }

        BodyPart {
            id: _backHair
            visible: _head.hairVolume > 0.1
            width: _upperHead.width * 1.1
            height: _upperHead.height * 1.5 * _head.hairVolume
            depth: _upperHead.depth * 0.3 * _head.hairVolume
            color: _head.hairColor
            basePos: Qt.vector3d(0,
                                 _upperHead.height - height,
                                 -0.5*_upperHead.depth)
        }

        BodyPart {
            id: _leftHair
            visible: _head.hairVolume > 0.1
            width: _upperHead.width * 0.2 * _head.hairVolume
            height: _upperHead.height * 1.3 * _head.hairVolume
            depth: _upperHead.depth * 1.1
            color: _head.hairColor
            basePos: Qt.vector3d(-_upperHead.width * 0.5,
                                 _upperHead.height - height,
                                 0)
        }

        BodyPart {
            id: _rightHair
            visible: _head.hairVolume > 0.1
            width: _upperHead.width * 0.2 * _head.hairVolume
            height: _upperHead.height * 1.3 * _head.hairVolume
            depth: _upperHead.depth * 1.1
            color: _head.hairColor
            basePos: Qt.vector3d(_upperHead.width * 0.5,
                                 _upperHead.height - height,
                                 0)
        }

        BodyPart {
            id: _nose
            color: _head.skinColor.darker(1.1)
            width: _upperHead.width * .15 * _head.noseSize
            height: _upperHead.height * .2 * _head.noseSize
            depth: _upperHead.depth * .2 * _head.noseSize
            basePos: Qt.vector3d(0,
                                 _leftEye.basePos.y - height * 1.1,
                                 _upperHead.depth * .5)
        }

        component Ear: BodyPart {
            color: _head.skinColor
            width: .25 * _upperHead.height; depth: 0.2 * _upperHead.depth
        }

        Ear {
            id: _leftEar
            basePos: Qt.vector3d(-0.55*_upperHead.width, _leftEye.basePos.y, 0)
        }

        Ear {
            id: _rightEar
            basePos: Qt.vector3d(-_leftEar.basePos.x,
                                  _leftEar.basePos.y,
                                  _leftEar.basePos.z)
        }

        component Eye: BodyPart {
            id: _eye
            color: "white"
            width: _upperHead.width * .22 * _head.eyeSize
            property BodyPart brow: _brow
            property alias browEuler: _brow.eulerRotation
            BodyPart {
                color: _head.eyeColor
                width: 0.33 * _eye.width
                basePos: Qt.vector3d(0, 0.2 * _eye.height, _eye.depth * .5)
            }
            BodyPart {
                id: _brow
                color: _head.hairColor
                width: 1.2 * _eye.width
                height: .33 * _eye.height
                depth: _eye.depth
                basePos: Qt.vector3d(0, 0.8*_eye.height, 0.1)
            }
        }

        Eye {
            id: _leftEye
            basePos: Qt.vector3d(-_leftEye.width, .3 * _upperHead.height, _upperHead.depth * .5)
        }

        Eye {
            id: _rightEye
            basePos: Qt.vector3d(-_leftEye.basePos.x, _leftEye.basePos.y, _leftEye.basePos.z)
        }
    }

    // Jaw joint: the lower head hinges here (top/back of the jaw, roughly
    // between the ears) so the chin swings down and back when the mouth opens.
    Node {
        id: _jawJoint
        position: Qt.vector3d(0,
                              _lowerHead.height,
                              _head.depth * .09 - _lowerHead.depth * 0.35)
        eulerRotation.x: _head.mouthOpen * _head.jawOpenAngle

        // Lower head part containing mouth and chin
        BodyPart {
            id: _lowerHead

            // Default dimensions
            width: 1.0
            height: 0.5
            depth: 1.2
            showEdges: true
            edgeMask: bottomEdges | leftEdges | rightEdges | frontEdges | backEdges

            property real chinPointiness: 1.0

            // Compensates the joint offset so the jaw sits exactly where it
            // would as a direct child (see _jawJoint.position).
            basePos: Qt.vector3d(0, -height, _lowerHead.depth * 0.35)
            color: _head.skinColor

            // Apply chin pointiness using scaled bottom face
            scaledFace: Box3DGeometry.BottomFace
            faceScale: Qt.vector2d(chinPointiness, 1.0)

            // Mouth on the front of the jaw, built from the continuous
            // shape parameters (open/wide/round/cornerLift).
            Node {
                id: _mouth
                position: Qt.vector3d(0, 0.6 * _lowerHead.height, _lowerHead.depth * .5)

                readonly property real baseW: _lowerHead.width * .22 * _head.mouthSize
                readonly property real lineH: .3 * baseW
                // widened by "ee", narrowed by "oo"
                readonly property real w: baseW * (1 + 0.5 * _head.mouthWide)
                                                * (1 - 0.4 * _head.mouthRound)
                // gap the mouth opens up (in addition to the jaw rotation)
                readonly property real gap: _head.mouthOpen * _lowerHead.height * 0.45

                // Dark mouth cavity; top edge stays at the mouth line, the
                // bottom grows downward as the mouth opens.
                BodyPart {
                    id: _mouthCavity
                    color: "#20100c"
                    width: _mouth.w
                    height: _mouth.lineH + _mouth.gap
                    depth: 0.1
                    showEdges: false
                    castsShadows: false
                    basePos: Qt.vector3d(0, -height, _head.mouthRound * 0.05)
                }

                // Lip line covering the cavity's top edge (keeps the closed
                // mouth reading as a clean line).
                BodyPart {
                    id: _upperLip
                    color: "black"
                    width: _mouth.w * 1.02
                    height: _mouth.lineH * 0.4
                    depth: 0.11
                    showEdges: false
                    castsShadows: false
                    basePos: Qt.vector3d(0, -height * 0.5, 0)
                }

                // Mouth corners: lifted for smiles, dropped for frowns.
                component MouthCorner: BodyPart {
                    color: "black"
                    width: _mouth.lineH
                    showEdges: false
                    castsShadows: false
                }
                MouthCorner {
                    id: _mouthLeft
                    basePos: Qt.vector3d(-0.5 * (_mouth.w + width),
                                         -0.5 * width + _head.mouthCornerLift * 0.5 * _mouth.baseW,
                                         0)
                }
                MouthCorner {
                    id: _mouthRight
                    basePos: Qt.vector3d(0.5 * (_mouth.w + width),
                                         -0.5 * width + _head.mouthCornerLift * 0.5 * _mouth.baseW,
                                         0)
                }
            }
        }
    }

    // ACTIVITY ANIMATIONS
    //
    // Emotions animate the mouth parameters and eyebrows. While a
    // speechSource is active it overrides open/wide/round (see the
    // property bindings above); corner lift stays with the emotions.

    component MouthParamAnim: NumberAnimation {
        target: _head
        duration: _head.toEmotionDuration
        easing.type: Easing.InOutQuad
    }

    ParallelAnimation {
        id: _sadnessAnimation
        running: _head.activity == Head.Activity.ShowSadness
        MouthParamAnim { property: "mouthCornerLift"; to: -0.8 }
        MouthParamAnim { property: "_animMouthOpen"; to: 0 }
        MouthParamAnim { property: "_animMouthWide"; to: 0 }
        MouthParamAnim { property: "_animMouthRound"; to: 0 }
        RaiseEyeBrowns {}
    }

    ParallelAnimation {
        id: _joyAnimation
        running: _head.activity == Head.Activity.ShowJoy
        MouthParamAnim { property: "mouthCornerLift"; to: 0.8 }
        MouthParamAnim { property: "_animMouthOpen"; to: 0.1 }
        MouthParamAnim { property: "_animMouthWide"; to: 0.4 }
        MouthParamAnim { property: "_animMouthRound"; to: 0 }
        RaiseEyeBrowns {}
    }

    ParallelAnimation {
        id: _angerAnimation
        running: _head.activity == Head.Activity.ShowAnger
        MouthParamAnim { property: "mouthCornerLift"; to: -0.7 }
        MouthParamAnim { property: "_animMouthOpen"; to: 0.15 }
        MouthParamAnim { property: "_animMouthWide"; to: 0.3 }
        MouthParamAnim { property: "_animMouthRound"; to: 0 }
        LowerEyeBrowns {}
    }

    SequentialAnimation {
        id: _talkAnimation
        running: _head.activity == Head.Activity.Talk && !_head.speechActive
        loops: Animation.Infinite
        ParallelAnimation {
            MouthParamAnim { property: "_animMouthOpen"; to: 0.65; duration: _head.talkDuration }
            MouthParamAnim { property: "_animMouthWide"; to: 0.25; duration: _head.talkDuration }
        }
        ParallelAnimation {
            MouthParamAnim { property: "_animMouthOpen"; to: 0.08; duration: _head.talkDuration }
            MouthParamAnim { property: "_animMouthWide"; to: 0.1; duration: _head.talkDuration }
        }
    }

    ParallelAnimation {
        id: _idleAnimation
        running: _head.activity == Head.Activity.Idle
        MouthParamAnim { property: "mouthCornerLift"; to: 0 }
        MouthParamAnim { property: "_animMouthOpen"; to: 0 }
        MouthParamAnim { property: "_animMouthWide"; to: 0 }
        MouthParamAnim { property: "_animMouthRound"; to: 0 }
        NeutralEyeBrowns {}
    }

    // ANIMATION BUILDING BLOCKS (eyebrows)

    component LowerEyeBrowns: ParallelAnimation {
        id: _lowerEyeBrowns
        property int duration: _head.toEmotionDuration
        PosAndEulerAnim {
            duration: _lowerEyeBrowns.duration
            target: _leftEye.brow
            toEuler: Qt.vector3d(0,0,-25)
            toPos: Qt.vector3d(.5 * target.basePos.x,
                               target.basePos.y,
                               target.basePos.z)
        }
        PosAndEulerAnim {
            duration: _lowerEyeBrowns.duration
            target: _rightEye.brow
            toEuler: Qt.vector3d(0,0,25)
            toPos: Qt.vector3d(.5 * target.basePos.x,
                               target.basePos.y,
                               target.basePos.z)
        }
    }

    component RaiseEyeBrowns: ParallelAnimation {
        id: _raiseEyeBrowns
        property int duration: _head.toEmotionDuration

        PosAndEulerAnim {
            duration: _raiseEyeBrowns.duration
            target: _leftEye.brow
            toEuler: Qt.vector3d(0,0,5)
            toPos: Qt.vector3d(target.basePos.x,
                               target.basePos.y + target.height,
                               target.basePos.z)
        }
        PosAndEulerAnim {
            duration: _raiseEyeBrowns.duration
            target: _rightEye.brow
            toEuler: Qt.vector3d(0,0,-5)
            toPos: Qt.vector3d(target.basePos.x,
                               target.basePos.y + target.height,
                               target.basePos.z)
        }
    }

    component NeutralEyeBrowns: ParallelAnimation {
        id: _neutralEyeBrowns
        property int duration: _head.toEmotionDuration
        PosAndEulerAnim {
            duration: _neutralEyeBrowns.duration
            target: _leftEye.brow
            toEuler: target.baseEuler
            toPos: target.basePos
        }
        PosAndEulerAnim {
            duration: _neutralEyeBrowns.duration
            target: _rightEye.brow
            toEuler: target.baseEuler
            toPos: target.basePos
        }
    }

}
