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
        \brief Height of the lower head (jaw) at rest.

        The rendered jaw may momentarily be taller while the mouth is
        open (see \l jawDrop).
    */
    property alias lowerHeadHeight: _lowerHead.baseHeight

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
    // FACE ANCHORS
    // ============================================================================
    // Where the features of this face actually are, in the head node's own
    // frame - which is the frame anything parented to \l Character::head lives
    // in. Y is measured from the head node's origin (the top of the neck),
    // Z from its centre, and the face is on +Z.
    //
    // Published because an accessory otherwise has to restate the arithmetic
    // below - and then a beard slides off a chin the day a dimension changes,
    // with nothing raising an error. Every anchor is derived from the parts
    // themselves, never a second copy of their expressions.

    /*!
        \qmlproperty real Head::faceOffsetZ
        \brief How far forward of the head node both head boxes sit.
    */
    readonly property real faceOffsetZ: _upperHead.basePos.z

    /*!
        \qmlproperty real Head::upperHeadBottom
        \brief Y of the seam between jaw and cranium - the bottom of the
               upper head box.
    */
    readonly property real upperHeadBottom: _upperHead.basePos.y

    /*!
        \qmlproperty real Head::crownTop
        \brief Y of the top of the skull, hair not included.
    */
    readonly property real crownTop: _upperHead.basePos.y + _upperHead.height

    /*!
        \qmlproperty real Head::faceFront
        \brief Z of the front face of the cranium - the plane the eyes and
               the nose stand on.
    */
    readonly property real faceFront: _upperHead.basePos.z + _upperHead.depth * 0.5

    /*!
        \qmlproperty real Head::jawFront
        \brief Z of the front face of the jaw - the plane the mouth sits on.
    */
    readonly property real jawFront: _lowerHead.basePos.z + _lowerHead.depth * 0.5

    /*!
        \qmlproperty real Head::eyeWidth
        \brief Edge length of one eye. The eyes are cubes, so this is their
               height and depth as well.
    */
    readonly property real eyeWidth: _leftEye.width

    /*!
        \qmlproperty real Head::eyeSpacing
        \brief How far each eye centre sits from the head's centre line.
    */
    readonly property real eyeSpacing: -_leftEye.basePos.x

    /*!
        \qmlproperty real Head::eyeLine
        \brief Y of the eye centres.

        Reads the eyes' resting size, so it stays put when a lid closes.
    */
    readonly property real eyeLine: _upperHead.basePos.y + _upperHead._eyeLine
                                    + _head.eyeWidth * 0.5

    /*!
        \qmlproperty real Head::noseBottom
        \brief Y of the underside of the nose - as far down the face as
               spectacles can slip.
    */
    readonly property real noseBottom: _upperHead.basePos.y + _nose.basePos.y

    /*!
        \qmlproperty vector3d Head::earPos
        \brief Origin of the right ear (bottom centre of its box). The left
               ear is the same point with x negated.
    */
    readonly property vector3d earPos: Qt.vector3d(_rightEar.basePos.x,
                                                   _upperHead.basePos.y + _rightEar.basePos.y,
                                                   _upperHead.basePos.z + _rightEar.basePos.z)

    /*!
        \qmlproperty real Head::earSize
        \brief Edge length of one ear, which is a cube like the eyes.
    */
    readonly property real earSize: _rightEar.width

    /*!
        \qmlproperty real Head::mouthWidth
        \brief Width of the closed, unstretched mouth. What \l mouthWide and
               \l mouthRound do to it is momentary and not included here.
    */
    readonly property real mouthWidth: _lowerHead.width * .22 * _head.mouthSize

    /*!
        \qmlproperty real Head::mouthLine
        \brief Y of the upper lip.

        Fixed: the jaw box stretches downward as the mouth opens (see
        \l jawDrop) but the mouth line stays where it is on the face.
    */
    readonly property real mouthLine: 0.6 * _lowerHead.baseHeight

    /*!
        \qmlproperty real Head::mouthBottom
        \brief Y of the lowest point the mouth currently reaches - the
               bottom of the cavity, which grows downward as it opens.
    */
    readonly property real mouthBottom: _head.mouthLine - _mouth.lineH - _mouth.gap

    /*!
        \qmlproperty real Head::chinBottom
        \brief Y of the chin, which drops below the head origin while the
               mouth is open.
    */
    readonly property real chinBottom: -_lowerHead.jawStretch

    // ============================================================================
    // MOUTH SHAPE PARAMETERS
    // ============================================================================

    /*!
        \qmlproperty real Head::mouthOpen
        \readonly
        \brief How far the mouth/jaw is opened (0 = closed, 1 = fully open).

        Driven by the facial activity animations or a \l speechSource.
        Readonly on purpose: assigning it directly would break the binding
        that lets speech drive the mouth. For fully manual mouth control,
        set \l speechSource to any object providing \c speaking,
        \c mouthOpen, \c mouthWide and \c mouthRound.
    */
    readonly property real mouthOpen: speechActive ? speechSource.mouthOpen : _animMouthOpen

    /*!
        \qmlproperty real Head::mouthWide
        \readonly
        \brief How far the mouth is stretched sideways (0-1), e.g. for "ee" sounds.
    */
    readonly property real mouthWide: speechActive ? speechSource.mouthWide : _animMouthWide

    /*!
        \qmlproperty real Head::mouthRound
        \readonly
        \brief How rounded/puckered the mouth is (0-1), e.g. for "oo" sounds.
    */
    readonly property real mouthRound: speechActive ? speechSource.mouthRound : _animMouthRound

    /*!
        \qmlproperty real Head::mouthCornerLift
        \brief Mouth corner position from frown (-1) over neutral (0) to smile (1).

        Stays under emotion control even while a speechSource drives the
        other mouth parameters - characters can smile while talking.
    */
    property real mouthCornerLift: 0

    /*!
        \qmlproperty real Head::eyeSquint
        \brief How far the lower lid is raised, 0 open to 1 nearly shut.

        The eye closes from BELOW and its top edge stays put, which is what
        separates a smile from a stare: a face whose only happy signal is at
        the mouth reads as startled, because nobody smiles with their eyes
        wide open. Under a big moustache it may be the only signal left.

        \sa eyeHood
    */
    property real eyeSquint: 0

    /*!
        \qmlproperty real Head::eyeHood
        \brief How far the upper lid is lowered, 0 open to 1 nearly shut.

        Closes the eye from ABOVE, leaving the lower edge where it was. The
        other half of \l eyeSquint and not interchangeable with it: a lid
        coming down is a glare or a droop, a lid coming up is a smile.
    */
    property real eyeHood: 0

    /*!
        \qmlproperty real Head::jawDrop
        \brief How far the chin stretches down when \l mouthOpen is 1, as a
               fraction of the lower head height.

        The jaw box stretches downward (its top edge stays attached to the
        upper head), so the chin visibly drops without the face splitting
        apart - cartoon squash-and-stretch instead of rigid jaw motion.
    */
    property real jawDrop: 0.25

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

        basePos: Qt.vector3d(0, _lowerHead.baseHeight * 0.99, _head.depth * .09)
        color: _head.skinColor

        // The height the eyes sit at inside this box, and with them the nose
        // and the ears. Named once here so the three cannot drift apart;
        // \l Head::eyeLine publishes it in the head's own frame.
        readonly property real _eyeLine: .3 * height

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
                                 _upperHead._eyeLine - height * 1.1,
                                 _upperHead.depth * .5)
        }

        component Ear: BodyPart {
            color: _head.skinColor
            width: .25 * _upperHead.height; depth: 0.2 * _upperHead.depth
        }

        Ear {
            id: _leftEar
            basePos: Qt.vector3d(-0.55*_upperHead.width, _upperHead._eyeLine, 0)
        }

        Ear {
            id: _rightEar
            basePos: Qt.vector3d(-_leftEar.basePos.x,
                                  _leftEar.basePos.y,
                                  _leftEar.basePos.z)
        }

        // The eye is a cube whose height the lids eat into. Closing it by
        // SHRINKING the white, rather than by putting a skin-coloured plate
        // in front of it, is what makes it survive being looked at from the
        // side: a plate only covers the face-on view, and these heads are
        // seen from three-quarters most of the time.
        component Eye: BodyPart {
            id: _eye
            color: "white"
            width: _upperHead.width * .22 * _head.eyeSize

            // What each lid takes. Half the eye is as far as either goes -
            // past that the iris has nowhere to sit and the face reads as
            // asleep rather than as pleased.
            readonly property real cutBelow: _eye.width * 0.5 * _head.eyeSquint
            readonly property real cutAbove: _eye.width * 0.5 * _head.eyeHood
            // Never fully shut: a zero-height box still draws its outline.
            height: Math.max(_eye.width * 0.12,
                             _eye.width - _eye.cutBelow - _eye.cutAbove)

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
                height: .33 * _eye.width
                depth: _eye.depth
                // Anchored to the eye's OPEN size, not to its current one.
                // Hung off the height it would ride the lids down, and an
                // eyebrow that follows the lid is an eyebrow inside the eye.
                //
                // The z was an absolute 0.1 among otherwise proportional
                // numbers. On a head the size of a cartoon professor's that
                // is most of an eye's depth, so the brows floated clear of
                // the face and in front of anything worn over the eyes -
                // visible as two bars hanging off the front of the skull.
                basePos: Qt.vector3d(0, 0.8 * _eye.width, _eye.depth * 0.18)
            }
        }

        Eye {
            id: _leftEye
            // Only the bottom edge moves: cutBelow closes the eye from below
            // by lifting its floor, cutAbove by lowering its ceiling, which
            // needs nothing here because the box grows upward from basePos.
            basePos: Qt.vector3d(-_leftEye.width,
                                 _upperHead._eyeLine + _leftEye.cutBelow,
                                 _upperHead.depth * .5)
        }

        Eye {
            id: _rightEye
            basePos: Qt.vector3d(-_leftEye.basePos.x, _leftEye.basePos.y, _leftEye.basePos.z)
        }
    }

    // Lower head part containing mouth and chin. When the mouth opens,
    // the box stretches downward: the top edge stays attached to the
    // upper head while the chin extends - no seam, no face split.
    BodyPart {
        id: _lowerHead

        // Configured (rest) height; the public lowerHeadHeight alias
        // targets this so characters set dimensions independent of the
        // momentary jaw stretch.
        property real baseHeight: 0.5
        readonly property real jawStretch: _head.mouthOpen * _head.jawDrop * baseHeight

        // Default dimensions
        width: 1.0
        height: baseHeight + jawStretch
        depth: 1.2
        showEdges: true
        edgeMask: bottomEdges | leftEdges | rightEdges | frontEdges | backEdges

        property real chinPointiness: 1.0

        // Box origin is bottom-center: shift down by the stretch so the
        // top edge stays fixed at the seam to the upper head.
        basePos: Qt.vector3d(0, -jawStretch, _head.depth * .09)
        color: _head.skinColor

        // Apply chin pointiness using scaled bottom face
        scaledFace: Box3DGeometry.BottomFace
        faceScale: Qt.vector2d(chinPointiness, 1.0)

        // Mouth on the front of the jaw, built from the continuous
        // shape parameters (open/wide/round/cornerLift).
        Node {
            id: _mouth
            // Counteracts the jaw stretch (the box origin moved down) so
            // the mouth line (upper lip) stays fixed on the face while
            // the chin extends below.
            position: Qt.vector3d(0,
                                  _head.mouthLine + _lowerHead.jawStretch,
                                  _lowerHead.depth * .5)

            readonly property real baseW: _head.mouthWidth
            readonly property real lineH: .3 * baseW
            // widened by "ee", narrowed by "oo"
            readonly property real w: baseW * (1 + 0.5 * _head.mouthWide)
                                            * (1 - 0.4 * _head.mouthRound)
            // gap the mouth opens up toward the stretching chin
            readonly property real gap: _head.mouthOpen * _lowerHead.baseHeight * 0.45

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
            //
            // Hinged at the end of the mouth line and turned, rather than a
            // box moved up and down beside it. As a free cube the corner rose
            // clear of the lip it belonged to: at full smile it sat 0.25 base
            // widths up while being only 0.3 tall, so two thirds of its own
            // height of bare skin showed underneath. A smiling character wore
            // two dots floating past the ends of a straight mouth and read as
            // startled rather than pleased. A stroke that starts AT the mouth
            // and turns keeps the shape continuous, which is the whole reason
            // a viewer reads it as one expression.
            component MouthCorner: Node {
                id: _corner
                // -1 is the character's left, +1 its right.
                required property real side

                position: Qt.vector3d(_corner.side * 0.5 * _mouth.w, 0, 0)
                // Lift is an angle now. Both signs work out: the far end of
                // the stroke rises for a smile and drops for a frown on
                // either side of the face.
                eulerRotation.z: _corner.side * _head.mouthCornerLift * 40

                BodyPart {
                    id: _stroke
                    color: "black"
                    width: _mouth.w * 0.42
                    height: _mouth.lineH * 0.7
                    // The lip line's depth, so the two are the same surface
                    // and no corner floats in front of the face.
                    depth: 0.11
                    showEdges: false
                    castsShadows: false
                    // Grows outward from the hinge and straddles the mouth
                    // line, so its inner end always overlaps the lip.
                    basePos: Qt.vector3d(_corner.side * _stroke.width * 0.5,
                                         -0.5 * _stroke.height, 0)
                }
            }
            MouthCorner { side: -1 }
            MouthCorner { side: 1 }
        }
    }

    // ACTIVITY ANIMATIONS
    //
    // Emotions animate the mouth parameters, the eyelids and the eyebrows.
    // While a speechSource is active it overrides open/wide/round (see the
    // property bindings above); corner lift and the lids stay with the
    // emotions, so a character can smile while it talks.
    //
    // Which lid moves is the whole of the difference between the emotions at
    // the eyes: up from below is pleasure, down from above is a glare, both
    // a little is tired or sad. Getting that backwards produces a face that
    // is unmistakably wrong and impossible to name.

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
        // Half-mast, mostly from above: sadness is a face with no energy in
        // it, and the small squint keeps it from reading as merely sleepy.
        MouthParamAnim { property: "eyeHood"; to: 0.45 }
        MouthParamAnim { property: "eyeSquint"; to: 0.12 }
        RaiseEyeBrowns {}
    }

    ParallelAnimation {
        id: _joyAnimation
        running: _head.activity == Head.Activity.ShowJoy
        MouthParamAnim { property: "mouthCornerLift"; to: 0.8 }
        MouthParamAnim { property: "_animMouthOpen"; to: 0.1 }
        MouthParamAnim { property: "_animMouthWide"; to: 0.4 }
        MouthParamAnim { property: "_animMouthRound"; to: 0 }
        // The cheek pushing the lower lid up. This is the one that carries a
        // smile when the mouth is hidden - behind a moustache, at a distance,
        // or turned away.
        MouthParamAnim { property: "eyeSquint"; to: 0.55 }
        MouthParamAnim { property: "eyeHood"; to: 0 }
        RaiseEyeBrowns {}
    }

    ParallelAnimation {
        id: _angerAnimation
        running: _head.activity == Head.Activity.ShowAnger
        MouthParamAnim { property: "mouthCornerLift"; to: -0.7 }
        MouthParamAnim { property: "_animMouthOpen"; to: 0.15 }
        MouthParamAnim { property: "_animMouthWide"; to: 0.3 }
        MouthParamAnim { property: "_animMouthRound"; to: 0 }
        // Narrowed from above, under the brows that are already coming down
        // to meet it. Nothing from below: an angry face is not a squeezed
        // one, it is a covered one.
        MouthParamAnim { property: "eyeHood"; to: 0.4 }
        MouthParamAnim { property: "eyeSquint"; to: 0 }
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
        MouthParamAnim { property: "eyeSquint"; to: 0 }
        MouthParamAnim { property: "eyeHood"; to: 0 }
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
