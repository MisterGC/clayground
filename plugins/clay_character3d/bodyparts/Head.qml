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
    hair, eyes, ears, nose, and mouth. It supports six animated facial
    expressions - neutral, joy, sadness, anger, disgust and surprise - plus
    talking.

    The mouth is driven by a small set of continuous shape parameters
    (\l mouthOpen, \l mouthWide, \l mouthRound, \l mouthCornerLift,
    \l mouthSkew). The expression activities animate these parameters; a
    \l speechSource (typically a \l Speech instance) can take over
    open/wide/round for lip-synced talking while emotions keep control of the
    mouth corners.

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
        \qmlproperty vector3d Head::poseEuler
        \brief Where a body animation is aiming the head.

        The head is the one joint more than one thing has an opinion about.
        Everywhere else an animation drives \c eulerRotation directly, but an
        aim and a nod are not alternatives - the nod happens WHILE the aim
        holds, and has to be given back afterwards without the aim having
        been forgotten.

        So the animators drive this, momentary things drive \l offsetEuler,
        and the head adds them to \c baseEuler. Anything animating a head's
        \c eulerRotation directly is writing to the sum and will have its
        value overwritten the next time either part changes.

        \sa offsetEuler, nod(), HeadEulerAnim
    */
    property vector3d poseEuler: Qt.vector3d(0, 0, 0)

    /*!
        \qmlproperty vector3d Head::offsetEuler
        \brief A momentary rotation on top of whatever the head is aiming at.

        Degrees, added to \l poseEuler. A nod, a shake, a tilt - anything
        that happens and then stops happening without disturbing where the
        head was pointed.

        \sa poseEuler, nod()
    */
    property vector3d offsetEuler: Qt.vector3d(0, 0, 0)

    // BodyPart binds this to baseEuler alone. The head needs the sum, and it
    // needs it as a BINDING - the animators used to animate eulerRotation
    // itself, which broke that binding permanently the first time any of
    // them ran and left anything else wanting a say with nowhere to put it.
    eulerRotation: Qt.vector3d(_head.baseEuler.x + _head.poseEuler.x
                                   + _head.offsetEuler.x + _head._nodPitch,
                               _head.baseEuler.y + _head.poseEuler.y + _head.offsetEuler.y,
                               _head.baseEuler.z + _head.poseEuler.z + _head.offsetEuler.z)

    /*!
        \qmlmethod void Head::nod(real degrees, int times)
        \brief Nods, and gives the head back.

        Down then up, on \l offsetEuler, so it composes with wherever the
        head is already aimed - a listener can nod at someone it is looking
        at without losing them.

        \a degrees defaults to 7, which is a backchannel nod rather than a
        bow; \a times defaults to 1.
    */
    function nod(degrees, times) {
        _nodAnim.stop()
        _nodAnim.depth = (degrees === undefined ? 7 : degrees)
        _nodAnim.loops = Math.max(1, times === undefined ? 1 : times)
        _nodAnim.start()
    }

    SequentialAnimation {
        id: _nodAnim
        property real depth: 7
        // Down is quicker than up. A nod that returns at the speed it fell
        // reads as a bounce; the weight is in the drop.
        NumberAnimation { target: _head; property: "_nodPitch"
                          to: _nodAnim.depth; duration: 130
                          easing.type: Easing.OutQuad }
        NumberAnimation { target: _head; property: "_nodPitch"
                          to: 0; duration: 210; easing.type: Easing.InOutQuad }
    }

    // Its own summed channel rather than a writer into offsetEuler: a nod and
    // a caller's own offset are two things that can be true at once, and
    // whichever wrote the vector last would otherwise erase the other.
    property real _nodPitch: 0

    /*!
        \qmlproperty real Head::nodAmount
        \readonly
        \brief How far into a nod the head is, in degrees.

        Its own channel, so it is not readable from \l offsetEuler - which
        is the point of the two being separate, and worth a property rather
        than an explanation.
    */
    readonly property real nodAmount: _head._nodPitch

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
        // real, not int - see GazeAnim: a QML int is signed 32-bit, so an
        // LCG state reaching 2^32 comes back out negative and the spacing
        // factor leaves the range it was written for.
        property real _rng: Math.max(1, _head.blinkSeed)
        function _next() {
            _rng = (_rng * 16807) % 2147483647
            const f = 0.66 + (_rng / 2147483647) * 0.68
            // The floor is a guard against a blinkInterval set absurdly low,
            // but it also swallows the variation whole below about 600 ms -
            // every seed comes out at 400 and the rhythm is a metronome again.
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
    // The third brow number, and the only asymmetric one on the face: one brow
    // up while the other goes down. A length, like _browRise.
    property real _browSkew: 0

    /*!
        \qmlproperty real Head::browAngle
        \readonly
        \brief The angle the current expression is holding the brows at, in
               degrees. Positive drops the inner ends into a V.

        \sa browRise, browSkew
    */
    readonly property real browAngle: _head._browAngle

    /*!
        \qmlproperty real Head::browRise
        \readonly
        \brief How far above their resting place the brows are, as a length
               in the same units \l eyeWidth is measured in.

        Does NOT include \l browFlash, which is a momentary thing on top.

        \sa browAngle, browSkew
    */
    readonly property real browRise: _head._browRise

    /*!
        \qmlproperty real Head::browSkew
        \readonly
        \brief How far one brow is raised above the other, as a length.

        The three brow numbers are published for the same reason
        \l nodAmount is: together with the mouth parameters and the lids they
        are WHICH expression the face is wearing, and once the brows are
        shapes in a shader there is no measuring them from outside. A test
        that has to tell six expressions apart asserts on these rather than on
        pixels.

        \sa browAngle, browRise, mouthSkew
    */
    readonly property real browSkew: _head._browSkew

    /*!
        \qmlproperty real Head::browFlash
        \brief A momentary brow raise on top of whatever the face is wearing.

        Additive, in the same units \l eyeWidth is measured in, so it
        composes with an emotion rather than replacing it - a listener can
        acknowledge a point without ceasing to look pleased about it.

        \sa flashBrows()
    */
    property real browFlash: 0

    /*!
        \qmlmethod void Head::flashBrows(real amount)
        \brief Raises the brows and lets them fall.

        The one gesture a face makes while somebody else is talking. Fast up,
        slower down - the reverse reads as a flinch.
    */
    function flashBrows(amount) {
        _browFlashAnim.peak = (amount === undefined ? 0.28 : amount) * _head.eyeWidth
        _browFlashAnim.restart()
    }

    SequentialAnimation {
        id: _browFlashAnim
        property real peak: 0
        NumberAnimation { target: _head; property: "browFlash"
                          to: _browFlashAnim.peak; duration: 120
                          easing.type: Easing.OutQuad }
        NumberAnimation { target: _head; property: "browFlash"
                          to: 0; duration: 260; easing.type: Easing.InOutQuad }
    }

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
        \qmlproperty real Head::mouthSkew
        \brief A one-sided lip curl, -1 to 1. A sneer, not a frown.

        The whole mouth tilts and one corner climbs clear of the other, so a
        face can be lopsided. Everything else here is mirrored, which is why
        this exists: disgust is the one expression whose whole point is that
        the two halves disagree, and without it it comes out as a milder
        anger. Composes with \l mouthCornerLift - a sneer keeps whatever the
        corners were already doing.

        Under emotion control while a \l speechSource is talking, exactly as
        \l mouthCornerLift is.

        \sa mouthCornerLift
    */
    property real mouthSkew: 0

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
        \value Head.Activity.ShowDisgust Sneer - the one lopsided face
        \value Head.Activity.ShowSurprise Round open mouth under high brows

        \sa Character::setEmotion
    */
    // The two added last are added at the END, out of the reading order the
    // documentation above uses. A QML enum numbers its values by position, and
    // a saved character carries the number rather than the name - inserting
    // ShowDisgust after ShowAnger would silently turn every stored Talk into a
    // Sadness.
    enum Activity {
        ShowJoy,
        ShowAnger,
        ShowSadness,
        Talk,
        Idle,
        ShowDisgust,
        ShowSurprise
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
        // browFlash is ADDED, not assigned: the emotions own _browRise and
        // animate it, so a backchannel that wrote to the same number would
        // erase whatever mood the face was wearing and could not be given
        // back afterwards.
        browOffset: Qt.vector2d(0, _head.eyeWidth * 0.465
                                   + _head._browRise + _head.browFlash)
        browAngle: _head._browAngle
        browSkew: _head._browSkew

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
        // Reaches UP into the cranium by the width of the chamfer: a rounded
        // jaw and a rounded skull meeting edge to edge make a groove across
        // the cheek, and the only way two chamfered boxes read as one is for
        // one to be inside the other where they meet. The face shader places
        // the mouth in world units from the box's bottom, so the extra height
        // moves nothing on the face. Estimated from the rest dimensions, not
        // read from the geometry - the geometry's width depends on this
        // height, and that would be a loop.
        height: baseHeight + jawStretch + _seamOverlap
        readonly property real _seamOverlap: {
            const own = bevel * Math.min(width, baseHeight, depth)
            const above = _upperHead.bevel
                        * Math.min(_upperHead.width, _upperHead.height, _upperHead.depth)
            return Math.max(own, above) * 1.15
        }
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
        mouthSkew: _head.mouthSkew

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
    // An expression is ten numbers, and every expression states ALL ten -
    // including the ones it leaves at rest. That is the design, and it is a
    // change from the three shared brow components this file used to pass
    // around: joy and sadness both asked for "raised brows" and so wore the
    // same brow, which is most of why a still of the two was hard to tell
    // apart. A shared component makes expressions differ in degree; a table
    // makes them differ in kind.
    //
    // An animation that does not name a channel does not reset it either - it
    // hands that channel to whatever the last face left there, and half a
    // sneer under a smile is an expression nobody can name.
    //
    // While a speechSource is active it overrides open/wide/round (see the
    // property bindings above); the corners, the skew and the lids stay with
    // the emotions, so a character can smile while it talks.
    //
    // What separates the six, in the order a viewer reads them:
    //
    //   the MOUTH  a smile, a frown, a shout, a sneer, or an O
    //   the BROWS  their ANGLE first and their height second - an angry V, a
    //              sad inverted V, a surprised pair up near the hairline, and
    //              for disgust one brow that disagrees with the other
    //   the LIDS   up from below is pleasure or revulsion, down from above is
    //              a glare or a droop, and neither of them is surprise
    //
    // Which lid moves is not interchangeable: getting it backwards produces a
    // face that is unmistakably wrong and impossible to name.

    component FaceParamAnim: NumberAnimation {
        target: _head
        duration: _head.toEmotionDuration
        easing.type: Easing.InOutQuad
    }

    // One expression, as the numbers that make it - so the six can be read as
    // a table and compared column by column, which is the only way to keep
    // them apart while they are being tuned.
    component Expression: ParallelAnimation {
        id: _expr

        // -1 a full frown, 1 a full smile.
        property real cornerLift: 0
        // The lopsided part: one corner climbs while the other stays pulled
        // down, and the whole mouth tilts with it.
        property real skew: 0
        property real open: 0
        property real wide: 0
        property real round: 0
        // Upper lid down: a glare or a droop.
        property real hood: 0
        // Lower lid up: a smile or a wince.
        property real squint: 0
        // Degrees. Positive drops the inner ends into a V.
        property real browAngle: 0
        // Height above the resting brow, in eye widths.
        property real browRise: 0
        // One brow up and the other down, in eye widths.
        property real browSkew: 0

        FaceParamAnim { property: "mouthCornerLift"; to: _expr.cornerLift }
        FaceParamAnim { property: "mouthSkew";       to: _expr.skew }
        FaceParamAnim { property: "_animMouthOpen";  to: _expr.open }
        FaceParamAnim { property: "_animMouthWide";  to: _expr.wide }
        FaceParamAnim { property: "_animMouthRound"; to: _expr.round }
        FaceParamAnim { property: "eyeHood";         to: _expr.hood }
        FaceParamAnim { property: "eyeSquint";       to: _expr.squint }
        FaceParamAnim { property: "_browAngle";      to: _expr.browAngle }
        // The two brow heights are in eye widths because that is the unit the
        // resting brow offset is written in - a head given bigger eyes raises
        // its brows the same distance relative to them.
        FaceParamAnim { property: "_browRise"; to: _expr.browRise * _head.eyeWidth }
        FaceParamAnim { property: "_browSkew"; to: _expr.browSkew * _head.eyeWidth }
    }

    // Neutral. Every channel at rest, which is also what every other
    // expression is measured against.
    Expression {
        id: _idleAnimation
        running: _head.activity === Head.Activity.Idle
    }

    // Joy. An open grin rather than a closed curve - a cartoon smile shows the
    // mouth - and the cheeks pushing the lower lids up. The squint is the one
    // that carries a smile when the mouth is hidden: behind a moustache, at a
    // distance, or turned away. The brows go up and stay nearly level, which
    // is what keeps this from reading as the sad face below.
    Expression {
        id: _joyAnimation
        running: _head.activity === Head.Activity.ShowJoy
        cornerLift: 1.0; open: 0.30; wide: 0.75
        squint: 0.60
        browAngle: 4; browRise: 0.34
    }

    // Sadness. The mouth shuts, narrows and turns fully down; no energy goes
    // into it at all. The brows are raised like joy's but hinge the other way
    // - the inner ends climb toward each other and the outer ends fall - and
    // that single sign flip is the difference between the two faces. Lids come
    // down from above, with just enough squint to stop it reading as sleepy.
    Expression {
        id: _sadnessAnimation
        running: _head.activity === Head.Activity.ShowSadness
        cornerLift: -1.0; round: 0.18
        hood: 0.52; squint: 0.16
        browAngle: -28; browRise: 0.30
    }

    // Anger. A shout: the mouth is open and wide as well as turned down, which
    // is what stops it being sadness with different eyebrows. The brows drive
    // into a V and sit lower than they rest, and the lids come down from above
    // to meet them. Nothing from below - an angry face is not a squeezed one,
    // it is a covered one.
    Expression {
        id: _angerAnimation
        running: _head.activity === Head.Activity.ShowAnger
        cornerLift: -0.85; open: 0.45; wide: 0.55
        hood: 0.50
        browAngle: 27; browRise: -0.04
    }

    // Disgust. The only face here whose two halves disagree, and it has to be:
    // symmetric, with the mouth down and the brows lowered, it is anger with
    // the volume turned down. The lip curls on one side, the mouth tilts with
    // it, one brow climbs while the other drops, and the lower lids come up as
    // if against a smell. The mouth stays small - a wide one is a shout.
    //
    // The pair is RAISED before it is skewed, and that is not decoration: the
    // resting brow bar already overlaps the top of the eye, so skewing from
    // rest drops one brow onto the white and the face reads as broken rather
    // than as sceptical - at 0.34 it covered an eye outright. Lifted by 0.14
    // first, the low brow lands about where a resting one does and only the
    // high one leaves home.
    Expression {
        id: _disgustAnimation
        running: _head.activity === Head.Activity.ShowDisgust
        cornerLift: -0.55; skew: 0.85; open: 0.18; wide: 0.10
        hood: 0.10; squint: 0.55
        browAngle: 8; browRise: 0.14; browSkew: 0.22
    }

    // Surprise. A round open mouth under high brows, and the one expression
    // with NO lid at all: eyes at their full height are half of what a viewer
    // reads as shock, and any hood or squint immediately turns it into one of
    // the other five. The brows stop below the hair - past about 0.7 eye
    // widths they reach the fringe and read as a shadow on it rather than as
    // eyebrows.
    Expression {
        id: _surpriseAnimation
        running: _head.activity === Head.Activity.ShowSurprise
        open: 0.85; round: 0.90
        browAngle: -6; browRise: 0.65
    }

    SequentialAnimation {
        id: _talkAnimation
        running: _head.activity === Head.Activity.Talk && !_head.speechActive
        loops: Animation.Infinite
        ParallelAnimation {
            FaceParamAnim { property: "_animMouthOpen"; to: 0.65; duration: _head.talkDuration }
            FaceParamAnim { property: "_animMouthWide"; to: 0.25; duration: _head.talkDuration }
        }
        ParallelAnimation {
            FaceParamAnim { property: "_animMouthOpen"; to: 0.08; duration: _head.talkDuration }
            FaceParamAnim { property: "_animMouthWide"; to: 0.1; duration: _head.talkDuration }
        }
    }

}
