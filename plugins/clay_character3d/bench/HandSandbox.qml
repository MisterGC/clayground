// (c) Clayground Contributors - MIT License, see "LICENSE" file
// @brief A rig for looking at one hand very closely, at both levels of detail
// @tags 3D, Character, Hand, Bench
// @category Plugin Benchmarks
//
// HandSandbox - the bench DetailedHand is developed against.
//
// A hand is the one part of these characters that is judged from two distances
// at once. Close up it has to look like a hand; from across a room it only has
// to keep the silhouette of the gesture, and the ten extra boxes it costs are
// wasted. So this bench always shows BOTH: the plain single-box Hand on the
// left, the articulated one on the right, same character, same pose, same
// light. A change that improves the close-up and destroys the far read is
// visible here in one frame instead of two sessions apart.
//
// There are two ways to drive it, and both are needed. raise()/setPose() hold
// the arm and the hand still, which is the only way to look at a shape; play()
// runs the real gesture through GestureAnim, which is the only way to see the
// shape the hand is actually shipped in - aimed, wrist-rolled, and settling.
//
//   claydojo --sbx plugins/clay_character3d/bench/HandSandbox.qml
//
//   clayrender plugins/clay_character3d/bench/HandSandbox.qml --size 900x700 \
//       --eval 'raise("point"); setPose("point"); look("hand")' \
//       --out /tmp/a.png
//
//   clayrender plugins/clay_character3d/bench/HandSandbox.qml --size 900x700 \
//       --eval 'play("point"); look("hand")' --settle --out /tmp/b.png
//
// The readout is the point of the distance test: figurePx is how tall the
// figure lands on screen and fingerPx how long the extended index is on the
// same screen. "Still readable at 200 px" is a claim those two numbers can be
// checked against instead of an impression. Under a point it also prints how
// far the finger misses the marker by.

import QtQuick
// Basic, never bare QtQuick.Controls: the native macOS style refuses the
// customisation these sliders need and warns once, which is enough to make
// clayrender exit 2 on a bench that rendered perfectly.
import QtQuick.Controls.Basic
import QtQuick3D
import Clayground.Character3D

pragma ComponentBehavior: Bound

