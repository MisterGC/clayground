// (c) Clayground Contributors - MIT License, see "LICENSE" file
//
// ActionStage - the two whole-body actions, Using and Fighting, the way the
// hand bench shows a hand: ONE figure, close, orbitable, and MOVING. The
// gesture sheet freezes those cycles as columns of stills, which is where a
// pose is judged; this is where the timing is judged, because a punch that
// snaps and a punch that floats freeze to the same picture.
//
// Everything on screen comes from action.js: every step the figure is posed
// with applyActionPose(action, phase) at the phase THE LAB'S CLOCK stands in,
// and the hands are set from actionPoseAt(action, phase).hand because
// applyActionPose does not write them. The figure's own activity stays Idle -
// the cycle is played by the clock, not by the plugin's animator - so pausing
// the transport freezes a frame and stepping it scrubs the cycle, and two
// runs of one seed put the fists in the same place.
//
// PROPS. The work has a table under it and the fight a bag in front of it, at
// the height and distance the model thinks it is working at, because "the
// hands are on the work" and "the fists sit where a guard sits" are both
// claims about a relation to something, and an empty room has nothing to be
// related to. The props verb takes them away for a silhouette read.
//
// HOW TO READ IT. The readings measure the hands against the body in the
// figure's own frame and in HEAD HEIGHTS: the fist's height over its own
// shoulder, how far it reaches forward, and how far it is from the chin. A
// guard is a claim about exactly those - fists at the cheeks, in front of the
// face, above the elbows - and a working posture about the same numbers lower
// down. They are read off the joints, so they live in report() and the card;
// what the record carries is the pure pose model at the clock's phase.
import QtQuick
import QtQuick3D
import Clayground.Canvas3D
import Clayground.Character3D
import Clayground.Lab
import "sheet.js" as Sheet

