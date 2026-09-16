// (c) Clayground Contributors - MIT License, see "LICENSE" file
//
// HandBench - one hand, very closely, at both levels of detail at once.
//
// A hand is the one part of these characters judged from two distances at the
// same time. Close up it has to look like a hand; from across a room it only
// has to keep the silhouette of the gesture, and the ten extra boxes it costs
// are wasted. So the scene always shows BOTH: the articulated hand on the
// left, the plain single-box one on the right, same character, same pose,
// same light. A change that improves the close-up and destroys the far read
// is visible here in one frame instead of two sessions apart.
//
// The arm is held rather than animated - the arm verb picks one of five held
// shapes, the pose verb what the fingers do - and the hold is written onto
// the joints again every 120 ms, because the idle animation owns those same
// joints and would take them back. That is a vice, and nothing ships a hand
// in a vice; what ships is a gesture, and GestureSheet is where the solver's
// own hand is looked at.
//
// The readings are the distance test: how tall the subject lands on screen
// and how long its extended index is in the same pixels. "Still readable at
// two hundred pixels" is a claim those two can be checked against instead of
// an impression - and the figure scale knob is how the subject is taken away
// from the camera without moving it. The one pure number is the palm against
// the arm it hangs off, which is what the hand-build knob is actually about.
//
// NOT PORTED from the bench: the seventeen-slider pose tuner. Dialling a new
// finger table is plugin work and belongs on the bench
// (plugins/clay_character3d/bench/HandSandbox.qml); this scene is for looking
// at what ships.
import QtQuick
import QtQuick3D
import Clayground.Character3D
import Clayground.Lab

