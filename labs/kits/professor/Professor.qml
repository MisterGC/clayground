// (c) Clayground Contributors - MIT License, see "LICENSE" file
//
// Professor - someone to be taught by, rather than a strip of text to read.
//
// A flow already says the right words. What a text panel cannot do is what a
// teacher does without thinking: turn to the thing being discussed and put a
// finger on it. That is the whole reason this exists - the face is not the
// point, the POINTING is. Everything else here is in service of making the
// pointing believable enough to be read as deliberate.
//
// It is one Node, on purpose. Drop it inside a View3D, give it `view`, and it
// carries its own arrival, its own gesture and its own speech bubble; a lab
// should never have to assemble a professor out of parts.
//
// What it deliberately does NOT do: it says only what it is given. Everything
// else in these labs is an answer from a solver, and a character that started
// volunteering opinions would be the first thing on screen asserting authority
// it had not earned.
import QtQuick
import QtQuick3D
import Clayground.Canvas3D
import Clayground.Character3D
import Clayground.Lab
import Clayground.Sound

Node {
    id: root

    /*! The enclosing View3D. The speech bubble needs it to face the camera. */
    property var view: null

    /*! What the bubble is showing. Empty hides it. */
    property string line: ""

    /*!
        How many characters the bubble fits on a line before wrapping.

        Label3D draws its pill on one line and grows sideways for as long as
        the text does, which is right for a meter reading and wrong for a
        sentence: a lab's narration is eighty characters and the pill ran out
        under the tool palette. Wrapping happens here rather than in Label3D
        because a speech bubble is the one label in these labs that carries
        prose.
    */
    property int bubbleWidth: 46

    // Greedy, on spaces, and it never breaks a word: a hyphenated line in a
    // hand-lettered bubble looks like a rendering fault.
    readonly property string _wrapped: {
        const s = root.line
        if (s.length <= root.bubbleWidth)
            return s
        const words = s.split(" ")
        let out = "", run = ""
        for (const w of words) {
            if (run === "") { run = w; continue }
            if (run.length + 1 + w.length <= root.bubbleWidth) { run += " " + w; continue }
            out += (out === "" ? "" : "\n") + run
            run = w
        }
        return out + (out === "" ? "" : "\n") + run
    }

    // --- where it is ----------------------------------------------------------
    // The professor owns its own position, through `stand` rather than through
    // `position`: travelling has to animate something, and something a lab has
    // bound is not available to animate. Set `stand` to place one; call
    // travelTo() to send it somewhere.

    /*! The spot on the ground the professor occupies. */
    property vector3d stand: Qt.vector3d(0, 0, 0)

    /*! Which way it faces, in degrees. A professor faces +Z at 0. */
    property real heading: 0

    /*! How fast it travels, in world units per second. */
    property real travelSpeed: 3.2

    /*! How high it rides while travelling, as a fraction of its own height. */
    property real hoverRise: 0.16

    /*! Whether it travels on a board at all. False just slides it. */
    property bool hoverboard: true

    /*! True from the moment it lifts off until it has landed. */
    readonly property bool travelling: _trip.running

    /*! Emitted on landing, with the spot it landed on. */
    signal arrived(vector3d at)

    position: Qt.vector3d(root.stand.x, root.stand.y + root._hover, root.stand.z)
    // Leaning into the direction of travel is the only motion cue there is -
    // the legs do not move - so it does the work a walk cycle would.
    eulerRotation: Qt.vector3d(root._lean, root.heading, 0)

    /*!
        Flies to \a worldPos, landing on it. Ignored while away.

        The gesture is dropped at take-off on purpose: a point is solved once,
        against the frame the professor stood in when it was asked for, so an
        arm held through a flight ends up aimed at nothing. Point again after
        \l arrived - which is also the honest choreography, since a person
        walks over first and points second.
    */
    function travelTo(worldPos) {
        if (!_present || !worldPos) return
        _trip.stop()
        stopGesture()
        _from = root.stand
        _to = worldPos
        const dx = _to.x - _from.x
        const dz = _to.z - _from.z
        const far = Math.sqrt(dx * dx + dz * dz)
        // Turn to face the way it is going, unless it is going nowhere in
        // particular - a spin on the spot for a 2 cm hop looks like a fault.
        _headTo = far > root.standHeight * 0.25
                ? root.heading + _shortWay(Math.atan2(dx, dz) * 180 / Math.PI - root.heading)
                : root.heading
        _flightMs = Math.max(320, Math.min(4000, far / Math.max(0.1, root.travelSpeed) * 1000))
        _trip.restart()
    }

    /*! Turns on the spot to face \a worldPos, without going anywhere. */
    function turnTo(worldPos) {
        if (!worldPos) return
        const dx = worldPos.x - root.stand.x
        const dz = worldPos.z - root.stand.z
        if (Math.abs(dx) < 1e-4 && Math.abs(dz) < 1e-4) return
        _turn.to = root.heading + _shortWay(Math.atan2(dx, dz) * 180 / Math.PI - root.heading)
        _turn.restart()
    }

    /*!
        Nominal body height, in world units.

        Nominal because the plugin treats it as an input to its proportion
        tables rather than as a measurement - see \l standHeight for what
        the professor actually is. A lab that cares where the head ends up
        should read that one.
    */
    property real height3d: 1.48

    /*!
        How much bigger the head is than the plugin will draw it.

        The plugin's proportions bottom out at four heads to a body, at
        maturity 0. A cartoon old man is drawn at three or fewer, and that
        difference is most of what makes a silhouette funny rather than
        merely short - so the head is scaled past the floor here.

        It scales the head NODE rather than restating the six dimensions the
        plugin derives from its own parameters. That is the whole reason the
        beard, the glasses and the hair grow with it: they are parented to
        that node, so they are inside the same transform.
    */
    property real headScale: 1.69

    /*!
        How tall the professor actually stands.

        Measured off the character rather than off \l height3d, which is
        NOT it: \c bodyHeight is a nominal figure the plugin feeds into its
        proportion tables, and the parts it derives sum to about 1.3 times
        it. Anything positioned from height3d - a camera, a speech bubble -
        aims at the chest.
    */
    readonly property real standHeight:
        _char.height + (root.headScale - 1) * _char.headHeight

    /*!
        Eye height above the professor's feet - where a camera that wants to
        look it in the face should aim.
    */
    readonly property real faceY:
        root.standHeight - _char.headHeight * root.headScale * 0.38

    // --- how old the professor looks -----------------------------------------
    // Cartoonists draw the old much the way they draw the young: short, with a
    // head too big for the body and no neck to speak of. What carries the age
    // is not the proportion, it is the grey, the beard and the glasses sitting
    // on top of it. So the SHAPE here is deliberately childlike and every
    // signifier of age is added over it.
    //
    // These are the character plugin's own parameters, passed through under its
    // own names rather than renamed - `maturity` is what the plugin calls the
    // knob that decides how many head-heights fit in a body, and low is the big
    // head.

    /*!
        Heads-tall. Low means a big head and short legs.

        Middling rather than low, which looks like the wrong end of the
        knob for a cartoon: the big head comes from \l headScale instead,
        and leaving maturity up keeps the limb proportions of an adult
        under it. A low value here gave a toddler wearing a beard.
    */
    property real maturity: 0.64

    /*! Roundness. Also shortens the neck, which is most of the effect. */
    property real mass: 0.32

    /*! How much hair. Grey, but a professor still has plenty of it. */
    property real hairVolume: 1.0

    /*! Bigger with age, and worth exaggerating under a pair of glasses. */
    property real noseSize: 1.73

    /*!
        Which beard: "full", "walrus", "goatee", "chin" or "none".

        The default is the walrus, because it is the one that leaves the
        chin bare - and a big moustache over a visible, smiling mouth is a
        friendlier face than a grey mass with a slot in it.
    */
    property string beardStyle: "walrus"

    /*! 0 is clean-shaven, 1 is a full professor. */
    property real beardLength: 0.62

    /*!
        Which hair: "wild", "swept", "tidy", "ring" or "none". "wild" is the
        crown of spikes that is most of what makes a cartoon professor read
        as a professor rather than as a grandfather.
    */
    property string hairStyle: "wild"

    /*!
        The resting face: "happy", "neutral", "sad" or "cross".

        Happy by default, and deliberately so. This character exists to
        offer to teach you something; a neutral face on a figure that
        appears beside your work reads as supervision.

        Speech with an emotion temporarily takes the face over and hands
        it back afterwards - but it does that by ASSIGNING faceActivity,
        which breaks this binding for good. Professor.say() therefore
        never passes an emotion.
    */
    property string mood: "happy"

    /*! Whether the professor wears glasses. */
    property bool spectacles: true

    /*!
        How rounded every box he is made of is - a chamfer on each edge, as a
        fraction of that box's shortest side.

        Free: it is more triangles on the same single draw call per box, and
        vertices are not what a scene like this is bound by. 0.15 takes the
        hardness off without turning him into a pebble; the plugin describes
        0.3 as nearly spherical, and much past 0.2 the chamfer starts eating
        into the flat front of the face the eyes are drawn on.

        It reaches the kit's own beard, hair and spectacles as well as the
        character's own boxes: those three reparent themselves into the head
        node, so the character's tree walk finds them there.
    */
    property real roundness: 0.15

    /*!
        Eye size, and with it how much forehead is left.

        This looks like a cosmetic knob and is not. The plugin's cranium is
        about 1.4 times wider than it is tall, and it sizes the eyes off the
        WIDTH - so eyes much above 1.0 put the lenses within a hair of the
        crown, Hair refuses to grow anything below them, and every cut comes
        out as a bald patch with a fringe. 1.15 read better on its own and
        cost the professor its hair; this is the trade, written down.
    */
    property real eyeSize: 1.0

    /*!
        Whether the hands have fingers. Opt-in, because it is ten more boxes
        per hand and a lab whose professor is only ever seen across a board
        does not need them.

        They are not decoration. A block hand at the end of a raised arm ends
        in an ambiguous stub; an extended index finger is the clearest signal
        there is that a gesture means "that thing there". Together with the
        forced elbow bend in PointAnim, that is what keeps a raised point from
        reading as a salute - see the note in PointAnim's _apply().
    */
    property bool detailedHands: true

    /*!
        What the hands do when they are NOT pointing: "relax", "open" or
        "thumbsUp". The pointing hand always overrides this with "point".
    */
    property string handPose: "relax"

    /*!
        How much bigger the hands are than the proportion tables give.

        The gestures are the reason this character exists and the hands are
        where they happen, so they are drawn at the size a cartoonist would
        draw them. Fed straight to \c Character.handScale, which is where the
        reasoning now lives.
    */
    property real handScale: 1.3

    /*!
        White gloves, the way a cartoon does it - the hands get their own
        colour and a cuff at each wrist.

        Off by default, because it is a strong look and a lab may not want it.
        On, it is the cheapest legibility this character has: a bare hand is
        the same colour as the face and has to be found before the gesture can
        be read, and a pointing finger nobody found in time is a finger that
        pointed at nothing.
    */
    property bool gloves: false

    /*! Colour of the gloves, when \l gloves is on. */
    property color gloveTone: LabTheme.sheet

    property color hairTone: LabTheme.muted        // warm grey, not white
    property color skinTone: LabTheme.clay
    property color coatTone: LabTheme.forest       // tweed, near enough
    property color trouserTone: LabTheme.inkFaint  // grey flannel

    /*! True between the end of the arrival puff and the start of the exit. */
    readonly property bool present: _present

    /*! True once a gesture has arrived - the cue to start talking. */
    readonly property bool settled: _point.settled

    /*!
        What the hands are doing: "point", "thumbsUp", "talk", or "" for
        nothing.

        Set the moment a gesture is asked for, while the arm is still on its
        way there - which is what makes it the thing to assert on. The joint
        angles ease in over settleMs, so a test that reads those immediately
        after the call is reading the pose the professor has just left.
    */
    readonly property string gesture: _point.activeGesture

    /*! Which hand is doing it: "left", "right" or "". */
    readonly property string gestureHand: _point.activeHand

    /*! Where the bubble is pinned, so a lab can put something else there. */
    readonly property vector3d headAnchor: _char.scenePosition.plus(
        Qt.vector3d(0, root.standHeight * 0.95 * root._grow, 0))

    /*! The character, for a lab that wants to reach past this component. */
    readonly property var character: _char

    /*!
        Arrives. The puff fires first and the body swells out of it a beat
        later, so the cloud reads as the cause and not as decoration around
        someone who was already standing there.
    */
    function appear() {
        if (_present) return
        _present = true
        _puff.burst()
        _in.restart()
    }

    /*!
        Leaves. The body collapses BEFORE the cloud, for the same reason in
        reverse: the puff has to be what is left behind.
    */
    function vanish() {
        if (!_present) return
        _present = false
        quiet()
        stopGesture()
        // Mid-flight departures land where they were: leaving the hover height
        // set would put the next arrival's puff in the air.
        _trip.stop()
        _hover = 0
        _lean = 0
        _out.restart()
    }

    /*! Turns to \a worldPos and points at it. Ignored while away. */
    function pointAt(worldPos) {
        if (!_present) return
        _point.gesture = "point"
        _point.hand = "auto"
        _point.target = worldPos
        _point.active = true
    }

    /*!
        Gives a thumbs up with \a which hand ("right" by default, "left" if
        asked). Ignored while away.

        Approval, not decoration: it is the answer to "did I get that right",
        which is the question a lab flow asks most often and the one a line
        of text answers least convincingly.
    */
    function thumbsUp(which) {
        if (!_present) return
        _point.gesture = "thumbsUp"
        _point.hand = which === undefined ? "right" : which
        _point.target = null
        _point.active = true
    }

    /*!
        Talks with the hands: a loose two-beat gesticulation that runs until
        something else is asked for. Ignored while away.

        The other half of pointing. A finger held on a part for the length of
        a paragraph turns the teacher into a signpost; the point has said
        "this one" within a second or two, and everything after that is
        explanation, which people deliver facing whoever they are explaining
        it to. Pair it with \l faceViewer().

        It replaces any point or thumbs-up: one driver owns these joints.
    */
    function gesticulate() {
        if (!_present) return
        _point.gesture = "talk"
        _point.hand = "auto"
        _point.target = null
        _point.active = true
        // Long enough to cover the line being said, and never open-ended.
        _gestureCap.interval = Math.max(root.gestureMaxMs,
                                        _mouth.running ? _mouth.interval : 0)
        _gestureCap.restart()
    }

    /*!
        \qmlproperty int Professor::gestureMaxMs
        rief The longest a talking gesture runs with nothing to end it.

        The end of a line is what normally puts the hands down, and there are
        three ways a line can end: a mouth timer, a narration clip, a speech
        engine. Each of them can fail to arrive - a clip that will not decode,
        an engine that never starts, or a caller that asked for gesticulation
        without saying anything at all. Then the professor stands there waving
        for the rest of the session, which is the one outcome worse than not
        gesturing. This is the floor under all three.
    */
    property int gestureMaxMs: 12000

    Timer {
        id: _gestureCap
        onTriggered: if (root.gesture === "talk") root.stopGesture()
    }

    /*!
        Turns to face the camera, so the next thing said is said to the
        reader rather than to the board.

        The whole body turns, because this character has no separate neck
        aim - see \l turnTo(). Needs \l view.
    */
    function faceViewer() {
        if (!root.view || !root.view.camera) return
        turnTo(root.view.camera.scenePosition)
    }

    /*!
        Sets the lasting face from a script emotion name.

        The professor's face is its \l mood, so this maps the performance
        vocabulary onto it: "happy", "sad", "angry" (worn as \c cross - a
        professor is cross, not furious) and "neutral" or "" back to neutral.
        Unknown names are ignored rather than guessed at.

        This is the verb \l Performance calls for an \c{*emotion*} cue, so a
        script's \c{*happy*} works on the professor exactly as it does on a
        plain \l Character.
    */
    function setEmotion(name) {
        const n = ("" + name).toLowerCase()
        if (n === "happy") root.mood = "happy"
        else if (n === "sad") root.mood = "sad"
        else if (n === "angry") root.mood = "cross"
        else if (n === "neutral" || n === "") root.mood = "neutral"
    }

    /*! Drops the arm and lets the character stand normally again. */
    function stopGesture() {
        _gestureCap.stop()
        _point.active = false
        _point.target = null
        _point.gesture = "point"
        _point.hand = "auto"
    }

    /*!
        Shows \a what in the bubble and moves the mouth, without asking for
        any audio.

        The verb for narration. \l say() goes through the character's speech
        engine, which means text-to-speech - fine for a character that is
        meant to be heard, wrong for a lab whose flow the reader is working
        through at their own pace and possibly in an open-plan office.

        The mouth runs for about as long as the line takes to read and then
        goes back to the resting face, so the professor stops talking while
        the text stays up - which is what a person does.

        \a clip is optional: a url to a pre-rendered narration wav. Given one,
        the professor plays it and the mouth runs for the recording's real
        length instead of an estimate. This is not \l say() - nothing is
        synthesised at runtime, the audio was made in advance and the lab
        decides which file belongs to which line.
    */
    function tell(what, clip) {
        root.line = what
        const url = (clip === undefined || clip === null) ? "" : "" + clip
        _voice.stop()
        _voice.source = url
        _talking = (what !== undefined && what !== "")

        // Two ways to know when the mouth stops. With a clip it is the clip:
        // pre-rendered narration is the only thing here that knows how long
        // the sentence actually takes, and guessing next to a recording that
        // disagrees is worse than not moving the mouth at all. The timer stays
        // armed anyway, on a generous estimate, because a file that fails to
        // decode emits nothing at all and would leave the jaw open for the
        // rest of the session.
        _mouth.interval = Math.max(900, Math.min(30000,
            300 + root.speechRateMs * ("" + what).length))
        _mouth.restart()
        if (url !== "")
            _voice.play()
    }

    /*! Clears the bubble, closes the mouth and stops any narration clip. */
    function quiet() {
        root.line = ""
        _mouth.stop()
        _voice.stop()
        _voice.source = ""
        _speechEnded()
    }

    /*! True while a line is still being said - by mouth, clip or engine. */
    readonly property bool talking: _talking

    property bool _talking: false

    /*!
        \qmlproperty int Professor::speechRateMs
        \brief Milliseconds per character of narration.

        The one rate. It used to be guessed twice - once here for the mouth
        and once in FlowGuide for how long to hold a point - and the two
        guesses disagreed, so on a short line the mouth finished BEFORE the
        professor turned round and started gesturing: lips with no hands, then
        hands with no lips. Anything that needs to know how long a line lasts
        reads \l lineMs.

        72 ms is measured rather than chosen: the pre-rendered narration for
        the electronics lab runs at about fourteen characters of text per
        second of speech, over eighty-eight seconds of audio.
    */
    property int speechRateMs: 72

    /*!
        How long the line currently being said lasts, in ms.

        The clip's real duration once that is known, the estimate until then,
        and stale after the line ends - read it while \l talking.
    */
    readonly property int lineMs: _mouth.interval

    // The sentence is over: shut the mouth, and put the hands down with it.
    //
    // The hands are the part that has to be said out loud. Talking body
    // language is only talking body language while something is being said -
    // left running past the end of the line it is a person miming at an empty
    // room, and it ran for the whole rest of the step, because the gesture was
    // started by the choreography and only ever stopped by the next one.
    // Anything else the professor is doing with its arms is left alone: a
    // point outlives the sentence that introduced it, on purpose.
    function _speechEnded() {
        root._talking = false
        if (_point.gesture === "talk" && _point.active)
            stopGesture()
    }

    Timer {
        id: _mouth
        onTriggered: root._speechEnded()
    }

    /*!
        \qmlproperty real Professor::voiceVolume
        \brief How loud a narration clip plays, 0 to 1.
    */
    property real voiceVolume: 1.0

    /*! True while a narration clip is playing. */
    readonly property bool voicing: _voice.playing

    /*! How long the current clip runs, in ms; 0 before it is known. */
    readonly property int voiceMs: _voice.duration

    // Pre-rendered narration. Music rather than Sound: a line has to be
    // stoppable when the step changes, and it is the wrapper that reports a
    // duration and an end.
    Music {
        id: _voice
        volume: root.voiceVolume
        lazyLoading: true
        onFinished: root._speechEnded()
        // The estimate above is a backstop; once the real length is known,
        // use it. Plus a beat, so the mouth does not shut on the last word.
        onDurationChanged: {
            if (_voice.duration > 0 && root._talking) {
                _mouth.interval = _voice.duration + 250
                _mouth.restart()
            }
        }
    }

    /*!
        Says \a what out loud. Text AND text-to-speech: the bubble shows it,
        the mouth is lip-synced to the audio, and the machine talks. Use
        \l tell() for a lab that should stay silent.

        Emotion is deliberately not passed through. The character's talking
        body language drives both upper arms in a loop, which fights a held
        point and wins - measured at 41 degrees of aim error. Suppressing the
        arm-waving keeps the gesture; the face still carries the tone.
    */
    function say(what) {
        root.line = what
        _char.speechBodyLanguage = false
        _talking = true
        _saying = true
        _sayStarted = false
        _char.say(what)
    }

    // Whether a spoken line is outstanding. The engine reports `speaking`, but
    // it is false BEFORE it starts as well as after it ends, so the flag is
    // what tells the two apart.
    property bool _saying: false

    // Whether the engine has actually begun the line we are waiting on.
    //
    // Character.say() stops any previous line as its first act, so asking for
    // a second line drives `speaking` false - the OLD line ending, arriving
    // after the new one was requested, and indistinguishable from the new one
    // ending unless the start is tracked. Taken at face value it cleared
    // `talking` while the character was about to speak, and the real end of
    // that line was then never seen. The transition only counts as an ending
    // if a beginning was seen first; a line that never begins is what
    // gestureMaxMs is for.
    property bool _sayStarted: false

    Connections {
        target: _char
        enabled: root._saying
        function onSpeakingChanged() {
            if (_char.speaking) {
                root._sayStarted = true
                root._talking = true
                return
            }
            if (!root._sayStarted)
                return
            root._saying = false
            root._sayStarted = false
            root._speechEnded()
        }
    }

    /*! Stops mid-sentence and clears the bubble, spoken or written. */
    function hush() {
        _char.stopSpeaking()
        quiet()
    }

    // --- travelling -----------------------------------------------------------

    property real _hover: 0
    property real _lean: 0
    property vector3d _from: Qt.vector3d(0, 0, 0)
    property vector3d _to: Qt.vector3d(0, 0, 0)
    property real _headTo: 0
    property int _flightMs: 600

    // Turning 350 degrees to end up where turning -10 would have got you is
    // the single most obvious way for a rig to look like a rig.
    function _shortWay(delta) {
        return ((delta % 360) + 540) % 360 - 180
    }

    SequentialAnimation {
        id: _trip

        // Power up and turn before moving. A board that starts sliding before
        // it has left the ground reads as a bug in the floor.
        ParallelAnimation {
            NumberAnimation {
                target: root; property: "_hover"
                to: root.standHeight * root.hoverRise
                duration: 260; easing.type: Easing.OutCubic
            }
            NumberAnimation {
                target: root; property: "heading"
                to: root._headTo; duration: 300; easing.type: Easing.InOutQuad
            }
            NumberAnimation {
                target: root; property: "_lean"
                to: 9; duration: 260; easing.type: Easing.OutCubic
            }
        }

        Vector3dAnimation {
            target: root; property: "stand"
            to: root._to
            duration: root._flightMs
            // Eased at both ends, so the lean it is already holding reads as
            // the acceleration rather than as a fixed tilt.
            easing.type: Easing.InOutQuad
        }

        ParallelAnimation {
            NumberAnimation {
                target: root; property: "_hover"
                to: 0; duration: 300; easing.type: Easing.InCubic
            }
            NumberAnimation {
                target: root; property: "_lean"
                to: 0; duration: 300; easing.type: Easing.OutCubic
            }
        }

        ScriptAction { script: root.arrived(root.stand) }
    }

    NumberAnimation {
        id: _turn
        target: root; property: "heading"
        duration: 320; easing.type: Easing.InOutQuad
    }

    Hoverboard {
        visible: root.hoverboard
        length: root.standHeight * 0.46
        deckTone: LabTheme.ink
        glowTone: LabTheme.secondary
        // Tied to the height rather than to a state flag: the board is exactly
        // as present as the professor is off the ground, which means it can
        // never be left switched on under someone standing on the floor.
        energy: root.standHeight > 0
                ? Math.min(1, root._hover / (root.standHeight * root.hoverRise))
                : 0
        scale: Qt.vector3d(root._grow, root._grow, root._grow)
    }

    // --- arrival ------------------------------------------------------------

    property bool _present: false
    // 0 while away, 1 while standing. Scaled, not hidden: a professor that
    // blinked into existence at full size would need no puff at all.
    property real _grow: 0

    // The two of these must stop each other, and it is not tidiness.
    //
    // Arriving takes 470 ms and leaving 200 ms, so a flow started and stopped
    // inside half a second used to run both: the exit finished first, the
    // arrival then grew the body back, and the professor stood there at full
    // size with `present === false` - a state vanish() refuses to act on,
    // because it early-returns when it is already away. Nothing could remove
    // it for the rest of the session. One misclick is enough.

    SequentialAnimation {
        id: _in
        onStarted: _out.stop()
        // the cloud gets a moment on its own before anything is inside it
        PauseAnimation { duration: 90 }
        NumberAnimation {
            target: root; property: "_grow"; to: 1.0
            duration: 380; easing.type: Easing.OutBack; easing.overshoot: 1.7
        }
    }

    SequentialAnimation {
        id: _out
        onStarted: _in.stop()
        NumberAnimation {
            target: root; property: "_grow"; to: 0.0
            duration: 200; easing.type: Easing.InBack; easing.overshoot: 1.4
        }
        ScriptAction { script: _puff.burst() }
    }

    Puff {
        id: _puff
        // Not a smoke colour. The ground these labs stand on is pale paper,
        // and a grey cloud on it is a cloud nobody sees; the accent reads as
        // "something happened here" and belongs to the palette.
        tone: LabTheme.secondary
        radius: root.height3d * 0.62
    }

    // --- the character ------------------------------------------------------

    // ParametricCharacter, not Character: bodyHeight is what lets a lab say
    // how tall its professor is in ITS units, and the rest of the dimensions
    // follow from it. Everything Character offers - speech, the arms the
    // gesture drives, the activity - is inherited.
    ParametricCharacter {
        id: _char
        name: "professor"
        // The squash is the difference between a model being scaled and a
        // body arriving: it lands wide and low, then stands up.
        scale: {
            const g = root._grow
            const squash = 1 + (1 - Math.min(1, g)) * 0.35
            return Qt.vector3d(g * squash, g / squash, g * squash)
        }
        visible: root._grow > 0.001

        bodyHeight: root.height3d
        // High rather than Auto: the professor's whole job is pointing at
        // things, and Auto measures apparent size against a threshold it
        // reaches only in a close shot. A lab is watched from the working
        // distance and the finger has to be there anyway.
        detail: root.detailedHands ? Character.Detail.High : Character.Detail.Low
        handScale: root.handScale
        gloves: root.gloves
        gloveColor: root.gloveTone
        roundness: root.roundness
        realism: 0.0                   // the labs are drawn, not photographed
        maturity: root.maturity
        mass: root.mass
        muscle: 0.3                    // an academic, not an athlete
        femininity: 0.2
        // Nought, and the kit's Hair draws instead. The head's own hair is
        // four slabs around the skull with one knob to inflate them, and it
        // would draw straight through anything put on top of it.
        hair: 0
        nose: root.noseSize
        eyes: root.eyeSize
        chinForm: 0.35                 // a rounder jaw, which a beard sits on

        skinColor: root.skinTone
        hairColor: root.hairTone
        torsoColor: root.coatTone
        armColor: root.coatTone
        hipColor: root.trouserTone
        legColor: root.trouserTone

        // Idle, and left there. Walking, running, using and fighting all own
        // the arms, and switching activity mid-gesture restarts the idle
        // animation, which zeroes the pose.
        activity: Character.Activity.Idle

        // The face is a separate activity from the body, so a professor can
        // stand still and still be pleased to see you.
        // Talking wins while it lasts - the mouth cannot both hold a smile
        // and flap - and the face drops back to the mood underneath when the
        // line is finished.
        faceActivity: root._talking ? Head.Activity.Talk
                    : root.mood === "happy" ? Head.Activity.ShowJoy
                    : root.mood === "sad" ? Head.Activity.ShowSadness
                    : root.mood === "cross" ? Head.Activity.ShowAnger
                                            : Head.Activity.Idle
    }

    // The oversized head. A Binding rather than a property assignment because
    // the head belongs to the character, not to this file - and because the
    // node's origin sits at the top of the neck, so scaling it grows the head
    // upward and outward instead of sinking it into the shoulders.
    Binding {
        target: _char.head
        property: "scale"
        value: Qt.vector3d(root.headScale, root.headScale, root.headScale)
    }

    // The oversized hands are the plugin's own Character.handScale now - this
    // kit reached into the wrist joint with a Binding until the plugin grew
    // the property, on the same principle and by the same means.

    // --- the signifiers of age ------------------------------------------------
    // Both parent themselves to the character's head, so they ride it when the
    // head turns during a gesture and they shrink with the body when it arrives
    // in its puff. Declared here rather than inside the character because the
    // plugin has no slot for either - see the kit README.

    Hair {
        character: _char
        tone: root.hairTone
        style: root.hairStyle
        volume: root.hairVolume
    }

    Beard {
        character: _char
        tone: root.hairTone
        style: root.beardStyle
        length: root.beardLength
        fullness: 0.72
        moustache: true
    }

    Spectacles {
        character: _char
        visible: root.spectacles
        frameTone: LabTheme.ink
        // barely there: a lens you can see through is a lens that does not
        // hide the eyes, and the eyes are where the character reads from
        lensTone: Qt.rgba(LabTheme.sheet.r, LabTheme.sheet.g, LabTheme.sheet.b, 0.22)
        slip: 0.2
    }

    // --- the hands ------------------------------------------------------------
    // The plugin's own articulated hands now, rather than the copy this kit
    // carried until the plugin grew one. They live inside Arm, so there is
    // nothing to attach here - only the pose to feed them.
    //
    // Character wires Arm.handPose to its own GestureAnim, and the professor
    // does not use that one: PointAnim drives these arms, with a beat table
    // and a silhouette policy tuned against this exact body. So the pose is
    // overridden, the same way the oversized hands and head are. Whichever arm
    // the gesture picked gets the pointing finger and the other keeps whatever
    // the lab asked for.

    Binding {
        target: _char.rightArm
        property: "handPose"
        value: _point.rightHandPose !== "" ? _point.rightHandPose : root.handPose
    }

    Binding {
        target: _char.leftArm
        property: "handPose"
        value: _point.leftHandPose !== "" ? _point.leftHandPose : root.handPose
    }

    // --- the gesture --------------------------------------------------------

    PointAnim {
        id: _point
        character: _char
        // no point aiming a body that is still swelling out of a cloud
        active: false
        settleMs: 420
    }

    // --- what it is saying --------------------------------------------------
    // In the scene rather than in the chrome: a bubble over the professor's
    // head belongs to the professor, whereas a panel at the bottom of the
    // window belongs to the application. That difference is the whole point of
    // having a character at all.
    Label3D {
        // A SIBLING of the professor, not a child of it. Label3D places itself
        // at anchorNode.scenePosition + labelOffset - a scene position - and
        // assigning a scene position to a child of the thing it is anchored to
        // applies that thing's transform twice: the bubble left the professor
        // the moment it started travelling and hung over the spot it had come
        // from. It also has no business inheriting the lean.
        parent: root.parent
        view: root.view
        anchorNode: root
        // clear of the head, not level with it: at head height the skull
        // occludes the middle of its own speech bubble
        // Clear of the head, and further clear the taller the bubble is: the
        // pill is centred on this point, so a three-line one hangs half its
        // own height lower than a one-line one and lands on the hair.
        labelOffset: Qt.vector3d(
            0, root.standHeight * root._grow
               * (1.12 + 0.11 * (root._wrapped.split("\n").length - 1)), 0)
        text: root._wrapped
        visible: root.line !== "" && root._grow > 0.9
        sizeMode: Label3D.Screen
        // Screen mode holds the PILL to a fixed height on screen, so a bubble
        // that wrapped onto three lines rendered each of them at a third the
        // size. The target has to grow with the line count or wrapping makes
        // the text smaller instead of narrower.
        screenHeight: 24 * root._wrapped.split("\n").length
        // A radius, spelled out, because Label3D's default is -1 and that
        // means "half the height" - a lozenge, which is right for the
        // one-line callouts it was built for and wrong here. The text is a
        // rectangle; on a five-line bubble the caps have a 75-pixel radius
        // and the corners of that rectangle end up outside the shape, so the
        // first and last lines run off the ends of their own bubble.
        labelStyle.radius: 20
        labelStyle.paddingH: 20
        labelStyle.paddingV: 12
    }
}