Node {
    id: scene

    // --- the contract: identity, what the lab drives ---------------------------
    readonly property string aspect: "action"
    property real time: 0
    property var view: null
    property bool silhouette: false

    // --- choices (strings and flags) --------------------------------------------
    /*! "fight" or "use". */
    property string action: "fight"
    /*! One of the four builds an action is worth watching on. */
    property string build: "neutral"
    /*! Fingers or a single box for the hands. */
    property bool fingers: true
    /*! The table under the work and the bag in front of the guard. */
    property bool props: true

    // --- knobs (numbers) ----------------------------------------------------------
    Parameter { id: pIntensity; name: "intensity"; value: 0.5; from: 0; to: 1 }
    Parameter { id: pWorkHeight; name: "workHeight"; value: 0.35; from: 0; to: 1 }

    readonly property real bodyHeight: 10

    /*! The builds worth watching an action on, as the two width sliders. */
    readonly property var builds: [
        { name: "neutral", mass: 0.5, muscle: 0.5 },
        { name: "thin",    mass: 0.1, muscle: 0.2 },
        { name: "heavy",   mass: 0.9, muscle: 0.4 },
        { name: "brawny",  mass: 0.6, muscle: 1.0 }
    ]
    function buildRow(name) {
        for (const b of scene.builds) if (b.name === name) return b
        return scene.builds[0]
    }
    readonly property var buildNow: scene.buildRow(scene.build)

    // --- framing --------------------------------------------------------------------
    // The figure, the name over its head and as much of the props as stands
    // beside it: the bag hangs from above the frame and the rope is not framed.
    function bounds() {
        return [Qt.vector3d(-scene.bodyHeight * 0.6, 0, -scene.bodyHeight * 0.5),
                Qt.vector3d(scene.bodyHeight * 0.6, scene.bodyHeight * 1.4, scene.bodyHeight * 0.65)]
    }
    readonly property var shots: ({
        "quarter": { yaw: 35, pitch: 8 },
        "front":   { yaw: 0,  pitch: 6 },
        "side":    { yaw: 90, pitch: 6 },
        "top":     { yaw: 30, pitch: 84 }
    })
    readonly property string defaultShot: "quarter"
    readonly property real nearest: 3
    readonly property real plotWindow: 4

    // --- the cycle, played by the clock ------------------------------------------------
    // The cycle length is read off the character's own derived table, so it
    // follows the intensity knob and the build the way the shipped animator
    // would.
    readonly property real cycleS: {
        pIntensity.value; pWorkHeight.value; scene.buildNow
        return subject.actionTable(scene.action).cycleMs / 1000
    }
    readonly property real phase: Sheet.phaseOf(scene.time, scene.cycleS)
    function poseNow() { return subject.actionPoseAt(scene.action, scene.phase) }

    /*! True once the first pose is on the joints; the lab waits for it. */
    property bool posed: false
    readonly property bool ready: scene.posed

    // The first pose has to wait out IdleAnim, which zeroes every joint over
    // its first 200 ms - hence the timer. Every later change poses
    // SYNCHRONOUSLY, so a capture on any frame after it is current.
    function apply() {
        subject.handPose = scene.poseNow().hand
        subject.applyActionPose(scene.action, scene.phase)
    }
    // Never restarts the timer: the clock changes `time` every frame while it
    // runs, and a timer restarted on every change is a timer that never fires
    // - the figure would stand at attention for as long as the clock ran.
    function pose() { if (scene.posed) scene.apply() }
    Timer {
        id: _first
        interval: 300
        onTriggered: { scene.apply(); scene.posed = true }
    }
    Component.onCompleted: _first.start()
    onTimeChanged: scene.pose()
    onActionChanged: scene.pose()
    Connections {
        target: pIntensity
        function onValueChanged() { scene.pose() }
    }
    Connections {
        target: pWorkHeight
        function onValueChanged() { scene.pose() }
    }

    // --- the numbers ---------------------------------------------------------------------
    // PURE: the pose model at the phase the clock stands in, never the joints -
    // the joints carry the hands' own settle, which is wall-clock.
    Probe { name: "action.phase"; expr: () => scene.phase }
    Probe { name: "action.cycle"; unit: "s"; expr: () => scene.cycleS }
    Probe { name: "action.armPitch"; unit: "deg"; expr: () => scene.poseNow().rightArm.upper[0] }
    Probe { name: "action.elbow"; unit: "deg"; expr: () => scene.poseNow().rightArm.lower[0] }
    Probe { name: "action.trunkYaw"; unit: "deg"; expr: () => scene.poseNow().torso[1] }

    /*!
        The fists against the body, in the figure's own frame and in HEAD
        HEIGHTS: each fist as an offset from its own shoulder (x out from the
        centre line, y up, z forward) and its distance from the chin. Read off
        the JOINTS, so it carries the hands' settle and belongs here rather
        than in a probe.
    */
    function fists() {
        const c = subject
        const head = Math.max(0.01, c.headHeight)
        function local(node) { return c.mapPositionFromScene(node.scenePosition) }
        const chin = local(c.head).minus(Qt.vector3d(0, head * 0.45, 0))
        function one(arm, side) {
            const s = local(arm.upperArm)
            const h = local(arm.hand)
            return { dx: (h.x - s.x) / head * side, dy: (h.y - s.y) / head,
                     dz: (h.z - s.z) / head,
                     chin: Math.hypot(h.x - chin.x, h.y - chin.y, h.z - chin.z) / head }
        }
        return { right: one(c.rightArm, 1), left: one(c.leftArm, -1) }
    }

    // --- verbs, state, readout ---------------------------------------------------------------
    function verbs() {
        return {
            "action":  (a) => { scene.action = a === "use" ? "use" : "fight" },
            "build":   (b) => { scene.build = scene.buildRow(b).name },
            "fingers": (on) => { scene.fingers = on === undefined ? true : !!on },
            "props":   (on) => { scene.props = on === undefined ? true : !!on }
        }
    }
    readonly property var choices: [
        { verb: "action", key: "choice.action", current: scene.action,
          options: ["fight", "use"].map(v => ({ value: v, key: "action." + v })) },
        { verb: "build", key: "choice.build", current: scene.build,
          options: scene.builds.map(b => ({ value: b.name, key: "build." + b.name })) },
        { verb: "fingers", key: "choice.detail", current: scene.fingers,
          options: [{ value: true, key: "detail.high" }, { value: false, key: "detail.low" }] },
        { verb: "props", key: "choice.props", current: scene.props,
          options: [{ value: true, key: "props.on" }, { value: false, key: "props.off" }] }
    ]
    function choiceState() { return { action: action, build: build, fingers: fingers, props: props } }
    function loadChoices(s) {
        if (!s) return
        if (s.action !== undefined) action = s.action
        if (s.build !== undefined) build = s.build
        if (s.fingers !== undefined) fingers = !!s.fingers
        if (s.props !== undefined) props = !!s.props
    }

    /*! What is playing and where the hands are, language-neutral. */
    function report() {
        const p = scene.poseNow()
        const f = scene.fists()
        return {
            action: scene.action, build: scene.build, props: scene.props,
            fingers: scene.fingers, intensity: pIntensity.value, workHeight: pWorkHeight.value,
            cycleS: scene.cycleS, phase: scene.phase,
            armPitch: p.rightArm.upper[0], elbow: p.rightArm.lower[0], trunkYaw: p.torso[1],
            rightFist: f.right, leftFist: f.left,
            hand: subject.rightArm.handPose, ready: scene.ready
        }
    }
    /*! The card's rows, translated at call time. */
    function readout() {
        const r = scene.report()
        return [
            { key: "read.cycle", value: LabLang.qty(r.cycleS, "s", 2) },
            { key: "read.phase", value: LabLang.num(r.phase, 3) },
            { key: "read.fistHeight", value: LabLang.num(r.rightFist.dy, 2) + " " + LabLang.t("unit.headHeights") },
            { key: "read.fistReach", value: LabLang.num(r.rightFist.dz, 2) + " " + LabLang.t("unit.headHeights") },
            { key: "read.chin", value: LabLang.num(r.rightFist.chin, 2) + " " + LabLang.t("unit.headHeights") }
        ]
    }

    // What is playing, over the figure's head.
    readonly property var labels: {
        LabLang.lang
        return [{ at: Qt.vector3d(0, scene.bodyHeight * 1.27, 0),
                  text: LabLang.t("action." + scene.action), above: true }]
    }

    // --- the figure ------------------------------------------------------------------------------
    ParametricCharacter {
        id: subject
        bodyHeight: scene.bodyHeight
        mass: scene.buildNow.mass
        muscle: scene.buildNow.muscle
        realism: 0.3
        roundness: 0.15
        // Fixed, never Auto: a stage that let the figure decide how much hand
        // to draw would be judging two things at once.
        detail: scene.fingers ? Character.Detail.High : Character.Detail.Low
        autoBlink: false
        gazeBehaviour: false
        // Idle, on purpose: the cycle is written by the clock above, so a
        // paused transport is a frozen frame rather than an animator carrying
        // on underneath it.
        activity: Character.Activity.Idle
        actionIntensity: pIntensity.value
        workHeight: pWorkHeight.value

        skin: scene.silhouette ? LabTheme.ink : "#e8beac"
        topClothing: scene.silhouette ? LabTheme.ink : "#3d6fb4"
        bottomClothing: scene.silhouette ? LabTheme.ink : "#2c3e50"
        footColor: scene.silhouette ? LabTheme.ink : "#4a3728"
        hairTone: scene.silhouette ? LabTheme.ink : "#5c3a21"
        eyeTone: scene.silhouette ? LabTheme.ink : "#4a3728"

        onMassChanged: scene.pose()
        onMuscleChanged: scene.pose()
    }

    // --- the props -------------------------------------------------------------------------------
    // Where the model puts the hands at this work height, solved from the
    // table it is playing: the surface sits under the fingertips and runs from
    // a little behind the resting hands to where the reach goes. Anything else
    // and the figure works in the air over a table or through one.
    readonly property var work: {
        pWorkHeight.value; pIntensity.value; scene.buildNow
        return subject.actionTable("use")
    }
    readonly property real upperLen: subject.armHeight * 0.5
    readonly property real shoulderY: subject.legHeight + subject.footHeight
                                    + subject.hipHeight + subject.torsoHeight
    readonly property real rad: Math.PI / 180
    readonly property real handY: scene.shoulderY
                                - scene.upperLen * Math.cos(scene.work.upper * scene.rad)
                                - scene.upperLen * Math.cos((scene.work.upper + scene.work.elbow) * scene.rad)
    readonly property real handZ: scene.upperLen * Math.sin(scene.work.upper * scene.rad)
                                + scene.upperLen * Math.sin((scene.work.upper + scene.work.elbow) * scene.rad)
    readonly property real tableTop: scene.handY - subject.rightArm.handHeight * 1.7
    readonly property real tableZ: scene.handZ + scene.upperLen * 0.2

    // The table. Wide enough that a sideways reach still lands on it.
    Node {
        visible: scene.props && !scene.silhouette && scene.action === "use"
        Box3D {
            position: Qt.vector3d(0, scene.tableTop - 0.3, scene.tableZ)
            width: subject.shoulderWidth * 2.6
            height: 0.3
            depth: scene.upperLen * 1.6
            color: scene.silhouette ? LabTheme.ink : "#b48a5a"
            showEdges: true
            edgeColorFactor: 0.7
        }
        Repeater3D {
            model: 4
            Box3D {
                required property int index
                readonly property real sx: (index % 2 === 0 ? -1 : 1) * subject.shoulderWidth * 1.2
                readonly property real sz: (index < 2 ? -1 : 1) * scene.upperLen * 0.7
                position: Qt.vector3d(sx, 0, scene.tableZ + sz)
                width: 0.35
                height: scene.tableTop - 0.3
                depth: 0.35
                color: scene.silhouette ? LabTheme.ink : "#8d6a43"
                showEdges: true
                edgeColorFactor: 0.7
            }
        }
    }

    // The bag: hung a straight's reach in front of the chest, from above the
    // frame, its middle at the guard's height.
    Node {
        id: _bag
        visible: scene.props && !scene.silhouette && scene.action === "fight"
        // Its near face is where a straight lands: the punching shoulder comes
        // round to the centre line, the arm is all but straight and level, and
        // the fist is a hand's depth further.
        readonly property real face: subject.shoulderWidth * 0.22 + subject.armHeight * 0.92
                                   + subject.rightArm.handDepth
        readonly property real thick: subject.shoulderWidth * 0.5
        readonly property real base: scene.shoulderY - subject.torsoHeight
        readonly property real tall: subject.torsoHeight * 1.9
        // See-through, because a bag at a straight's reach sits square in front
        // of the figure from the very angle a guard is judged at.
        Box3D {
            position: Qt.vector3d(0, _bag.base, _bag.face + _bag.thick * 0.5)
            width: _bag.thick
            height: _bag.tall
            depth: _bag.thick
            color: scene.silhouette ? LabTheme.ink : "#8e3b3b"
            opacity: 0.55
            showEdges: true
            edgeColorFactor: 0.7
        }
        Box3D {
            position: Qt.vector3d(0, _bag.base + _bag.tall, _bag.face + _bag.thick * 0.5)
            width: 0.2
            height: scene.bodyHeight * 0.8
            depth: 0.2
            color: scene.silhouette ? LabTheme.ink : "#55545a"
        }
    }
}
