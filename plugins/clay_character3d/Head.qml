import QtQuick
import QtQuick3D

import Clayground.Canvas3D

//pragma ComponentBehavior: Bound

BodyPartsGroup {
    id: _head

    property color skinColor: "#d38d5f"
    property color hairColor: "#734120"

    // Don't set these properties directly as they
    // are derived from the head parts
    width: Math.max(upperHeadWidth, lowerHeadWidth)
    height: upperHeadHeight + lowerHeadHeight
    depth: Math.max(upperHeadDepth, lowerHeadDepth)

    // Upper Head Properties with defaults
    property alias upperHeadWidth: _upperHead.width
    property alias upperHeadHeight: _upperHead.height
    property alias upperHeadDepth: _upperHead.depth

    // Lower Head Properties with defaults
    property alias lowerHeadWidth: _lowerHead.width
    property alias lowerHeadHeight: _lowerHead.height
    property alias lowerHeadDepth: _lowerHead.depth
    property alias chinPointiness: _lowerHead.chinPointiness

    property int toEmotionDuration: 1000
    property int talkDuration: 200

    enum Activity {
        ShowJoy,
        ShowAnger,
        ShowSadness,
        Talk,
        Idle
    }
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
            width: _upperHead.width * 1.1
            height: _upperHead.height * 0.5
            depth: _upperHead.depth * 1.1
            color: _head.hairColor
            basePos: Qt.vector3d(0,
                                 _upperHead.height * 0.8,
                                 0)
        }

        BodyPart {
            id: _backHair
            width: _upperHead.width * 1.1
            height: _upperHead.height * 1.5
            depth: _upperHead.depth * 0.3
            color: _head.hairColor
            basePos: Qt.vector3d(0,
                                 _upperHead.height - height,
                                 -0.5*_upperHead.depth)
        }

        BodyPart {
            id: _leftHair
            width: _upperHead.width * 0.2
            height: _upperHead.height * 1.3
            depth: _upperHead.depth * 1.1
            color: _head.hairColor
            basePos: Qt.vector3d(-_upperHead.width * 0.5,
                                 _upperHead.height - height,
                                 0)
        }

        BodyPart {
            id: _rightHair
            width: _upperHead.width * 0.2
            height: _upperHead.height * 1.3
            depth: _upperHead.depth * 1.1
            color: _head.hairColor
            basePos: Qt.vector3d(_upperHead.width * 0.5,
                                 _upperHead.height - height,
                                 0)
        }

        BodyPart {
            id: _nose
            color: _head.skinColor.darker(1.1)
            width: _upperHead.width * .15
            height: _upperHead.height * .2
            depth: _upperHead.depth * .2
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
            width: _upperHead.width * .22
            property BodyPart brow: _brow
            property alias browEuler: _brow.eulerRotation
            BodyPart {
                color: "black"
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

        basePos: Qt.vector3d(0, 0, _head.depth * .09)
        color: _head.skinColor

        // Apply chin pointiness using scaled bottom face
        scaledFace: Box3DGeometry.BottomFace
        faceScale: Qt.vector2d(chinPointiness, 1.0)

        BodyPart {
            id: _mouthUpper

            readonly property int _mouthWidth: .33 * _lowerHead.width

            color: "black"
            basePos: Qt.vector3d(0, 0.6*_lowerHead.height, _lowerHead.depth * .5)
            width: _lowerHead.width * .22; height: .3 * width; depth: 0.1

            BodyPart {
                id: _mouthLeft
                color: "black"
                basePos: Qt.vector3d(-0.5*(_mouthUpper.width + width), 0, 0)
                width: _mouthUpper.height
            }
            BodyPart {
                id: _mouthRight
                color: "black"
                basePos: Qt.vector3d(0.5*(_mouthUpper.width + width), 0, 0)
                width: _mouthUpper.height
            }
            BodyPart {
                id: _mouthLower
                color: "black"
                width: _lowerHead.width * .23; height: .3 * width; depth: 0.1
            }
        }
    }

    // ACTIVITY ANIMATIONS

    ParallelAnimation
    {
        id: _sadnessAnimation
        running: _head.activity == Head.Activity.ShowSadness
        FrownMouth{}
        RaiseEyeBrowns{}
    }

    ParallelAnimation
    {
        id: _joyAnimation
        running: _head.activity == Head.Activity.ShowJoy
        SmileMouth{}
        RaiseEyeBrowns{}
    }

    ParallelAnimation {
        id: _angerAnimation
        running: _head.activity == Head.Activity.ShowAnger
        LowerEyeBrowns{}
        FrownMouth{}
    }

    SequentialAnimation {
        id: _talkAnimation
        running: _head.activity == Head.Activity.Talk
        loops: Animation.Infinite
        OpenMouth {duration: _head.talkDuration}
        CloseMouth {duration: _head.talkDuration}
    }

    ParallelAnimation {
        id: _idleAnimation
        running: _head.activity == Head.Activity.Idle
        NeutralEyeBrowns{}
        CloseMouth{}
    }



    //ANIMATION BUILDING BLOCKS

    component OpenMouth: ParallelAnimation {
        id: _openMouth
        property int duration: _head.talkDuration
        FrownMouth {duration: _openMouth.duration}
        PosAnim {
            duration: _openMouth.duration
            target: _mouthLower
            to: Qt.vector3d(target.basePos.x,
                            target.basePos.y - target.width * .45,
                            target.basePos.z)
        }
    }

    component CloseMouth: ParallelAnimation {
        id: _closeMouth
        property int duration: _head.talkDuration
        PosAnim {
            duration: _closeMouth.duration
            target: _mouthUpper
            to: target.basePos
        }
        PosAnim {
            duration: _closeMouth.duration
            target: _mouthLower
            to: target.basePos
        }
        PosAnim {
            duration: _closeMouth.duration
            target: _mouthLeft
            to: target.basePos
        }
        PosAnim {
            duration: _closeMouth.duration
            target: _mouthRight
            to: target.basePos
        }
    }

    component SmileMouth: ParallelAnimation {
        id: _smileMouth
        property int duration: _head.toEmotionDuration
        PosAnim {
            duration: _smileMouth.duration
            target: _mouthUpper
            to: target.basePos
        }
        PosAnim {
            duration: _smileMouth.duration
            target: _mouthLower
            to: target.basePos
        }
        PosAnim {
            duration: _smileMouth.duration
            target: _mouthLeft
            to: Qt.vector3d(target.basePos.x,
                            target.basePos.y + target.width * .5,
                            target.basePos.z)
        }
        PosAnim {
            duration: _smileMouth.duration
            target: _mouthRight
            to: Qt.vector3d(target.basePos.x,
                            target.basePos.y + target.width * .5,
                            target.basePos.z)
        }
    }

    component FrownMouth: ParallelAnimation {
        id: _frownMouth
        property int duration: _head.toEmotionDuration
        PosAnim {
            duration: _frownMouth.duration
            target: _mouthUpper
            to: target.basePos
        }
        PosAnim {
            duration: _frownMouth.duration
            target: _mouthLower
            to: target.basePos
        }
        PosAnim {
            duration: _frownMouth.duration
            target: _mouthLeft
            to: Qt.vector3d(target.basePos.x,
                            target.basePos.y - target.width * .5,
                            target.basePos.z)
        }
        PosAnim {
            duration: _frownMouth.duration
            target: _mouthRight
            to: Qt.vector3d(target.basePos.x,
                            target.basePos.y - target.width * .5,
                            target.basePos.z)
        }

    }

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
