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
        \qmlproperty bool Head::features
        \brief Whether the face is drawn at all - eyes, brows, nose, ears and
               mouth.

        On by default, and no longer something to turn off for performance: the
        eyes, brows and mouth are drawn into the head's own surfaces and cost
        no draw calls, so a face is nearly free. Off, the nose and ears go with
        it, which saves three.

        It used to be the single biggest saving available on a character - a
        face was thirteen boxes out of a head's twenty - and \l
        {Character::detail}{Character.detail} switched it off at a distance.
        That was always the wrong trade: an eye is about a thirtieth of a
        figure's height, so it is still a pixel or two at a hundred-pixel
        figure, and its absence reads as a character with no face rather than
        as a character far away. \l detail now thins the face instead of
        deleting it.

        \sa detail, Character::detail
    */
    property bool features: true

    /*!
        \qmlproperty enumeration Head::Detail
        \brief How much head to draw.

        \value Head.Detail.High Everything: irises, highlights, brows, mouth
               corners, nose and ears.
        \value Head.Detail.Low The drawn face thins to whites, lash lines and
               a lip; the ears go, which the hair was mostly hiding anyway.
               The nose stays - it is the one feature carrying silhouette.
        \value Head.Detail.Minimal The nose goes too, leaving the skull, the
               hair and a face that is still a face.

        The steps between these are worth 0, 2 and 3 draw calls respectively,
        because the expensive part of a face stopped being geometry. What Low
        and Minimal really buy is a face that stays legible when it is twenty
        pixels tall, rather than one that shimmers.
    */
    enum Detail { High, Low, Minimal }

    /*!
        \qmlproperty int Head::detail
        \brief Current level of head detail. Use the Head.Detail enum.

        Set by \l {Character::detail}{Character.detail} on a character.
    */
    property int detail: Head.Detail.High

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
    // The one place this offset is written; both head boxes and every Z anchor
    // below read it from here.
    //
    // Deliberately NOT `_head.depth * 0.09`, which is the same number: taking
    // it off the group's own aggregate depth makes Qt detect a binding loop and
    // drop the binding, and a dropped binding leaves the anchors holding
    // whatever they happened to reach first. That is not a warning to live
    // with - it put the professor's moustache at the wrong depth, in front of
    // the mouth it is supposed to sit above. The loop predates these anchors
    // having any callers at all, which is exactly why nobody saw it: an
    // anchor nothing reads is an anchor nothing evaluates.
    //
    // The two boxes are the source of truth for their own size. `depth` on the
    // group is a summary derived FROM them, so asking it what they measure is
    // the wrong direction of enquiry as well as a loop.
    readonly property real faceOffsetZ: Math.max(_upperHead.depth, _lowerHead.depth) * 0.09

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
    readonly property real faceFront: _head.faceOffsetZ + _upperHead.depth * 0.5

    /*!
        \qmlproperty real Head::faceBack
        \brief Z of the back face of the cranium - where hair that wraps the
               skull has to stop.
    */
    readonly property real faceBack: _head.faceOffsetZ - _upperHead.depth * 0.5

    /*!
        \qmlproperty real Head::jawFront
        \brief Z of the front face of the jaw - the plane the mouth sits on.
    */
    readonly property real jawFront: _head.faceOffsetZ + _lowerHead.depth * 0.5

    /*!
        \qmlproperty real Head::eyeRelief
        \brief How far the eyes stand proud of \l faceFront.

        Zero, because the eyes are drawn into the face rather than built in
        front of it - so a spectacle rim can sit on the face plane and does
        not have to be pushed clear of a pair of protruding cubes. It stays
        published because that is the fact accessories need to know, and a
        head that grows something proud of its face again can say so here
        without every accessory being re-authored.
    */
    readonly property real eyeRelief: 0

    /*!
        \qmlproperty real Head::earTop
        \brief Y of the top of the ears.
    */
    readonly property real earTop: _head.earPos.y + _head.earSize

    /*!
        \qmlproperty real Head::hairOuterX
        \brief How far from the centre line the head's own side hair reaches.

        Half the skull when \l hairVolume is 0. An arm routed to an ear passes
        through the side hair unless it is pushed out to at least this.
    */
    // The slab straddles the skull's side face, so only half of it is outside.
    readonly property real hairOuterX: _upperHead.width * 0.5
                                       + (_leftHair.visible ? _leftHair.width * 0.5 : 0)

    /*!
        \qmlproperty real Head::eyeWidth
        \brief Edge length of one eye. The eyes are cubes, so this is their
               height and depth as well.
    */
    readonly property real eyeWidth: _upperHead.width * .22 * _head.eyeSize

    /*!
        \qmlproperty real Head::eyeSpacing
        \brief How far each eye centre sits from the head's centre line.
    */
    readonly property real eyeSpacing: _head.eyeWidth

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
                                                   _head.upperHeadBottom + _rightEar.basePos.y,
                                                   _head.faceOffsetZ + _rightEar.basePos.z)

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
    readonly property real mouthBottom: _head.mouthLine - _lowerHead._mouth.lineH
                                        - _lowerHead._mouth.gap

    /*!
        \qmlproperty real Head::chinBottom
        \brief Y of the chin, which drops below the head origin while the
               mouth is open.
    */
    readonly property real chinBottom: -_lowerHead.jawStretch

    /*!
        \qmlproperty vector2d Head::gaze
        \brief Where the eyes look, as a fraction of the irises' free travel
               inside the whites. (0,0) is straight ahead, (1,0) hard right.

        Costs nothing and moves nothing: the irises are drawn, so aiming them
        is a uniform rather than a transform. Sliding a built iris sideways
        would carry it off its own eyeball and break from the side, which is
        why the head had to be turned for this before.
    */
    property vector2d gaze: Qt.vector2d(0, 0)

    /*!
        \qmlproperty int Head::faceDetail
        \brief How much of the drawn face to draw: 1 all of it, 0 only what
               survives being small.

        At 0 the irises, their highlights, the brows and the mouth corners are
        skipped and the whites, the lash lines and the lip remain. A shader
        branch, not a change of geometry - so unlike switching \l features it
        cannot pop, and it costs no draw calls either way.

        Derived from \l detail; set that instead.

        \sa detail, Character::detail
    */
    readonly property int faceDetail: _head.detail === Head.Detail.High ? 1 : 0

    /*!
        \qmlproperty bool Head::autoBlink
        \brief Whether the eyes blink by themselves.

        Off by default, and deliberately so: a lab replays a scene from a seed
        and compares the frames, so anything moving on its own has to be asked
        for. When it is on the rhythm is fixed rather than random, for the same
        reason.

        A blink is one animated number here and nothing at all in the scene -
        the lids are drawn, so closing them costs no geometry and no draw call.
        As boxes it would have meant resizing an eye every frame of every
        blink, which is why the eyes never blinked before.

        \sa blinkInterval, eyeHood
    */
    property bool autoBlink: false

    /*!
        \qmlproperty int Head::blinkInterval
        \brief Milliseconds between blinks when \l autoBlink is on.
    */
    property int blinkInterval: 4200

    /*!
        \qmlproperty real Head::blinkAmount
        \brief How shut the blink currently has the eyes, 0 to 1.

        Composes ON TOP of \l eyeHood rather than replacing it, so a character
        can blink in the middle of a glare and come back to the glare.
        Writable, for a caller that would rather drive its own rhythm - a
        performance script cueing a blink on a line, say - with \l autoBlink
        left off.
    */
    property real blinkAmount: 0

    /*!
        \qmlmethod void Head::blink()
        \brief Blinks once, now.

        Separate from \l autoBlink so anything that knows a blink belongs
        here can ask for one - a performance script on a line, or a large
        gaze shift, which a real face nearly always blinks through.
    */
    function blink() { _blinkAnim.restart() }

    /*!
        \qmlproperty int Head::blinkSeed
        \brief Which irregular-but-repeatable blink rhythm this head gets.

        Two heads with the same seed blink in step, which is the one thing a
        crowd must not do; two runs of the same sandbox blink identically,
        which is what keeps a clayrender comparison meaningful.
    */
    property int blinkSeed: 1

    Timer {
        id: _blinkTimer
        // Evenly spaced blinks read as a metronome - the eye notices the beat
        // long before it notices the blink. The spacing wanders by a third
        // either way, from a sequence that is fixed for a given seed rather
        // than from a wall clock.
        property int _rng: Math.max(1, _head.blinkSeed)
        function _next() {
            _rng = (_rng * 1664525 + 1013904223) >>> 0
            const f = 0.66 + (_rng / 4294967296) * 0.68
            interval = Math.max(400, Math.round(_head.blinkInterval * f))
        }
        running: _head.autoBlink
        interval: _head.blinkInterval
        repeat: true
        onRunningChanged: if (running) _next()
        onTriggered: { _head.blink(); _next() }
    }

    SequentialAnimation {
        id: _blinkAnim
        // Down fast, up a little slower - a blink that shuts and opens at the
        // same rate reads as a wince.
        NumberAnimation { target: _head; property: "blinkAmount"
                          to: 1; duration: 70; easing.type: Easing.OutQuad }
        NumberAnimation { target: _head; property: "blinkAmount"
                          to: 0; duration: 110; easing.type: Easing.InQuad }
    }

    // The brows, as the two numbers the emotion animations actually move: how
    // far above their resting place, and at what angle. They were a pair of
    // boxes with a position and an euler each, which is four animated targets
    // for a thing that has two degrees of freedom.
    property real _browRise: 0
    property real _browAngle: 0

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

    // Upper head: the cranium, and the eyes drawn into its front.
    //
    // A FaceBox rather than a BodyPart, which costs nothing - it is the same
    // geometry with a material that can draw on itself. The eyes, their lids,
    // their irises and their brows used to be six boxes standing proud of this
    // one; six draw calls for markings with no silhouette, and from any angle
    // off dead-centre you could see the side wall of an eye.
    FaceBox {
        id: _upperHead

        // Default dimensions
        width: 1.0
        height: 0.8
        depth: 1.2

        showEdges: false

        basePos: Qt.vector3d(0, _lowerHead.baseHeight * 0.99, _head.faceOffsetZ)
        color: _head.skinColor

        panel: _head.features ? FaceBox.Eyes : FaceBox.None
        faceDetail: _head.faceDetail

        eyeColor: _head.eyeColor
        browColor: _head.hairColor
        // Both in this box's own frame, which is what the anchors above
        // publish - so the eyes and anything worn over them are placed from
        // one set of numbers instead of two.
        eyeCentre: Qt.vector2d(_head.eyeSpacing,
                               _upperHead._eyeLine + _head.eyeWidth * 0.5)
        eyeHalf: _head.eyeWidth * 0.5
        eyeSquint: _head.eyeSquint
        // The emotion's lid and the blink's, combined - not one replacing the
        // other, so a blink lands on top of a glare and leaves it there.
        eyeHood: Math.min(1, _head.eyeHood + _head.blinkAmount)
        gaze: _head.gaze

        // The brow bar, and where it rests relative to the eye's centre. The
        // brow that was a box hung 0.8 eye widths above the eye's floor and
        // stood a third of an eye tall; these are the same numbers.
        browHalf: Qt.vector2d(_head.eyeWidth * 0.6, _head.eyeWidth * 0.165)
        browOffset: Qt.vector2d(0, _head.eyeWidth * 0.465 + _head._browRise)
        browAngle: _head._browAngle

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
            // The last feature to go. A nose is the only one of them that is
            // actually in front of the face rather than on it, so it is the
            // only one whose absence changes the three-quarter silhouette.
            visible: _head.features && _head.detail !== Head.Detail.Minimal
            color: _head.skinColor.darker(1.1)
            width: _upperHead.width * .15 * _head.noseSize
            height: _upperHead.height * .2 * _head.noseSize
            depth: _upperHead.depth * .2 * _head.noseSize
            basePos: Qt.vector3d(0,
                                 _upperHead._eyeLine - height * 1.1,
                                 _upperHead.depth * .5)
        }

        component Ear: BodyPart {
            // First to go: at any distance where Low is the right answer the
            // hair has already covered most of an ear.
            visible: _head.features && _head.detail === Head.Detail.High
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

    }

    // Lower head: the jaw, and the mouth drawn into its front. When the mouth
    // opens, the box stretches downward: the top edge stays attached to the
    // upper head while the chin extends - no seam, no face split.
    //
    // The mouth lives on THIS box rather than on the cranium precisely because
    // the box stretches: a mouth drawn into the jaw follows the jaw for free.
    FaceBox {
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
        // Everything except the four TOP borders (bits 3-6). Those four run
        // along the seam to the cranium, which is halfway up the cheek, and
        // the jaw was drawing a black line straight across the face there.
        // The old spelling - bottom|left|right|front|back - reads as "all but
        // the top" but ORs out to 0xFF, because the eight mask bits are shared
        // between faces rather than one per box edge: bit 3 is the front
        // face's top border AND the left face's left border, so naming the
        // left face turned the front face's top border back on.
        //
        // Not cosmetic. It is the whole of the visible split between the two
        // head boxes: their front faces are coplanar and the same colour, so
        // with this line gone the pair is indistinguishable from one box.
        edgeMask: allEdges & ~_seamEdges
        readonly property int _seamEdges: 0x78

        property real chinPointiness: 1.0

        // Box origin is bottom-center: shift down by the stretch so the
        // top edge stays fixed at the seam to the upper head.
        basePos: Qt.vector3d(0, -jawStretch, _head.faceOffsetZ)
        color: _head.skinColor

        // Apply chin pointiness using scaled bottom face
        scaledFace: Box3DGeometry.BottomFace
        faceScale: Qt.vector2d(chinPointiness, 1.0)

        panel: _head.features ? FaceBox.Mouth : FaceBox.None
        faceDetail: _head.faceDetail
        lipColor: "black"
        cavityColor: "#20100c"

        // The mouth, from the same continuous shape parameters as before
        // (open/wide/round/cornerLift) - only drawn rather than built.
        //
        // The Y counteracts the jaw stretch, exactly as the mouth Node used
        // to: the box origin has moved down, and the mouth line has not.
        mouthCentre: Qt.vector2d(0, _head.mouthLine + _lowerHead.jawStretch)
        // Widened by "ee", narrowed by "oo".
        mouthHalf: Qt.vector2d(_head.mouthWidth * 0.5
                               * (1 + 0.5 * _head.mouthWide)
                               * (1 - 0.4 * _head.mouthRound),
                               _mouth.lineH)
        mouthGap: _mouth.gap
        // Narrowing the mouth (above) is half of a rounded vowel; the cavity
        // becoming a circle rather than a shorter slot is the other half.
        mouthRound: _head.mouthRound
        mouthCornerLift: _head.mouthCornerLift

        // Kept as named values because the anchors publish them: mouthBottom
        // is where a beard has to start, and it is not derivable from the
        // outside once the shapes are in a shader.
        readonly property QtObject _mouth: QtObject {
            readonly property real lineH: .3 * _head.mouthWidth
            // The gap the mouth opens up toward the stretching chin.
            readonly property real gap: _head.mouthOpen * _lowerHead.baseHeight * 0.45
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
    //
    // Two numbers, not two transforms. A brow has one angle and one height;
    // as a pair of boxes it had a position and an euler each, so the same two
    // degrees of freedom were spread over four animated targets that had to be
    // kept mirrored by hand.

    component BrowAnim: NumberAnimation {
        target: _head
        easing.type: Easing.InOutQuad
    }

    component LowerEyeBrowns: ParallelAnimation {
        id: _lowerEyeBrowns
        property int duration: _head.toEmotionDuration
        BrowAnim { duration: _lowerEyeBrowns.duration
                   property: "_browAngle"; to: 25 }
        BrowAnim { duration: _lowerEyeBrowns.duration
                   property: "_browRise"; to: 0 }
    }

    component RaiseEyeBrowns: ParallelAnimation {
        id: _raiseEyeBrowns
        property int duration: _head.toEmotionDuration
        BrowAnim { duration: _raiseEyeBrowns.duration
                   property: "_browAngle"; to: -5 }
        // Up by its own height, which is what the box used to move.
        BrowAnim { duration: _raiseEyeBrowns.duration
                   property: "_browRise"; to: _head.eyeWidth * 0.33 }
    }

    component NeutralEyeBrowns: ParallelAnimation {
        id: _neutralEyeBrowns
        property int duration: _head.toEmotionDuration
        BrowAnim { duration: _neutralEyeBrowns.duration
                   property: "_browAngle"; to: 0 }
        BrowAnim { duration: _neutralEyeBrowns.duration
                   property: "_browRise"; to: 0 }
    }

}