Item {
    id: root
    anchors.fill: parent
    focus: true

    // --- what is on screen ----------------------------------------------------

    /*! Which pose both hands hold: relax, open, point, thumbsUp or fist. */
    property string pose: "relax"

    /*! Which shape the arms are held in: down, level, point, high or clear. */
    property string armPose: "clear"

    /*! Show the plain-hand character beside the articulated one. */
    property bool compare: true

    /*!
        Strip the scene back to shapes on a flat ground: no lights, no grid,
        everything in one ink. What is left is the outline - the thing that has
        to survive the distance the figure is actually seen from.
    */
    property bool silhouette: false

    /*! Uniform scale on both characters, for the small-on-screen tests. */
    property real figureScale: 1.0

    /*!
        The build, as ParametricCharacter's two width sliders. A hand is judged
        against the arm it is on as much as on its own, and those two are what
        move the arm: at 0/0 the figure is thin and unmuscled, at 1/1 heavy and
        muscular. Sweeping them is how \l ParametricCharacter::handBuildResponse
        was set - a hand that takes the whole of that spread is a claw at one
        end and a mitten at the other.

        clayrender ... --set 'mass=0' --set 'muscle=0' --eval 'look("body")'
    */
    property real mass: 0.55
    property real muscle: 0.3

    /*! How much of the build the hands take, 0 none and 1 all of it. */
    property real handBuild: 0.5

    function setBuild(m, u) { root.mass = m; root.muscle = u }

    /*! The three builds worth stepping between, thin to heavy. */
    readonly property var builds: [
        { label: "thin",    mass: 0.0,  muscle: 0.0 },
        { label: "neutral", mass: 0.5,  muscle: 0.5 },
        { label: "heavy",   mass: 1.0,  muscle: 1.0 },
        { label: "bench",   mass: 0.55, muscle: 0.3 }
    ]
    property int buildIndex: 3

    function nextBuild() {
        root.buildIndex = (root.buildIndex + 1) % root.builds.length
        root.mass = root.builds[root.buildIndex].mass
        root.muscle = root.builds[root.buildIndex].muscle
    }

    /*!
        The A/B this bench exists to make watchable: 1 is the hand glued to the
        arm, which is what the build used to do to it, and the default is the
        damped one. Flipped on ONE figure without moving anything else, so the
        two frames differ in nothing but the thing being judged.
    */
    function toggleHandBuild() { root.handBuild = root.handBuild < 0.99 ? 1.0 : 0.5 }

    /*!
        Cartoon hands: gloved, and bigger than the proportion tables give. The
        two go together - big enough to see, light enough to find - and this is
        the bench for deciding how far to push either.
    */
    property bool gloves: false
    property real handScale: 1.0

    function setGloves(on) { root.gloves = on }
    function setHandScale(s) { root.handScale = s }

    /*! Both at once, at the sort of values a cartoon would use. */
    function cartoon(on) {
        root.gloves = on
        root.handScale = on ? 1.45 : 1.0
    }

    /*!
        Which figure the close-up presets frame and the readout measures: the
        articulated hand by default, the plain box with subject("plain"). The
        plain one needs looking at too - it is what an Auto detail switch pops
        to, and a switch is only invisible if both sides of it are right.
    */
    property var subject: high

    /*!
        Flip the articulated figure's fingers on and off without moving
        anything else. This is the A/B that matters: an Auto detail switch does
        exactly this, on one character, mid-shot - so the two frames either
        differ only in detail or the switch is going to be seen. Comparing the
        two figures side by side cannot answer it, because they stand in
        different places and the eye reads the parallax as a difference.
    */
    function setDetail(on) {
        high.detail = on ? Character.Detail.High : Character.Detail.Low
    }

    /*!
        Hand the decision back to the character. Auto measures how tall it
        lands on screen and grows fingers past detailThreshold, so this is the
        preset to fly the camera in and out of - look("far") to look("hand")
        and back is the whole policy in two calls.
    */
    function setAuto() { high.detail = Character.Detail.Auto }

    function setSubject(which) {
        root.subject = (which === "plain" || which === "low") ? low : high
        root._trackPivot()
    }

    // --- camera ---------------------------------------------------------------

    property real camYaw: 35
    property real camPitch: 8
    property real camDist: 2.0
    property vector3d camPivot: Qt.vector3d(0, 6, 0)
    property bool camOnHand: true

    /*!
        Move the camera to a named viewpoint. The hand presets re-centre on the
        right hand wherever the current arm pose has put it, so a close-up stays
        a close-up after raise().
    */
    function look(preset) {
        if (preset === "hand")          { root.camYaw = 35;  root.camPitch = 8;  root.camDist = 2.0 }
        else if (preset === "handSide") { root.camYaw = 110; root.camPitch = 6;  root.camDist = 2.0 }
        else if (preset === "handTop")  { root.camYaw = 20;  root.camPitch = 55; root.camDist = 2.0 }
        else if (preset === "handBack") { root.camYaw = 200; root.camPitch = 8;  root.camDist = 2.0 }
        else if (preset === "handPalm") { root.camYaw = 350; root.camPitch = -8; root.camDist = 2.0 }
        // Far enough back to have the FOREARM in frame with the hand, which
        // is the only way to judge a hand against the arm it is on - and that
        // is the whole of the build question: a hand is not too small or too
        // big on its own, it is too small or too big for that limb.
        else if (preset === "arm")      { root.camYaw = 60;  root.camPitch = 20; root.camDist = 7.0 }
        else if (preset === "body")     { root.camYaw = 32;  root.camPitch = 8;  root.camDist = 22 }
        else if (preset === "bodySide") { root.camYaw = 92;  root.camPitch = 6;  root.camDist = 22 }
        // The working distance the component has to survive: the figure lands
        // around 200 px tall in a 700 px frame.
        else if (preset === "work")     { root.camYaw = 32;  root.camPitch = 6;  root.camDist = 36 }
        else if (preset === "far")      { root.camYaw = 32;  root.camPitch = 5;  root.camDist = 70 }
        else return

        root.viewpoint = preset
        root.camOnHand = preset.indexOf("hand") === 0 || preset === "arm"
        root._trackPivot()
    }

    property string viewpoint: "hand"

    // The hand moves when the arm pose does, and scenePosition does not notify,
    // so the pivot is sampled rather than bound - otherwise every close-up
    // would frame wherever the hand was at load time. Half a palm below the
    // wrist joint, because the hand hangs off the joint rather than sitting on
    // it and framing the joint puts the fingers at the bottom of the picture.
    function _trackPivot() {
        root.camPivot = root.camOnHand
                      ? root.subject.rightArm.hand.mapPositionToScene(
                            Qt.vector3d(0, -root.subject.rightArm.handHeight * 0.6, 0))
                      : Qt.vector3d(root.compare ? 0 : root.subject.basePos.x,
                                    root.subject.height * root.subject.scale.y * 0.55, 0)
    }

    // --- gestures ---------------------------------------------------------------
    //
    // The other half of the bench. raise()/setPose() are a vice - they hold the
    // hand still so it can be looked at - but nothing ships a hand in a vice.
    // What ships is a gesture: GestureAnim aims the arm, picks the hand pose
    // and rolls the wrist, and a hand that only ever looked right in the vice
    // is a hand that has not been checked. thumbsUp in particular is not a hand
    // pose at all until the wrist roll arrives, and the roll only comes from
    // here.
    //
    // A gesture owns the same joints the vice writes, so the two cannot both be
    // on: asking for one drops the other.

    /*! "" while the arms are posed by hand, otherwise the gesture being held. */
    property string gesture: ""

    /*! "point", "thumbsUp" or "talk". Anything else stops the gesture. */
    function play(name) {
        if (name !== "point" && name !== "thumbsUp" && name !== "talk") {
            root.stop()
            return
        }
        root.gesture = name
        for (const c of [high, low]) {
            if (name === "point") c.pointAt(root.aimFor(c), "right")
            else if (name === "thumbsUp") c.thumbsUp("right")
            else c.gesticulate()
        }
    }

    /*! Drop the gesture and go back to the posed arms. */
    function stop() {
        root.gesture = ""
        for (const c of [high, low])
            c.stopGesture()
        root._applyArm()
    }

    /*!
        Where a point aims, as an offset from the character's own feet rather
        than a place in the room. The two figures stand apart, and one shared
        target would turn them by different amounts and pose their arms
        differently - which is the one thing a side-by-side comparison must not
        do. Each gets its own marker at the same offset instead.
    */
    property vector3d aimOffset: Qt.vector3d(-5, 9, 7)

    function aimFor(c) { return c.scenePosition.plus(root.aimOffset) }

    function aimAt(x, y, z) {
        root.aimOffset = Qt.vector3d(x, y, z)
        if (root.gesture === "point")
            root.play("point")
    }

    // --- the arms -------------------------------------------------------------
    // Held by direct assignment rather than by an animation: the idle animation
    // owns the same joints and runs once at startup, so the pose has to be
    // written again after it has finished.

    /*! "down", "level", "point" (raised, bent elbow), "high" or "clear". */
    function raise(name) {
        root.armPose = name
        root.stop()
    }

    function _applyArm() {
        if (root.gesture !== "")
            return
        let upper = Qt.vector3d(0, 0, 0)
        let elbow = Qt.vector3d(0, 0, 0)
        let wrist = Qt.vector3d(0, 0, 0)
        if (root.armPose === "point") {
            upper = Qt.vector3d(-50, 0, 15); elbow = Qt.vector3d(-70, 0, 0); wrist = Qt.vector3d(-10, 0, 0)
        } else if (root.armPose === "high") {
            upper = Qt.vector3d(-38, 0, 12); elbow = Qt.vector3d(-92, 0, 0); wrist = Qt.vector3d(-14, 0, 0)
        } else if (root.armPose === "level") {
            upper = Qt.vector3d(-14, 0, 10); elbow = Qt.vector3d(-76, 0, 0); wrist = Qt.vector3d(0, 0, 0)
        } else if (root.armPose === "clear") {
            // Nothing anatomical about this one - it holds the hand out clear
            // of the torso and the head so a close-up has only the hand in it.
            upper = Qt.vector3d(-58, 0, 72); elbow = Qt.vector3d(-30, 0, 0); wrist = Qt.vector3d(0, 0, 0)
        }
        for (const c of [high, low]) {
            c.rightArm.upperArm.eulerRotation = upper
            c.rightArm.lowerArm.eulerRotation = elbow
            c.rightArm.hand.eulerRotation = wrist
            // The left arm stays down: with both arms up a close-up of one hand
            // has the other one in the background of it.
            c.leftArm.upperArm.eulerRotation = Qt.vector3d(0, 0, 0)
            c.leftArm.lowerArm.eulerRotation = Qt.vector3d(0, 0, 0)
            c.leftArm.hand.eulerRotation = Qt.vector3d(0, 0, 0)
        }
    }

    // Re-applied on a tick rather than once: the idle animation owns the same
    // joints, runs itself after load and would zero anything --eval set before
    // it got there. Writing the same numbers again costs nothing.
    Timer {
        interval: 120
        repeat: true
        running: true
        onTriggered: {
            root._applyArm()
            root._trackPivot()
            root.status = root.report()
        }
    }

    // --- what the hands are doing ---------------------------------------------

    /*! "relax", "open", "point", "thumbsUp" or "fist". */
    function setPose(name) { root.pose = name }

    function nextPose() {
        const all = ["relax", "open", "point", "thumbsUp", "fist"]
        root.pose = all[(all.indexOf(root.pose) + 1) % all.length]
    }

    /*! Shrink both figures; the fingers have to come with them. */
    function scaleTo(s) { root.figureScale = s }

    function setSilhouette(on) { root.silhouette = on }

    function setCompare(on) { root.compare = on; root._trackPivot() }

    // --- the tuner ---------------------------------------------------------------
    //
    // Every number in DetailedHand's pose table was arrived at by looking, and
    // looking is done with the hand in front of you - not in a text editor with
    // a rebuild between each guess. The panel puts a slider on each field of
    // the row the current pose resolves to, writes them onto the RIGHT hand
    // only, and prints the result back in the form the table is written in, so
    // a shape somebody dialled in is pasted rather than re-derived.
    //
    // The left hand deliberately keeps the shipped pose. A change to a shape
    // this small is not judged against a memory of the last render.

    // "monospace" resolves to nothing on macOS and Qt warns about it once,
    // which is enough to make clayrender exit 2 on a bench that is fine.
    readonly property string monoFont: Qt.platform.os === "osx" ? "Menlo"
                                     : Qt.platform.os === "windows" ? "Consolas"
                                                                    : "monospace"

    /*! Whether the slider panel is up. */
    property bool tuning: false

    /*!
        Which pose the panel is actually editing: the one the SUBJECT'S HAND is
        holding, not \l pose.

        The two are the same in the vice and different the moment a gesture is
        played - a gesture picks the hand's shape itself, and \l pose is only
        what the vice asked for. Tuning \l pose while a gesture holds another
        one writes the wrong row onto the hand, which looks exactly like the
        gesture being broken. It cost a wrong diagnosis before this followed
        the hand.
    */
    readonly property string tunedPose: {
        const a = root.subject.rightArm
        return a && a.handPose ? a.handPose : root.pose
    }

    /*!
        The fields of a pose row, with the range each is worth sweeping.
        `tx` runs past 90 because a thumb folding across a closed fist has to:
        under 90 it is still heading away from the wrist.
    */
    readonly property var tunables: [
        { key: "i",        label: "index curl",   from: 0,    to: 1,   dp: 2 },
        { key: "m",        label: "middle curl",  from: 0,    to: 1,   dp: 2 },
        { key: "r",        label: "ring curl",    from: 0,    to: 1,   dp: 2 },
        { key: "l",        label: "little curl",  from: 0,    to: 1,   dp: 2 },
        { key: "sp",       label: "fan",          from: 0,    to: 1,   dp: 2 },
        { key: "tx",       label: "thumb fold",   from: -60,  to: 200, dp: 0 },
        { key: "tz",       label: "thumb swing",  from: -110, to: 110, dp: 0 },
        { key: "tc",       label: "thumb curl",   from: 0,    to: 1,   dp: 2 },
        { key: "tl",       label: "thumb length", from: 0.5,  to: 1.8, dp: 2 },
        { key: "toff",     label: "thumb root fwd", from: -0.5, to: 1.8, dp: 2 },
        // A roll about the thumb's own length. A thumb's flat faces sit about
        // a quarter turn off a finger's, and at zero it is a finger that
        // happens to grow lower down the hand.
        { key: "tr",       label: "thumb twist",  from: -180, to: 180, dp: 0 },
        // Where the thumb leaves the palm. Hardcoded until the reference
        // photographs showed it was the thing that was wrong: a thumb comes
        // away LOW, past halfway to the wrist, and one rooted high is a fifth
        // finger set slightly apart.
        { key: "tdown",    label: "thumb root down", from: 0.15, to: 0.85, dp: 2 },
        { key: "tout",     label: "thumb root out",  from: 0.20, to: 0.75, dp: 2 },
        // Not a pose, but the other half of what a folded finger looks like.
        { key: "foldNear", label: "knuckle fold", from: 40,   to: 150, dp: 0 },
        { key: "foldFar",  label: "second fold",  from: 20,   to: 150, dp: 0 },
        { key: "tuckNear", label: "near tuck",    from: 0,    to: 0.6, dp: 2 },
        { key: "tuckFar",  label: "far tuck",     from: 0,    to: 0.8, dp: 2 }
    ]

    /*! The live values, keyed as the table is. */
    property var tuned: ({})

    /*!
        Reload the sliders from what the current pose actually ships with. Also
        what \l pose changes do, so stepping through the poses always starts
        from the real thing rather than from the last one that was fiddled.
    */
    function reseed() {
        const h = root._hand()
        if (!h)
            return
        const row = h.poseFor(root.tunedPose)
        let v = {}
        for (const t of root.tunables) {
            v[t.key] = row[t.key] !== undefined ? row[t.key]
                     : t.key === "foldNear" ? h.foldNear
                     : t.key === "foldFar"  ? h.foldFar
                     : t.key === "tuckNear" ? h.tuckNear
                     : t.key === "tuckFar"  ? h.tuckFar
                     : t.key === "tdown"    ? h.thumbDown
                     : t.key === "tout"     ? h.thumbOut : 0
        }
        root.tuned = v
        root.apply()
    }

    /*! Push the sliders onto the tuned hand. */
    function apply() {
        let o = {}
        for (const k in root.tuned)
            o[k] = root.tuned[k]
        high.rightArm.poseOverride = o
        low.rightArm.poseOverride = o
    }

    function set(key, value) {
        let v = {}
        for (const k in root.tuned)
            v[k] = root.tuned[k]
        v[key] = value
        root.tuned = v
        root.apply()
    }

    /*! Back to what ships, both hands. */
    function revert() {
        high.rightArm.poseOverride = null
        low.rightArm.poseOverride = null
        root.reseed()
    }

    // The DetailedHand under the subject, for poseFor() and the fold defaults.
    function _hand() {
        const a = root.subject.rightArm
        return a && a.fingers ? a.fingers : null
    }

    function _num(v, dp) { return dp === 0 ? String(Math.round(v)) : v.toFixed(dp) }

    /*!
        The tuned row, in the form DetailedHand's table is written in - paste it
        over the pose it belongs to. The fold fields come out on their own line
        because they are the hand's, not the pose's.
    */
    function dump() {
        const t = root.tuned
        const row = "        if (name === \"" + root.tunedPose + "\")\n"
                  + "            return { i: " + root._num(t.i, 2)
                  + ", m: " + root._num(t.m, 2) + ", r: " + root._num(t.r, 2)
                  + ", l: " + root._num(t.l, 2) + ", sp: " + root._num(t.sp, 2) + ",\n"
                  + "                     tx: " + root._num(t.tx, 0)
                  + ", tz: " + root._num(t.tz, 0) + ", tc: " + root._num(t.tc, 2)
                  + ", tl: " + root._num(t.tl, 2) + ", toff: " + root._num(t.toff, 2)
                  + ", tr: " + root._num(t.tr, 0) + " }"
        const shape = "    property real foldNear: " + root._num(t.foldNear, 0)
                    + "\n    property real foldFar: " + root._num(t.foldFar, 0)
                    + "\n    property real tuckNear: " + root._num(t.tuckNear, 2)
                    + "\n    property real tuckFar: " + root._num(t.tuckFar, 2)
                    + "\n    property real thumbDown: " + root._num(t.tdown, 2)
                    + "\n    property real thumbOut: " + root._num(t.tout, 2)
        const out = row + "\n\n" + shape
        console.log(out)
        return out
    }

    onTunedPoseChanged: root.reseed()

    // --- measurements ----------------------------------------------------------

    readonly property real _spread: 8

    readonly property real figureHeight: root.subject.height * root.subject.scale.y

    /*! Apparent height of the whole figure, in screen pixels. */
    function figurePx() {
        const foot = view.mapFrom3DScene(root.subject.scenePosition)
        const top = view.mapFrom3DScene(root.subject.scenePosition.plus(
                                            Qt.vector3d(0, root.figureHeight, 0)))
        return Math.abs(top.y - foot.y)
    }

    /*! Apparent length of the extended index finger, in the same pixels. */
    function fingerPx() {
        const h = root.subject.rightArm.hand
        const tip = root.subject.rightArm.indexTip
        const a = view.mapFrom3DScene(h.mapPositionToScene(Qt.vector3d(0, 0, 0)))
        const b = view.mapFrom3DScene(h.mapPositionToScene(tip))
        return Math.hypot(b.x - a.x, b.y - a.y)
    }

    /*!
        How far the extended index misses the marker by, in degrees - the angle
        between where the finger is aimed and where the thing actually is.
        Meaningless unless a point is being held.
    */
    function aimErrorDeg() {
        const h = root.subject.rightArm.hand
        const from = h.mapPositionToScene(Qt.vector3d(0, 0, 0))
        const along = h.mapPositionToScene(root.subject.rightArm.indexTip).minus(from)
        const toIt = root.aimFor(root.subject).minus(from)
        const denom = along.length() * toIt.length()
        if (denom < 1e-6)
            return 0
        return Math.acos(Math.max(-1, Math.min(1, along.dotProduct(toIt) / denom)))
             * 180 / Math.PI
    }

    /*! One line for --eval to print, and for the corner of every render. */
    function report() {
        // Character.handPose is only what the hand falls back to. While a
        // gesture holds it the arm's own handPose is the one on screen, and
        // printing the fallback instead is how a pose gets "fixed" twice.
        const held = root.subject.rightArm.handPose
        const mode = high.detail === Character.Detail.Auto
                   ? "auto/" + (high.detailedHands ? "fingers" : "box")
                   : (high.detailedHands ? "fingers" : "box")
        const arm = root.subject.rightArm
        return "build " + root.builds[root.buildIndex].label
             + " m" + root.mass.toFixed(2) + " u" + root.muscle.toFixed(2)
             + (root.handBuild < 0.99 ? "  hand takes half" : "  HAND GLUED TO ARM")
             // The one number the build question is actually about: how wide
             // the palm is against the arm it hangs off.
             + " palm/arm " + (arm.handWidth / Math.max(1e-6, arm.width)).toFixed(2)
             + "  "
             + (root.gloves ? "gloved x" + root.handScale.toFixed(2) + "  " : "")
             + (root.subject === low ? "plain  " : mode + "  ")
             + (root.gesture !== "" ? "gesture " + root.gesture
                                    : root.armPose + "/" + root.pose)
             + " -> " + held
             + "  " + root.viewpoint
             + "  figure=" + root.figurePx().toFixed(0) + "px"
             + "  wrist-to-fingertip=" + root.fingerPx().toFixed(0) + "px"
             + (root.gesture === "point"
                    ? "  aim off by " + root.aimErrorDeg().toFixed(1) + " deg"
                    : "")
    }

    property string status: ""

    Component.onCompleted: {
        root._applyArm()
        root.look("hand")
        // After the Loader3D has had a turn: fingers are loaded on demand and
        // reseed() needs the hand to ask what the pose ships with.
        _seed.start()
    }

    Timer {
        id: _seed
        interval: 60
        onTriggered: root.reseed()
    }

    // --- keys -------------------------------------------------------------------

    // --- orbiting by hand ---------------------------------------------------
    //
    // The presets answer "show me the shape from the angle it is judged at";
    // this answers "let me look at it". A hand is a solid and the thing wrong
    // with one is often on a face no preset points at - the fist's thumb hid
    // from four of them in a row - so dragging around it is not a convenience,
    // it is how you find out what is there.
    //
    // RIGHT button only, and that is deliberate: the tuning panel is full of
    // sliders, and a full-frame MouseArea that took the left button would eat
    // every one of them. The wheel arrives here whatever the accepted buttons
    // are, so zoom works over the panel too.
    MouseArea {
        id: _orbit
        anchors.fill: parent
        acceptedButtons: Qt.RightButton
        // Under the panel in z order: declared first, so the sliders are still
        // on top of it and still get their own events.
        z: -1

        property real lastX: 0
        property real lastY: 0

        /*! Degrees per pixel dragged. */
        property real rate: 0.35

        onPressed: (e) => {
            _orbit.lastX = e.x
            _orbit.lastY = e.y
            root.forceActiveFocus()
        }

        onPositionChanged: (e) => {
            root.camYaw += (e.x - _orbit.lastX) * _orbit.rate
            // Stopped short of straight up and straight down, where the yaw
            // stops meaning anything and the view flips as it crosses.
            root.camPitch = Math.max(-88, Math.min(88,
                                root.camPitch + (e.y - _orbit.lastY) * _orbit.rate))
            _orbit.lastX = e.x
            _orbit.lastY = e.y
            root.viewpoint = "free"
        }

        // Multiplicative, not additive: the presets run from 2 units at the
        // fingertips to 70 across the room, and a fixed step is either useless
        // close up or takes a minute to cross the far end.
        onWheel: (w) => {
            const k = w.angleDelta.y > 0 ? 0.88 : 1 / 0.88
            root.camDist = Math.max(0.3, Math.min(300, root.camDist * k))
            root.viewpoint = "free"
        }
    }

    Keys.onPressed: (e) => {
        if (e.key === Qt.Key_Space) root.nextPose()
        else if (e.key === Qt.Key_1) root.look("hand")
        else if (e.key === Qt.Key_2) root.look("handSide")
        else if (e.key === Qt.Key_3) root.look("handTop")
        else if (e.key === Qt.Key_4) root.look("handBack")
        else if (e.key === Qt.Key_5) root.look("handPalm")
        else if (e.key === Qt.Key_6) root.look("body")
        else if (e.key === Qt.Key_7) root.look("work")
        else if (e.key === Qt.Key_8) root.look("far")
        else if (e.key === Qt.Key_9) root.look("arm")
        else if (e.key === Qt.Key_P) root.play("point")
        else if (e.key === Qt.Key_O) root.play("thumbsUp")
        else if (e.key === Qt.Key_I) root.play("talk")
        else if (e.key === Qt.Key_X) root.stop()
        else if (e.key === Qt.Key_C) root.setCompare(!root.compare)
        else if (e.key === Qt.Key_D) root.setSubject(root.subject === high ? "plain" : "high")
        else if (e.key === Qt.Key_H) root.setDetail(!high.detailedHands)
        else if (e.key === Qt.Key_U) root.setAuto()
        else if (e.key === Qt.Key_L) root.cartoon(!root.gloves)
        else if (e.key === Qt.Key_S) root.setSilhouette(!root.silhouette)
        else if (e.key === Qt.Key_N) { root.tuning = !root.tuning; if (root.tuning) root.reseed() }
        else if (e.key === Qt.Key_0) root.revert()
        else if (e.key === Qt.Key_K) root.dump()
        else if (e.key === Qt.Key_B) root.nextBuild()
        else if (e.key === Qt.Key_V) root.toggleHandBuild()
        else if (e.key === Qt.Key_A) {
            const all = ["clear", "point", "high", "level", "down"]
            root.raise(all[(all.indexOf(root.armPose) + 1) % all.length])
        }
        else if (e.key === Qt.Key_Q) root.camYaw -= 10
        else if (e.key === Qt.Key_E) root.camYaw += 10
        else if (e.key === Qt.Key_R) root.camPitch = Math.min(85, root.camPitch + 5)
        else if (e.key === Qt.Key_F) root.camPitch = Math.max(-85, root.camPitch - 5)
        else if (e.key === Qt.Key_T) root.camDist = Math.max(0.4, root.camDist * 0.8)
        else if (e.key === Qt.Key_G) root.camDist = Math.min(200, root.camDist * 1.25)
        else return
        e.accepted = true
    }

    // --- the scene ----------------------------------------------------------------

    component Figure: ParametricCharacter {
        bodyHeight: 10
        realism: 0.0
        maturity: 0.15
        mass: root.mass
        muscle: root.muscle
        handBuildResponse: root.handBuild
        femininity: 0.2
        scale: Qt.vector3d(root.figureScale, root.figureScale, root.figureScale)
        handPose: root.pose
        // Auto has nothing to measure against without it.
        view: view
        gloves: root.gloves
        handScale: root.handScale
        activity: Character.Activity.Idle

        // One ink in silhouette mode: a two-tone figure hands the eye an inner
        // edge to read the shape by, which is exactly what is not available at
        // the distance this mode exists to test.
        skinColor: root.silhouette ? "#1b1b1f" : "#d38d5f"
        handColor: root.silhouette ? "#1b1b1f" : "#d38d5f"
        footColor: root.silhouette ? "#1b1b1f" : "#b5764a"
        // The IRIS colour, not the white of the eye - the white is drawn by
        // the face shader and is not a property at all. At #ffffff the irises
        // were painted white on a white eye and the figure came out with no
        // pupils, which reads as a doll from any distance close enough to see
        // a hand. Every other bench uses this brown.
        eyeColor: root.silhouette ? "#1b1b1f" : "#4a3728"
        hairColor: root.silhouette ? "#1b1b1f" : "#5c3a21"
        torsoColor: root.silhouette ? "#1b1b1f" : "#3663c8"
        armColor: root.silhouette ? "#1b1b1f" : "#3663c8"
        hipColor: root.silhouette ? "#1b1b1f" : "#5a6b7d"
        legColor: root.silhouette ? "#1b1b1f" : "#5a6b7d"
    }

    View3D {
        id: view
        anchors.fill: parent
        camera: cam

        environment: SceneEnvironment {
            clearColor: root.silhouette ? "#f4f2ee" : "#f0f0f0"
            backgroundMode: SceneEnvironment.Color
            antialiasingMode: SceneEnvironment.MSAA
            antialiasingQuality: SceneEnvironment.High
        }

        // Four is the hard maximum for directional lights, so silhouette mode
        // cannot add a light of its own: the key one flattens to pure ambient
        // instead and the other three go out.
        DirectionalLight {
            eulerRotation.x: -40
            eulerRotation.y: -45
            castsShadow: !root.silhouette
            shadowFactor: 75
            shadowMapQuality: Light.ShadowMapQualityVeryHigh
            softShadowQuality: Light.PCF16
            pcfFactor: 2
            shadowBias: 5
            shadowMapFar: 200
            brightness: root.silhouette ? 0.0 : 0.9
            ambientColor: root.silhouette ? Qt.rgba(1, 1, 1, 1)
                                          : Qt.rgba(0.55, 0.55, 0.6, 1.0)
        }

        DirectionalLight {
            eulerRotation.x: -20
            eulerRotation.y: 180
            visible: !root.silhouette
            brightness: 0.5
        }

        DirectionalLight {
            eulerRotation.x: -25
            eulerRotation.y: 90
            visible: !root.silhouette
            brightness: 0.35
        }

        DirectionalLight {
            eulerRotation.x: -25
            eulerRotation.y: -90
            visible: !root.silhouette
            brightness: 0.35
        }

        Node {
            position: root.camPivot
            eulerRotation: Qt.vector3d(-root.camPitch, root.camYaw, 0)

            PerspectiveCamera {
                id: cam
                z: root.camDist
                // The default near plane is 10 units out, which is further than
                // the whole close-up rig - without this every hand preset
                // renders an empty room.
                clipNear: 0.05
                clipFar: 800
            }
        }

        Model {
            source: "#Rectangle"
            visible: !root.silhouette
            eulerRotation.x: -90
            scale: Qt.vector3d(4, 4, 1)
            materials: PrincipledMaterial {
                baseColor: "#e8e6e1"
                roughness: 0.9
            }
        }

        // What a point is aimed at. Visible, because "the finger is on it" is
        // the only way to read an aim error that the number cannot show you -
        // the number says how far off, the marker says which way.
        component Marker: Model {
            source: "#Sphere"
            visible: root.gesture === "point"
            scale: Qt.vector3d(0.006, 0.006, 0.006)
            materials: PrincipledMaterial {
                baseColor: "#c0392b"
                lighting: PrincipledMaterial.NoLighting
            }
        }

        Marker { position: root.aimFor(high) }
        Marker {
            position: root.aimFor(low)
            visible: low.visible && root.gesture === "point"
        }

        // The one under the microscope.
        Figure {
            id: high
            name: "articulated"
            // basePos, not x: BodyPart binds position to basePos, so an x of
            // its own is overwritten the moment anything re-evaluates. Fixed
            // rather than re-centred when the other figure is hidden - a
            // close-up that shifts sideways the moment compare goes off is a
            // close-up you cannot compare two renders of.
            basePos: Qt.vector3d(-root._spread * 0.5, 0, 0)
            detail: Character.Detail.High
            objectName: "articulated"
        }

        // The same character with the plain box hand, for the far read. Off to
        // the side rather than behind: at the working distance the two have to
        // be comparable in one glance, not one after the other.
        Figure {
            id: low
            name: "plain"
            basePos: Qt.vector3d(root._spread * 0.5, 0, 0)
            visible: root.compare || root.subject === low
            detail: Character.Detail.Low
        }
    }

    // --- readout --------------------------------------------------------------

    Text {
        anchors { left: parent.left; top: parent.top; margins: 12 }
        color: "#1b1b1f"
        font.family: Qt.platform.os === "osx" ? "Menlo"
                   : Qt.platform.os === "windows" ? "Consolas" : "monospace"
        font.pixelSize: 13
        text: root.status
        visible: !root.silhouette
    }

    // The panel. One row per field, seeded from the pose and written straight
    // back onto the tuned hand - no apply button, because the whole point is to
    // watch the shape while the number moves.
    Rectangle {
        id: _panel
        visible: root.tuning && !root.silhouette
        // Sized to its rows rather than stretched to the frame: anchored to the
        // bottom it ran over the bench's own key legend.
        anchors { right: parent.right; top: parent.top; margins: 8 }
        width: 300
        height: _panelRows.implicitHeight + 20
        radius: 6
        color: Qt.rgba(1, 1, 1, 0.93)
        border.color: "#c9c6c0"

        Column {
            id: _panelRows
            anchors { left: parent.left; right: parent.right; top: parent.top; margins: 10 }
            spacing: 3

            Text {
                text: "tuning  " + root.tunedPose
                font.family: root.monoFont
                font.pixelSize: 13
                font.bold: true
                color: "#1b1b1f"
            }
            Text {
                width: _panel.width - 20
                wrapMode: Text.WordWrap
                text: "right hand only - the left keeps what ships"
                font.family: root.monoFont
                font.pixelSize: 10
                color: "#6b6b72"
            }
            Item { width: 1; height: 4 }

            Repeater {
                model: root.tunables
                Row {
                    id: _row
                    required property var modelData
                    spacing: 6
                    Text {
                        width: 84
                        text: _row.modelData.label
                        font.family: root.monoFont
                        font.pixelSize: 10
                        color: "#3a3a40"
                        anchors.verticalCenter: parent.verticalCenter
                    }
                    Slider {
                        width: 140
                        from: _row.modelData.from
                        to: _row.modelData.to
                        value: root.tuned[_row.modelData.key] === undefined
                               ? 0 : root.tuned[_row.modelData.key]
                        onMoved: root.set(_row.modelData.key, value)
                        anchors.verticalCenter: parent.verticalCenter
                    }
                    Text {
                        width: 42
                        horizontalAlignment: Text.AlignRight
                        text: root.tuned[_row.modelData.key] === undefined ? "-"
                              : root._num(root.tuned[_row.modelData.key], _row.modelData.dp)
                        font.family: root.monoFont
                        font.pixelSize: 10
                        color: "#1b1b1f"
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }
            }

            Item { width: 1; height: 6 }
            Text {
                width: _panel.width - 20
                wrapMode: Text.WordWrap
                font.family: root.monoFont
                font.pixelSize: 9
                color: "#6b6b72"
                text: "space next pose   0 revert   k print the row to the console   "
                    + "n close"
            }
        }
    }

    Text {
        anchors { left: parent.left; bottom: parent.bottom; margins: 12 }
        color: "#6b6b72"
        font.family: Qt.platform.os === "osx" ? "Menlo"
                   : Qt.platform.os === "windows" ? "Consolas" : "monospace"
        font.pixelSize: 11
        visible: !root.silhouette
        text: "space pose   a arm   p/o/i point,thumbsUp,talk   x stop   "
            + "1-5 hand views   6-8 body/work/far   9 arm+hand   c compare   "
            + "b build   v hand takes half/all of it   "
            + "n tune the pose   0 revert   k print the row   "
            + "right-drag orbit   wheel zoom   "
            + "s silhouette   qerf/tg camera"
    }
}