Node {
    id: scene

    // --- the contract: identity, what the lab drives ---------------------------
    readonly property string aspect: "hands"
    property real time: 0
    property var view: null
    property bool silhouette: false

    // --- choices ----------------------------------------------------------------
    /*! What the fingers do: relax, open, point, thumbsUp or fist. */
    property string pose: "relax"
    /*! How the arm is held: clear, point, high, level or down. */
    property string arm: "clear"
    /*! Which figure the readings measure: "articulated" or "plain". */
    property string subject: "articulated"
    /*! The build, as the two width sliders: thin, neutral, heavy or bench. */
    property string build: "bench"
    /*! Cartoon hands: gloved and half again as big, the way a comic draws them. */
    property bool gloves: false
    /*! The A/B this scene exists for: fingers or a box, on the LEFT figure. */
    property bool fingers: true

    // --- knobs ---------------------------------------------------------------------
    Parameter { id: pHandBuild; name: "handBuild"; value: 0.5; from: 0; to: 1 }
    Parameter { id: pScale; name: "scale"; value: 1.0; from: 0.15; to: 1 }

    readonly property real bodyHeight: 10
    // Wide apart on purpose: the held-clear arm puts the hand six units out
    // to the side, and at the bench's own spacing a close-up of one hand had
    // the other figure's head directly behind it.
    readonly property real spread: 16

    readonly property var builds: [
        { name: "thin",    mass: 0.0,  muscle: 0.0 },
        { name: "neutral", mass: 0.5,  muscle: 0.5 },
        { name: "heavy",   mass: 1.0,  muscle: 1.0 },
        { name: "bench",   mass: 0.55, muscle: 0.3 }
    ]
    function buildRow(name) {
        for (const b of scene.builds) if (b.name === name) return b
        return scene.builds[3]
    }
    readonly property var buildNow: scene.buildRow(scene.build)

    /*! The figure the readings are about. */
    readonly property var subjectFigure: scene.subject === "plain" ? low : high

    // --- framing -------------------------------------------------------------------
    // The hand moves when the arm pose does and scenePosition does not notify,
    // so where it is gets SAMPLED on the same tick that re-writes the hold -
    // otherwise every close-up would frame wherever the hand was at load time.
    // Half a palm below the wrist joint, because the hand hangs off the joint
    // rather than sitting on it and framing the joint puts the fingers at the
    // bottom of the picture.
    property vector3d handAt: Qt.vector3d(0, scene.bodyHeight * 0.6, 0)
    function trackHand() {
        const a = scene.subjectFigure.rightArm
        scene.handAt = a.hand.mapPositionToScene(Qt.vector3d(0, -a.handHeight * 0.6, 0))
    }

    readonly property real handReach: Math.max(0.6, high.rightArm.handHeight * 2.2)
                                    * Math.max(0.25, pScale.value)
    readonly property real armReach: high.armHeight * 0.85 * Math.max(0.25, pScale.value)

    /*!
        What to frame for \a shotName: a box around the subject's own hand for
        the three close-ups, the whole pair for the wide ones. This is the one
        scene in the kit whose region depends on the shot - a hand at two
        units and a pair at forty are not the same picture - which is why the
        lab hands the shot's name to bounds().

        A call with no name (another host, or a lab that frames before it has
        picked a shot) gets \l framedBy: the hand WITH its forearm, the
        framing both ends survive.
    */
    function bounds(shotName) {
        const name = shotName !== undefined && scene.shots[shotName] !== undefined
                   ? shotName : scene.framedBy
        if (name === "hand" || name === "palm" || name === "arm") {
            const r = name === "arm" ? scene.armReach : scene.handReach
            return [scene.handAt.minus(Qt.vector3d(r, r, r)),
                    scene.handAt.plus(Qt.vector3d(r, r, r))]
        }
        const h = scene.bodyHeight * Math.max(0.25, pScale.value)
        return [Qt.vector3d(-scene.spread, 0, -h * 0.4),
                Qt.vector3d(scene.spread, h * 1.25, h * 0.4)]
    }
    readonly property string framedBy: "arm"
    readonly property var shots: ({
        "hand":    { yaw: 35,  pitch: 8 },
        "palm":    { yaw: 350, pitch: 2 },
        "arm":     { yaw: 60,  pitch: 20 },
        "quarter": { yaw: 32,  pitch: 8 },
        "side":    { yaw: 92,  pitch: 6 },
        "far":     { yaw: 32,  pitch: 5 }
    })
    readonly property string defaultShot: "hand"
    readonly property real nearest: 0.6
    readonly property real plotWindow: 6

    // --- holding the arm ---------------------------------------------------------------
    // Written straight onto the joints rather than animated: the idle
    // animation owns them and runs itself after load, so the hold is re-written
    // on a tick. Writing the same numbers again costs nothing.
    function armAngles() {
        if (scene.arm === "point")
            return { upper: Qt.vector3d(-50, 0, 15), elbow: Qt.vector3d(-70, 0, 0), wrist: Qt.vector3d(-10, 0, 0) }
        if (scene.arm === "high")
            return { upper: Qt.vector3d(-38, 0, 12), elbow: Qt.vector3d(-92, 0, 0), wrist: Qt.vector3d(-14, 0, 0) }
        if (scene.arm === "level")
            return { upper: Qt.vector3d(-14, 0, 10), elbow: Qt.vector3d(-76, 0, 0), wrist: Qt.vector3d(0, 0, 0) }
        if (scene.arm === "clear")
            // Nothing anatomical about this one - it holds the hand out clear
            // of the torso and the head so a close-up has only the hand in it.
            return { upper: Qt.vector3d(-58, 0, 72), elbow: Qt.vector3d(-30, 0, 0), wrist: Qt.vector3d(0, 0, 0) }
        return { upper: Qt.vector3d(0, 0, 0), elbow: Qt.vector3d(0, 0, 0), wrist: Qt.vector3d(0, 0, 0) }
    }
    function holdArm() {
        const a = scene.armAngles()
        for (const c of [high, low]) {
            c.rightArm.upperArm.eulerRotation = a.upper
            c.rightArm.lowerArm.eulerRotation = a.elbow
            c.rightArm.hand.eulerRotation = a.wrist
            // The left arm stays down: with both arms up, a close-up of one
            // hand has the other one in the background of it.
            c.leftArm.upperArm.eulerRotation = Qt.vector3d(0, 0, 0)
            c.leftArm.lowerArm.eulerRotation = Qt.vector3d(0, 0, 0)
            c.leftArm.hand.eulerRotation = Qt.vector3d(0, 0, 0)
        }
    }

    /*! True once the hold has survived one idle pass; the lab waits for it. */
    property bool held: false
    Timer {
        interval: 120
        repeat: true
        running: true
        onTriggered: {
            scene.holdArm()
            scene.trackHand()
            scene.held = true
        }
    }
    readonly property bool ready: scene.held
    // Before the lab frames bounds(), which it does the moment the scene
    // loads: the hold and the sample both have to be there or the first
    // close-up frames the middle of the room.
    Component.onCompleted: { scene.holdArm(); scene.trackHand() }
    onArmChanged: { scene.holdArm(); scene.trackHand() }
    onSubjectChanged: scene.trackHand()

    // --- the numbers -----------------------------------------------------------------------
    // Pure: both come off the proportion tables, not off a settling joint.
    readonly property real palmArm: {
        pHandBuild.value; scene.buildNow; scene.gloves
        const a = scene.subjectFigure.rightArm
        return a.handWidth / Math.max(1e-6, a.width)
    }
    Probe { name: "hands.palmArm"; expr: () => scene.palmArm }
    Probe { name: "hands.handScale"; expr: () => (scene.gloves ? 1.45 : 1.0) }

    /*! Apparent height of the whole subject, in screen pixels. */
    function figurePx() {
        if (!scene.view) return 0
        const c = scene.subjectFigure
        const h = c.height * c.scale.y
        const foot = scene.view.mapFrom3DScene(c.scenePosition)
        const top = scene.view.mapFrom3DScene(c.scenePosition.plus(Qt.vector3d(0, h, 0)))
        return Math.abs(top.y - foot.y)
    }
    /*! Apparent length of the extended index finger, in the same pixels. */
    function fingerPx() {
        if (!scene.view) return 0
        const a = scene.subjectFigure.rightArm
        const from = scene.view.mapFrom3DScene(a.hand.mapPositionToScene(Qt.vector3d(0, 0, 0)))
        const tip = scene.view.mapFrom3DScene(a.hand.mapPositionToScene(a.indexTip))
        return Math.hypot(tip.x - from.x, tip.y - from.y)
    }

    // --- verbs, state, readout ------------------------------------------------------------------
    function verbs() {
        return {
            "pose":    (p) => { scene.pose = p === undefined || p === null ? "relax" : p },
            "arm":     (a) => { scene.arm = a === undefined || a === null ? "clear" : a },
            "subject": (s) => { scene.subject = s === "plain" ? "plain" : "articulated" },
            "build":   (b) => { scene.build = scene.buildRow(b).name },
            "gloves":  (on) => { scene.gloves = on === undefined ? true : !!on },
            "fingers": (on) => { scene.fingers = on === undefined ? true : !!on }
        }
    }
    readonly property var choices: [
        { verb: "pose", key: "choice.pose", current: scene.pose,
          options: ["relax", "open", "point", "thumbsUp", "fist"].map(
                       v => ({ value: v, key: "pose." + v })) },
        { verb: "arm", key: "choice.arm", current: scene.arm,
          options: ["clear", "point", "high", "level", "down"].map(
                       v => ({ value: v, key: "arm." + v })) },
        { verb: "subject", key: "choice.subject", current: scene.subject,
          options: ["articulated", "plain"].map(v => ({ value: v, key: "subject." + v })) },
        { verb: "build", key: "choice.build", current: scene.build,
          options: scene.builds.map(b => ({ value: b.name, key: "build." + b.name })) },
        { verb: "fingers", key: "choice.detail", current: scene.fingers,
          options: [{ value: true, key: "detail.high" }, { value: false, key: "detail.low" }] },
        { verb: "gloves", key: "choice.gloves", current: scene.gloves,
          options: [{ value: false, key: "gloves.off" }, { value: true, key: "gloves.on" }] }
    ]
    function choiceState() {
        return { pose: pose, arm: arm, subject: subject, build: build,
                 gloves: gloves, fingers: fingers }
    }
    function loadChoices(s) {
        if (!s) return
        if (s.pose !== undefined) pose = s.pose
        if (s.arm !== undefined) arm = s.arm
        if (s.subject !== undefined) subject = s.subject
        if (s.build !== undefined) build = s.build
        if (s.gloves !== undefined) gloves = !!s.gloves
        if (s.fingers !== undefined) fingers = !!s.fingers
    }

    /*! Everything the bench printed, as numbers. */
    function report() {
        return {
            subject: scene.subject, pose: scene.pose, arm: scene.arm,
            held: scene.subjectFigure.rightArm.handPose,
            build: scene.build, mass: scene.buildNow.mass, muscle: scene.buildNow.muscle,
            handBuild: pHandBuild.value, palmArm: scene.palmArm,
            gloves: scene.gloves, handScale: scene.gloves ? 1.45 : 1.0,
            fingers: scene.fingers, scale: pScale.value,
            figurePx: scene.figurePx(), fingerPx: scene.fingerPx(),
            ready: scene.ready
        }
    }
    /*! The card's rows, translated at call time. */
    function readout() {
        const r = scene.report()
        return [
            { key: "read.palmArm", value: LabLang.num(r.palmArm, 2) },
            { key: "read.figurePx", value: LabLang.num(r.figurePx, 0) + " px" },
            { key: "read.fingerPx", value: LabLang.num(r.fingerPx, 0) + " px" },
            { key: "read.posed", value: LabLang.t("pose." + r.held) }
        ]
    }

    // Which hand is which, over each figure's head.
    readonly property var labels: {
        LabLang.lang
        const y = scene.bodyHeight * 1.2 * pScale.value
        return [
            { at: Qt.vector3d(-scene.spread * 0.5, y, 0),
              text: LabLang.t("subject.articulated"), above: true },
            { at: Qt.vector3d(scene.spread * 0.5, y, 0),
              text: LabLang.t("subject.plain"), above: true }
        ]
    }

    // --- the two figures ----------------------------------------------------------------------
    component Figure: ParametricCharacter {
        bodyHeight: scene.bodyHeight
        realism: 0.0
        maturity: 0.15
        femininity: 0.2
        mass: scene.buildNow.mass
        muscle: scene.buildNow.muscle
        handBuildResponse: pHandBuild.value
        scale: Qt.vector3d(pScale.value, pScale.value, pScale.value)
        handPose: scene.pose
        // Auto has nothing to measure against without it.
        view: scene.view
        gloves: scene.gloves
        handScale: scene.gloves ? 1.45 : 1.0
        activity: Character.Activity.Idle
        autoBlink: false
        gazeBehaviour: false

        // The IRIS colour, not the white of the eye - the white is drawn by the
        // face shader and is not a property at all. At #ffffff the irises were
        // painted white on a white eye and the figure came out with no pupils.
        skinColor: scene.silhouette ? LabTheme.ink : "#d38d5f"
        handColor: scene.silhouette ? LabTheme.ink : "#d38d5f"
        footColor: scene.silhouette ? LabTheme.ink : "#b5764a"
        eyeColor: scene.silhouette ? LabTheme.ink : "#4a3728"
        hairColor: scene.silhouette ? LabTheme.ink : "#5c3a21"
        torsoColor: scene.silhouette ? LabTheme.ink : "#3663c8"
        armColor: scene.silhouette ? LabTheme.ink : "#3663c8"
        hipColor: scene.silhouette ? LabTheme.ink : "#5a6b7d"
        legColor: scene.silhouette ? LabTheme.ink : "#5a6b7d"
    }

    // The one under the microscope. basePos, not x: BodyPart binds position to
    // basePos, so an x of its own is overwritten the moment anything
    // re-evaluates.
    Figure {
        id: high
        name: "articulated"
        objectName: "articulated"
        basePos: Qt.vector3d(-scene.spread * 0.5, 0, 0)
        detail: scene.fingers ? Character.Detail.High : Character.Detail.Low
    }

    // The same character with the plain box hand, for the far read. Off to the
    // side rather than behind: at the working distance the two have to be
    // comparable in one glance, not one after the other.
    Figure {
        id: low
        name: "plain"
        objectName: "plain"
        basePos: Qt.vector3d(scene.spread * 0.5, 0, 0)
        detail: Character.Detail.Low
    }
}
