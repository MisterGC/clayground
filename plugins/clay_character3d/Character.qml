// (c) Clayground Contributors - MIT License, see "LICENSE" file

// Import Strategy:
// - Subdirectories use relative imports (e.g., 'import ".."' to access root)
// - This enables hot-reloading in sandbox development
// - Example files use module imports to demonstrate proper usage
// - Internal components use relative imports for cross-directory access

import QtQuick
import Clayground.Canvas3D
import "bodyparts"
import "animation"

pragma ComponentBehavior: Bound

/*!
    \qmltype Character
    \inqmlmodule Clayground.Character3D
    \inherits BodyPartsGroup
    \brief A fully animated 3D humanoid character with modular body parts.

    Character is the main component for creating 3D characters with procedural
    animations. It provides extensive customization through body part dimensions,
    colors, and automatic walk/run/idle animations.

    The character's origin is at ground level (Y=0 at bottom of feet), centered
    horizontally. Movement speeds are derived from animation geometry to ensure
    foot movement matches character movement.

    Example usage:
    \qml
    import Clayground.Character3D

    Character {
        name: "hero"
        activity: Character.Activity.Walking
        skinColor: "#d38d5f"
        torsoColor: "#4169e1"
    }
    \endqml

    \sa BodyPartsGroup, ParametricCharacter
*/
BodyPartsGroup {
    id: _character

    // Character origin is at ground level, center of body
    // Y=0 is at the bottom of the feet

    /*!
        \qmlproperty string Character::name
        \brief Character identifier name.
    */
    property string name: "unknown"

    /*!
        \qmlproperty real Character::walkSpeed
        \brief Walking speed derived from animation geometry.
    */
    readonly property real walkSpeed: _walkAnim.derivedWalkSpeed

    /*!
        \qmlproperty real Character::runSpeed
        \brief Running speed derived from animation geometry.
    */
    readonly property real runSpeed: _runAnim.derivedRunSpeed

    /*!
        \qmlproperty int Character::idleCycleDuration
        \brief Duration of the idle animation cycle in milliseconds.
    */
    property alias idleCycleDuration: _idleAnim.duration

    // Bounding box dimensions (derived from body parts)
    width: Math.max(shoulderWidth, waistWidth, hipWidth)
    height: footHeight + legHeight + hipHeight + torsoHeight + neckHeight + headHeight
    depth: Math.max(torsoDepth, hipDepth)

    // ============================================================================
    // ACTIVITY & BEHAVIOR PROPERTIES
    // ============================================================================
    enum Activity {
        Idle,
        Walking,
        Running,
        Using,
        Fighting
    }
    /*! Current activity state. Use Character.Activity enum: Idle, Walking, Running, Using, Fighting. */
    property int activity: Character.Activity.Idle

    /*! Current movement speed based on activity. */
    readonly property real currentSpeed: {
        if (activity === Character.Activity.Running) return _runAnim.derivedRunSpeed;
        if (activity === Character.Activity.Walking) return _walkAnim.derivedWalkSpeed;
        return 0;
    }
    /*! Current facial expression activity. */
    property alias faceActivity: _head.activity

    // ============================================================================
    // SPEECH & LIP-SYNC
    // ============================================================================

    /*!
        \qmlproperty Speech Character::speech
        \brief The character's speech engine for advanced configuration
               (volume, rate, pitch) and signals (started/finished).
    */
    readonly property Speech speech: _speech

    /*!
        \qmlproperty bool Character::speaking
        \brief True while the character is speaking (text or audio),
               including between the segments of annotated text.
    */
    readonly property bool speaking: _speech.speaking || _sayQueue.active

    /*!
        \qmlproperty bool Character::speechBodyLanguage
        \brief Whether emotional speech may use body language gestures.

        When true and the character is otherwise idle, saying something
        with an emotion plays a matching gesture loop (slumped sway when
        sad, bouncy arms when happy, agitated pumping when angry). The
        gestures never override other activities - a walking or fighting
        character keeps its body animation and only face and voice carry
        the emotion.
    */
    property bool speechBodyLanguage: true

    /*!
        \qmlproperty string Character::speechEmotion
        \readonly
        \brief The emotion of the current speech ("happy", "sad", "angry"
               or empty for neutral).
    */
    readonly property string speechEmotion: _emotionCtl.current

    /*!
        \qmlmethod void Character::say(string what, string emotion)
        \brief Makes the character say something with lip-synced mouth movement.

        Pass either plain text (spoken via text-to-speech when available,
        otherwise the mouth animates silently) or a path/URL to a wav/mp3
        file which is played back while the mouth follows the audio.

        The optional emotion ("happy", "sad" or "angry") colors the
        conversation: facial expression, voice pitch/rate (for TTS) and -
        if the character is idle and \l speechBodyLanguage is enabled -
        matching body language. Everything is restored when the speech
        finishes.

        Text may switch the emotion mid-speech with inline annotations:
        \qml
        npc.say("*angry* Get off my ground! *happy* Just kidding, come in.")
        \endqml
        Recognized annotations are *happy*, *sad*, *angry* and *neutral*
        (plus the aliases *joy*, *anger*, *sadness* and *calm*); each one
        applies from where it appears. The emotion argument sets the tone
        before the first annotation. Unknown annotations are left in the
        text untouched.
    */
    function say(what, emotion) {
        _sayQueue.cancel()
        // End any previous speech first: its finished() handling clears
        // the old emotion, so the ones applied by the queue survive.
        _speech.stop()
        _sayQueue.segments = _sayQueue.parse("" + what,
                                             emotion === undefined ? "" : emotion)
        _sayQueue.index = 0
        _sayQueue.next()
    }

    /*!
        \qmlmethod void Character::stopSpeaking()
        \brief Interrupts the current speech output.
    */
    function stopSpeaking() {
        _sayQueue.cancel()
        _speech.stop()
    }

    // Splits annotated text into (emotion, text) segments and speaks
    // them one after another, re-coloring face/voice/body per segment.
    QtObject {
        id: _sayQueue
        property var segments: []
        property int index: 0
        property bool active: false

        function parse(text, baseEmotion) {
            const known = {
                happy: "happy", joy: "happy",
                sad: "sad", sadness: "sad",
                angry: "angry", anger: "angry",
                neutral: "", calm: ""
            }
            const re = /\*(\w+)\*/g
            let result = []
            let emotion = baseEmotion
            let last = 0
            let m
            while ((m = re.exec(text)) !== null) {
                const e = known[m[1].toLowerCase()]
                if (e === undefined)
                    continue // unknown annotation: keep it as spoken text
                const chunk = text.slice(last, m.index).trim()
                if (chunk.length > 0)
                    result.push({ text: chunk, emotion: emotion })
                emotion = e
                last = re.lastIndex
            }
            const tail = text.slice(last).trim()
            if (tail.length > 0)
                result.push({ text: tail, emotion: emotion })
            return result
        }

        function next() {
            if (index >= segments.length) {
                active = false
                return
            }
            active = true
            const seg = segments[index]
            index++
            _emotionCtl.apply(seg.emotion)
            _speech.say(seg.text)
        }

        function cancel() {
            active = false
            segments = []
            index = 0
        }
    }

    Speech { id: _speech }

    // Applies an emotion to face and voice for the duration of one
    // speech output and restores the previous state afterwards.
    QtObject {
        id: _emotionCtl
        property string current: ""
        // The face between lines, set by setEmotion(). Kept apart from
        // `current` because a spoken line's emotion is borrowed and this one
        // is not: the line gives the face back to this when it ends.
        property string persistent: ""
        property int savedFace: Head.Activity.Idle
        property real savedPitch: 0
        property real savedRate: 0

        function canonical(emotion) {
            emotion = ("" + emotion).toLowerCase()
            if (emotion === "joy") emotion = "happy"
            if (emotion === "sadness") emotion = "sad"
            if (emotion === "anger") emotion = "angry"
            if (emotion !== "happy" && emotion !== "sad" && emotion !== "angry")
                return ""
            return emotion
        }

        function faceFor(emotion) {
            if (emotion === "happy") return Head.Activity.ShowJoy
            if (emotion === "sad") return Head.Activity.ShowSadness
            if (emotion === "angry") return Head.Activity.ShowAnger
            return Head.Activity.Idle
        }

        function persist(emotion) {
            persistent = canonical(emotion)
            const face = faceFor(persistent)
            // Mid-line, the new expression is what the line hands back to
            // when it finishes; the line's own emotion stays on the face
            // until then.
            if (current !== "")
                savedFace = face
            else
                _character.faceActivity = face
        }

        function apply(emotion) {
            clear()
            emotion = canonical(emotion)
            if (emotion === "")
                return
            savedFace = _character.faceActivity
            savedPitch = _speech.pitch
            savedRate = _speech.rate
            if (emotion === "happy") {
                _character.faceActivity = Head.Activity.ShowJoy
                _speech.pitch = Math.min(1, savedPitch + 0.35)
                _speech.rate = Math.min(1, savedRate + 0.1)
            } else if (emotion === "sad") {
                _character.faceActivity = Head.Activity.ShowSadness
                _speech.pitch = Math.max(-1, savedPitch - 0.35)
                _speech.rate = Math.max(-1, savedRate - 0.3)
            } else {
                _character.faceActivity = Head.Activity.ShowAnger
                _speech.pitch = Math.max(-1, savedPitch - 0.15)
                _speech.rate = Math.min(1, savedRate + 0.25)
            }
            current = emotion
        }

        function clear() {
            if (current === "")
                return
            current = ""
            _character.faceActivity = savedFace
            _speech.pitch = savedPitch
            _speech.rate = savedRate
        }
    }

    Connections {
        target: _speech
        function onFinished() {
            _emotionCtl.clear()
            if (_sayQueue.active)
                _sayQueue.next()
        }
    }

    TalkGestureAnim {
        id: _talkGestureAnim
        entity: _character
        emotion: _emotionCtl.current
        running: _emotionCtl.current !== ""
                 && _speech.speaking
                 && _character.speechBodyLanguage
                 && _character.activity === Character.Activity.Idle
                 // A held gesture outranks the speech body language: the
                 // caller asked for those arms by name, and two animators on
                 // one joint interleave rather than take turns.
                 && !_gestureAnim.holding
        loops: Animation.Infinite
        // Hand the joints back to the idle pose when the gesture ends
        onRunningChanged: {
            if (!running && _character.activity === Character.Activity.Idle
                    && !_gestureAnim.holding)
                _idleAnim.restart()
        }
    }

    // ============================================================================
    // GESTURES & DIRECTION
    // ============================================================================
    // A gesture is a HELD pose - it eases in, stays until something else is
    // asked for, and eases back - which is a different thing from the activity
    // cycles, which loop. The two cannot share a joint, so:
    //
    //   * gestures only run while activity is Character.Activity.Idle, and
    //     every verb below is ignored otherwise;
    //   * starting any other activity drops the gesture first, handing the
    //     joints over where they are;
    //   * IdleAnim and the speech body language stay switched off for as long
    //     as the gesture layer holds the joints, including the ease back to
    //     rest. stopGesture() owns that ease, nothing else.

    /*!
        \qmlproperty string Character::gesture
        \readonly
        \brief What the hands are doing: "point", "thumbsUp", "talk", or ""
               for nothing.

        Set the moment a gesture is asked for, while the arm is still on its
        way there - which is what makes it the thing to assert on. Reading
        joint angles instead, before \l gestureSettled, reports the pose the
        character has just left.
    */
    readonly property string gesture: _gestureAnim.activeGesture

    /*!
        \qmlproperty bool Character::gestureSettled
        \readonly
        \brief True once the pose has arrived - the cue to start talking
               about the thing that was pointed at.
    */
    readonly property bool gestureSettled: _gestureAnim.settled

    /*!
        \qmlproperty string Character::gestureHand
        \readonly
        \brief Which arm is doing it: "left", "right", or "" while released
               or while talking, which is two-handed.
    */
    readonly property string gestureHand: _gestureAnim.activeHand

    /*!
        \qmlproperty int Character::gestureSettleMs
        \brief How long a gesture takes to arrive at, and to leave.
    */
    property alias gestureSettleMs: _gestureAnim.settleMs

    /*!
        \qmlproperty real Character::gestureBeatScale
        \brief Stretches the rhythm of \l gesticulate(). 1 is as authored,
               above 1 is a slower speaker.
    */
    property alias gestureBeatScale: _gestureAnim.beatScale

    /*!
        \qmlproperty bool Character::safeSilhouette
        \brief Whether a raised pointing arm is forced to bend at the elbow.

        On by default, and a policy rather than a tuning value: a straight arm
        raised forward reads as a fascist salute, which no character should be
        able to strike by accident while pointing at something high. The
        forearm does the reaching instead and the aim is unaffected. Turn it
        off for a character whose job is exactly that shape - a salute, a
        hand-raise, a throw.
    */
    property alias safeSilhouette: _gestureAnim.safeSilhouette

    // ============================================================================
    // LEVEL OF DETAIL
    // ============================================================================

    /*!
        \qmlproperty enumeration Character::Detail
        \brief How much hand a character is worth drawing.

        \value Character.Detail.Minimal
               No face - no eyes, brows, nose, ears or mouth. A face is thirteen
               of a character's thirty-three draw calls and none of its
               silhouette, so this is the cheapest character there is.
        \value Character.Detail.Low
               The whole body, one box per hand. It still acts - a \l Hand takes
               its shape from \l handPose, so a fist and an open hand are
               different blocks.
        \value Character.Detail.High
               Ten boxes per hand as well: four fingers and a thumb that fold.
        \value Character.Detail.Auto
               Picks between the three by how big the character lands on screen.
               Needs \l view.
    */
    enum Detail {
        Minimal,
        Low,
        High,
        Auto
    }

    /*!
        \qmlproperty enumeration Character::detail
        \brief How much character to draw. \c Auto by default.

        Auto has to measure the character against something, and a character
        does not know what it is being looked at through - so with no \l view
        it stays Low. That is deliberately the same as the old behaviour, so
        the default costs an existing scene nothing until it opts in by handing
        over a view.

        \sa view, detailThreshold, minimalThreshold, effectiveDetail
    */
    property int detail: Character.Detail.Auto

    /*!
        \qmlproperty QtObject Character::view
        \brief The \c View3D this character is being seen in.

        Only \c Detail.Auto needs it, and only to ask how many pixels tall the
        character currently is. Set the same way \l {Label3D} takes one.
    */
    property var view: null

    /*!
        \qmlproperty real Character::detailThreshold
        \brief How tall the character has to be on screen, in pixels, before
               Auto gives it fingers.

        The default of 240 is measured rather than picked: an extended index
        finger stops being readable at all somewhere around a 90 px figure and
        is comfortable by about 120, so the switch sits well clear of the point
        where the fingers it buys would be invisible anyway.

        There is a hysteresis band below it - a character drifting across the
        line would otherwise grow and shed ten boxes a hand every few frames.
    */
    property real detailThreshold: 240

    /*!
        \qmlproperty real Character::minimalThreshold
        \brief How small the character has to get, in pixels of figure height,
               before Auto takes its face away.

        Measured the same way as \l detailThreshold, by looking: at an 83 px
        figure the eyes are clearly there and a character without them reads as
        faceless rather than as distant; at 56 px it is marginal; by 26 px the
        two are the same picture. 60 is the honest cut.

        Worth thirteen draw calls a character - a face is two thirds of a head.
    */
    property real minimalThreshold: 60

    /*!
        \qmlproperty bool Character::detailedHands
        \readonly
        \brief Whether the hands have fingers right now.

        The answer, not the question - \l detail is the question. Under Auto
        this flips on its own.

        \sa DetailedHand, detail
    */
    readonly property bool detailedHands: _detail.level === Character.Detail.High

    /*!
        \qmlproperty enumeration Character::effectiveDetail
        \readonly
        \brief Which \l {Character::Detail}{Detail} level is actually being
               drawn - never \c Auto.
    */
    readonly property int effectiveDetail: _detail.level

    /*!
        \qmlproperty string Character::handPose
        \brief What the hands do when no gesture is claiming them: "relax",
               "open", "point", "thumbsUp" or "fist".

        Read at both levels of detail. Fingers fold for it when there are
        fingers; the plain box reshapes itself to the same pose's outline when
        there are not.
    */
    property string handPose: "relax"

    /*!
        \qmlproperty string Character::emotion
        \readonly
        \brief The face the character is wearing between lines: "happy",
               "sad", "angry" or "" for neutral.

        Unlike \l speechEmotion this one persists - it is what the face
        returns to when a spoken line with its own emotion has finished.
    */
    readonly property string emotion: _emotionCtl.persistent

    /*!
        \qmlmethod void Character::pointAt(vector3d worldPos, string which)
        \brief Points at a position in the scene and holds it.

        \a which picks the arm: "auto" (the default - whichever side the
        target is on), "left" or "right". The body turns most of the way
        toward the target, leaving the last few degrees to head and shoulder,
        and the head looks at it unless \l lookAt() says otherwise.

        The pose is solved once, against the frame the character stands in
        when it is asked for. Move the character afterwards and the arm is
        aimed at where the target used to be relative to it - point again.

        Ignored unless \l activity is Character.Activity.Idle.
    */
    function pointAt(worldPos, which) {
        if (_character.activity !== Character.Activity.Idle)
            return
        _gestureAnim.request("point", worldPos, which)
    }

    /*!
        \qmlmethod void Character::thumbsUp(string which)
        \brief Gives a thumbs up with \a which hand ("right" by default).

        Ignored unless \l activity is Character.Activity.Idle.
    */
    function thumbsUp(which) {
        if (_character.activity !== Character.Activity.Idle)
            return
        _gestureAnim.request("thumbsUp", null,
                             which === undefined ? "right" : which)
    }

    /*!
        \qmlmethod void Character::gesticulate()
        \brief Talks with the hands: a loose two-handed gesticulation that
               runs until \l stopGesture().

        The other half of pointing. A finger held on a thing for the length of
        a paragraph turns the character into a signpost; the point has said
        "this one" within a second or two, and everything after that is
        explanation, which people deliver facing whoever they are explaining
        it to. It replaces any point or thumbs-up - one layer owns these
        joints - and it never stops by itself.

        Ignored unless \l activity is Character.Activity.Idle.
    */
    function gesticulate() {
        if (_character.activity !== Character.Activity.Idle)
            return
        _gestureAnim.request("talk", null, "auto")
    }

    /*!
        \qmlmethod void Character::stopGesture()
        \brief Eases every held joint back to the resting pose.

        The graceful counterpart to a gesture starting. A head aimed by
        \l lookAt() is released with it.
    */
    function stopGesture() {
        _gestureAnim.look(null)
        _gestureAnim.request("", null, "auto")
    }

    /*!
        \qmlmethod void Character::lookAt(vector3d worldPos)
        \brief Aims the head - and only the head - at a position in the scene.

        Outranks whatever the running gesture wanted to do with the head, so
        a character can point at one thing and address someone else. Pass
        null to hand the head back.

        Ignored unless \l activity is Character.Activity.Idle.
    */
    function lookAt(worldPos) {
        if (_character.activity !== Character.Activity.Idle)
            return
        _gestureAnim.look(worldPos)
    }

    /*!
        \qmlmethod void Character::turnTo(vector3d worldPos)
        \brief Turns the whole body on the spot to face a position in the
               scene, the short way round.

        Changes the orientation the character rests in, so it outlives the
        next \l stopGesture(). Nothing moves if the target is where the
        character already stands.

        Ignored unless \l activity is Character.Activity.Idle - a walking
        character is steered by its controller instead.
    */
    function turnTo(worldPos) {
        if (_character.activity !== Character.Activity.Idle)
            return
        _gestureAnim.turnTo(worldPos)
    }

    /*!
        \qmlmethod void Character::setEmotion(string name)
        \brief Puts a lasting expression on the face: "happy", "sad",
               "angry", or "neutral"/"" for none.

        Persists until it is changed, which is what separates it from the
        emotion of one spoken line: \l say() colors the face for the length
        of that line and then restores whatever was set here.
    */
    function setEmotion(name) {
        _emotionCtl.persist(name)
    }

    // ============================================================================
    // HEAD PROPERTIES
    // ============================================================================
    /*! Height of the neck section. */
    property real neckHeight: 0.333
    /*! Total head height (upper + lower). */
    readonly property real headHeight: upperHeadHeight + lowerHeadHeight

    /*! Width of the upper head. */
    property alias upperHeadWidth: _head.upperHeadWidth
    /*! Height of the upper head. */
    property alias upperHeadHeight: _head.upperHeadHeight
    /*! Depth of the upper head. */
    property alias upperHeadDepth: _head.upperHeadDepth
    /*! Width of the lower head/jaw. */
    property alias lowerHeadWidth: _head.lowerHeadWidth
    /*! Height of the lower head/jaw. */
    property alias lowerHeadHeight: _head.lowerHeadHeight
    /*! Depth of the lower head/jaw. */
    property alias lowerHeadDepth: _head.lowerHeadDepth
    /*! How pointed the chin is (0-1). */
    property alias chinPointiness: _head.chinPointiness

    /*! Eye size multiplier. */
    property alias eyeSize: _head.eyeSize
    /*! Nose size multiplier. */
    property alias noseSize: _head.noseSize
    /*! Mouth size multiplier. */
    property alias mouthSize: _head.mouthSize
    /*! Hair volume multiplier. */
    property alias hairVolume: _head.hairVolume

    /*! Skin color for head, hands, and feet. */
    property alias skinColor: _head.skinColor
    /*! Hair color. */
    property alias hairColor: _head.hairColor
    /*! Eye color. */
    property alias eyeColor: _head.eyeColor

    // ============================================================================
    // TORSO PROPERTIES
    // ============================================================================
    /*! Width at the shoulders. */
    property alias shoulderWidth: _torso.width
    /*! Height of the torso. */
    property alias torsoHeight: _torso.height
    /*! Depth of the torso. */
    property alias torsoDepth: _torso.depth
    /*! Width at the waist. */
    property alias waistWidth: _torso.waistWidth

    /*! Torso/shirt color. */
    property alias torsoColor: _torso.color

    // ============================================================================
    // HIP PROPERTIES
    // ============================================================================
    /*! Width of the hips. */
    property alias hipWidth: _hip.width
    /*! Height of the hip section. */
    property alias hipHeight: _hip.height
    /*! Depth of the hip section. */
    property alias hipDepth: _hip.depth

    /*! Hip/pants color. */
    property alias hipColor: _hip.color

    // ============================================================================
    // ARM PROPERTIES (symmetric - right arm drives both)
    // ============================================================================
    /*! Width of the arms. */
    property alias armWidth: _rightArm.width
    /*! Total arm length. */
    property alias armHeight: _rightArm.height
    /*! Depth of the arms. */
    property alias armDepth: _rightArm.depth

    /*! Upper arm proportion of total arm. */
    property alias armUpperRatio: _rightArm.upperRatio
    /*! How much the forearm tapers. */
    property alias armLowerTaper: _rightArm.lowerTaper

    /*! Width of the hands. */
    property alias handWidth: _rightArm.handWidth
    /*! Height of the hands. */
    property alias handHeight: _rightArm.handHeight
    /*! Depth of the hands. */
    property alias handDepth: _rightArm.handDepth

    /*! Arm/sleeve color. */
    property alias armColor: _rightArm.color
    /*! Hand color. */
    property alias handColor: _rightArm.handColor

    /*!
        \qmlproperty bool Character::gloves
        \brief Whether the hands are gloved - their own colour, and a cuff at
               each wrist.

        A cartoon convention, and a legibility one: a hand the colour of the
        arm it is on has to be found before it can be read. See \l {Arm::gloved}.

        \sa gloveColor, handScale
    */
    property alias gloves: _rightArm.gloved

    /*!
        \qmlproperty color Character::gloveColor
        \brief Colour of the gloves and their cuffs.
    */
    property alias gloveColor: _rightArm.gloveColor

    /*!
        \qmlproperty real Character::handScale
        \brief How much bigger the hands are drawn than the proportion tables
               give. 1 leaves them alone.

        Pairs with \l gloves: the two together are how a cartoon makes a
        gesture readable across a room. Big enough to see, light enough to
        find. \l detail accounts for it - bigger hands mean the fingers are
        worth drawing from further away.
    */
    property alias handScale: _rightArm.handScale

    // ============================================================================
    // LEG PROPERTIES (symmetric)
    // ============================================================================
    /*! Width of the legs. */
    property alias legWidth: _rightLeg.width
    /*! Total leg length. */
    property alias legHeight: _rightLeg.height
    /*! Depth of the legs. */
    property alias legDepth: _rightLeg.depth

    /*! Upper leg proportion of total leg. */
    property alias legUpperRatio: _rightLeg.upperRatio
    /*! How much the lower leg tapers. */
    property alias legLowerTaper: _rightLeg.lowerTaper

    /*! Width of the feet. */
    property alias footWidth: _rightLeg.footWidth
    /*! Height of the feet. */
    property alias footHeight: _rightLeg.footHeight
    /*! Depth of the feet. */
    property alias footDepth: _rightLeg.footDepth

    /*! Leg/pants color. */
    property alias legColor: _rightLeg.color
    /*! Foot/shoe color. */
    property alias footColor: _rightLeg.footColor

    // ============================================================================
    // BODY PART REFERENCES (for animating them)
    // ============================================================================
    /*! Reference to the left arm for animation. */
    readonly property Arm leftArm: _leftArm
    /*! Reference to the right arm for animation. */
    readonly property Arm rightArm: _rightArm
    /*! Reference to the left leg for animation. */
    readonly property Leg leftLeg: _leftLeg
    /*! Reference to the right leg for animation. */
    readonly property Leg rightLeg: _rightLeg
    /*! Reference to the head for animation. */
    readonly property Head head: _head
    /*! Reference to the torso. */
    readonly property BodyPart torso: _torso
    /*! Reference to the hip. */
    readonly property BodyPart hip: _hip

    /*!
        \qmlproperty vector3d Character::rightShoulderPos
        \readonly
        \brief Where the right shoulder joint sits, in the character's own
               coordinates (origin between the feet, +Z is the way the
               character faces).

        Published so gesture and aiming code can start from the joint that
        does the work instead of re-summing the body hierarchy - and so it
        keeps pointing at a shoulder when the torso's proportions change.
    */
    readonly property vector3d rightShoulderPos: Qt.vector3d(
        _torso.basePos.x + _rightArm.basePos.x,
        _torso.basePos.y + _rightArm.basePos.y,
        _torso.basePos.z + _rightArm.basePos.z)

    /*!
        \qmlproperty vector3d Character::leftShoulderPos
        \readonly
        \brief Where the left shoulder joint sits, in the character's own
               coordinates.
    */
    readonly property vector3d leftShoulderPos: Qt.vector3d(
        _torso.basePos.x + _leftArm.basePos.x,
        _torso.basePos.y + _leftArm.basePos.y,
        _torso.basePos.z + _leftArm.basePos.z)

    /*!
        \qmlproperty vector3d Character::headPos
        \readonly
        \brief Where the head node sits, in the character's own coordinates -
               the origin of the anchors published by \l Head.
    */
    readonly property vector3d headPos: Qt.vector3d(
        _torso.basePos.x + _head.basePos.x,
        _torso.basePos.y + _head.basePos.y,
        _torso.basePos.z + _head.basePos.z)

    BodyPart {
        id: _torso

        width: 3.5
        height: 2.5
        depth: 1.25
        property real waistWidth: 3.0

        scaledFace: Box3DGeometry.BottomFace
        faceScale: Qt.vector2d(waistWidth/width, 1.0)
        // Position torso above legs, feet, and hip
        basePos: Qt.vector3d(0, _character.legHeight + _character.footHeight + _hip.height, 0)

        Head {
            id: _head
            basePos:  Qt.vector3d(0, (_torso.height + _character.neckHeight), 0)
            speechSource: _speech

            // The face is the biggest single thing a distant character can
            // stop paying for: thirteen draw calls of the thirty-three a whole
            // body costs, and not one of them in the silhouette.
            features: _detail.level !== Character.Detail.Minimal
        }

        // Arms (containing hands)
        // Position at shoulder level (top of torso), arms extend downward
        // Whichever hand the gesture claimed shapes itself for it; the other
        // keeps whatever the character was asked to hold.
        Arm {
            id: _rightArm
            basePos: Qt.vector3d(_character.shoulderWidth * 0.5, _torso.height, 0)

            articulated: _character.detailedHands
            handPose: _gestureAnim.rightHandPose !== "" ? _gestureAnim.rightHandPose
                                                        : _character.handPose
        }

        Arm {
            id: _leftArm
            basePos: Qt.vector3d(-_character.shoulderWidth * 0.5, _torso.height, 0)

            mirrored: true
            articulated: _character.detailedHands
            handPose: _gestureAnim.leftHandPose !== "" ? _gestureAnim.leftHandPose
                                                       : _character.handPose

            // Mirror right arm dimensions
            width: _rightArm.width
            height: _rightArm.height
            depth: _rightArm.depth

            // Mirror proportion controls
            upperRatio: _rightArm.upperRatio
            lowerTaper: _rightArm.lowerTaper

            // Mirror colors
            color: _rightArm.color
            handColor: _rightArm.handColor
            gloved: _rightArm.gloved
            gloveColor: _rightArm.gloveColor
            handScale: _rightArm.handScale

            // Mirror hand dimensions
            handWidth: _rightArm.handWidth
            handHeight: _rightArm.handHeight
            handDepth: _rightArm.handDepth
        }

        // Hip (containing legs)
        BodyPart {
            id: _hip
            width: 3.0
            height: 1.167
            depth: 1.25
            color: "darkblue"

            scaledFace: Box3DGeometry.TopFace
            faceScale: Qt.vector2d(_torso.waistWidth/width, 1.0)
            basePos: Qt.vector3d(0, -_hip.height, 0)

            // Legs (containing feet)
            // Hip joint aligns with hip bottom (legs extend downward from there)
            Leg {
                id: _rightLeg
                basePos: Qt.vector3d(_hip.width * 0.4, 0, 0)
            }
            Leg {
                id: _leftLeg
                basePos: Qt.vector3d(-_hip.width * 0.4, 0, 0)

                // Mirror right leg dimensions
                width: _rightLeg.width
                height: _rightLeg.height
                depth: _rightLeg.depth

                // Mirror proportion controls
                upperRatio: _rightLeg.upperRatio
                lowerTaper: _rightLeg.lowerTaper

                // Mirror colors
                color: _rightLeg.color
                footColor: _rightLeg.footColor

                // Mirror foot dimensions
                footWidth: _rightLeg.footWidth
                footHeight: _rightLeg.footHeight
                footDepth: _rightLeg.footDepth
            }
        }
    }

    WalkAnim {
        id: _walkAnim
        entity: _character
        // Duration is calculated internally from leg geometry
        running: _character.activity === Character.Activity.Walking
        loops: Animation.Infinite
    }

    RunAnim {
        id: _runAnim
        entity: _character
        // Duration is calculated internally from leg geometry
        running: _character.activity === Character.Activity.Running
        loops: Animation.Infinite
    }

    // --- the detail policy ----------------------------------------------------
    //
    // Apparent size, not distance. Distance is the wrong question: the same
    // character twenty units away is half a screen tall through a long lens and
    // a speck through a wide one, and it is the pixels that decide whether a
    // finger is worth ten boxes. mapFrom3DScene answers in pixels and takes the
    // lens, the viewport and the projection with it.
    QtObject {
        id: _detail

        // What Auto last decided. Only consulted while detail IS Auto.
        property int autoLevel: Character.Detail.Low

        readonly property int level:
            _character.detail !== Character.Detail.Auto ? _character.detail
          : (_character.view !== null ? _detail.autoLevel : Character.Detail.Low)
    }

    function _autoDetail() {
        const v = _character.view
        if (!v)
            return Character.Detail.Low

        const base = _character.scenePosition
        const foot = v.mapFrom3DScene(base)
        const head = v.mapFrom3DScene(
                         base.plus(Qt.vector3d(0, _character.height * _character.scale.y, 0)))
        // Behind the lens mapFrom3DScene reports a negative z, and a character
        // straddling the near plane gives a screen height of thousands. Ten
        // boxes a hand for something nobody can see is the cheapest bug here to
        // avoid and the hardest to notice.
        if (foot.z <= 0 || head.z <= 0)
            return Character.Detail.Minimal

        const px = Math.abs(head.y - foot.y)

        // A gesture that shapes the hands is the whole reason fingers exist, so
        // it gets them at twice the distance. Not an override: a character
        // pointing at something from across the map still does not need a
        // finger, and the plain hand has a pose for pointing precisely so it
        // does not have to.
        const claimed = _gestureAnim.rightHandPose !== ""
                     || _gestureAnim.leftHandPose !== ""
        // Divided by handScale: the threshold is really asking whether a
        // FINGER is big enough to be worth ten boxes, and figure height is
        // only a proxy for that. A character drawn with cartoon hands has
        // readable fingers at half the figure height of one without.
        const want = _character.detailThreshold * (claimed ? 0.5 : 1.0)
                   / Math.max(0.01, _character.handScale)

        // Asymmetric on purpose at both boundaries: harder to gain detail than
        // to keep it. A character sitting exactly on a threshold would
        // otherwise pick up and drop the same thirteen or twenty boxes every
        // few frames, and a face flickering on and off is far more noticeable
        // than either version of it standing still.
        const at = _detail.autoLevel

        if (px > (at === Character.Detail.High ? want * 0.85 : want))
            return Character.Detail.High

        const bare = _character.minimalThreshold
        if (px > (at === Character.Detail.Minimal ? bare : bare * 0.85))
            return Character.Detail.Low

        return Character.Detail.Minimal
    }

    // Polled rather than bound: this depends on scenePosition and on the
    // camera, neither of which notifies. Four times a second is far more often
    // than a switch that has a hysteresis band around it can actually fire.
    Timer {
        interval: 250
        repeat: true
        running: _character.detail === Character.Detail.Auto
                 && _character.view !== null
        triggeredOnStart: true
        onTriggered: _detail.autoLevel = _character._autoDetail()
    }

    IdleAnim {
        id: _idleAnim
        entity: _character
        duration: 200
        // IdleAnim zeroes all sixteen joints, which is exactly what a held
        // pose is not allowed to have happen to it while it is being held -
        // or while it is easing back to rest, which the gesture layer does
        // itself. holding covers both.
        running: _character.activity == Character.Activity.Idle
                 && !_gestureAnim.holding
        loops: 1
    }

    GestureAnim {
        id: _gestureAnim
        entity: _character
        // The joints come back to the gesture layer's own rest pose, which is
        // the idle pose; restarting IdleAnim afterwards re-establishes it as
        // the baseline for whatever comes next without moving anything.
        onHoldingChanged: {
            if (!holding && _character.activity === Character.Activity.Idle)
                _idleAnim.restart()
        }
    }

    // An activity cycle and a held pose cannot share a joint, so the pose goes
    // first - immediately and without easing, since the cycle that is starting
    // animates from wherever it finds the joints anyway.
    onActivityChanged: {
        if (_character.activity !== Character.Activity.Idle)
            _gestureAnim.drop()
    }

    UseAnim {
        id: _useAnim
        entity: _character
        running: _character.activity === Character.Activity.Using
        loops: Animation.Infinite
    }

    FightAnim {
        id: _fightAnim
        entity: _character
        running: _character.activity === Character.Activity.Fighting
        loops: Animation.Infinite
    }

}
