// (c) Clayground Contributors - MIT License, see "LICENSE" file
//
// AnatomyBench - the kit's own bench for the transistor anatomy, and it exists
// to ask ONE question: at spread 0, is this the circuit kit's transistor? The
// part on the board here is the real CircuitElement3D, not a copy of it, so the
// answer cannot drift: whatever the element draws at rest is what comes apart.
// If a learner has to be told the two are the same part, the explosion explains
// a model rather than the thing on the board.
//
//   clayrender labs/kits/circuit/AnatomyBench.qml --out /tmp/anatomy.png \
//       --size 900x600 --settle
//
// Keys: E take it apart, one stage per press (package, then the inside) ·
// X ghost the epoxy · F walk the teaching order · L name every part ·
// T the lesson · 0 reset everything and the camera. Camera as everywhere else:
// right-drag turns, middle drags, wheel zooms, Space+left pans.
//
// --eval targets: flowActions() (explode, xray, focus, label, frame),
// report(), flows(), startFlow(id).

import QtQuick
import QtQuick3D
import Clayground.Canvas3D
import Clayground.Lab
import "anatomy.js" as Anatomy
import "strings.js" as CircuitStrings

Item {
    id: root
    anchors.fill: parent
    focus: true
    objectName: "anatomyBench"

    Component.onCompleted: {
        // Vocabulary first, then anything that reads it.
        LabLang.register(CircuitStrings.dict)
        root.forceActiveFocus()
    }

    // One clock, so a stepped headless run and a live one see the same beats.
    SimClock { id: clock; seed: 7; fixedStep: 1 / 60 }

    // Where the focus walk stands: -1 is "nothing focused", and the walk ends
    // back there rather than looping straight into part one, so there is always
    // a press that gives the whole part back.
    property int focusAt: -1

    // The lesson's vocabulary, by part id - data the element is handed, because
    // a kit part does not choose a language. Re-read when the language changes.
    readonly property var partLabels: {
        LabLang.lang
        const out = ({})
        const ids = Anatomy.partIds()
        for (let i = 0; i < ids.length; ++i) out[ids[i]] = LabLang.t("anatomy." + ids[i])
        return out
    }

    readonly property bool labelsOn: el.labelled === "all"

    // --- what a press does ---------------------------------------------------
    // Every one of these goes through a flow verb, so the keys, the buttons and
    // an agent's --eval drive the bench through exactly one API.

    function nextSpread() {
        const stages = el.anatomy ? el.anatomy.stages : 1
        const next = el.spread >= stages - 0.01 ? 0 : Math.floor(el.spread) + 1
        root.flowActions()["explode"](next)
    }
    function toggleXray() {
        root.flowActions()["xray"](el.xray > 0.5 ? 0 : 0.75)
    }
    function cycleFocus() {
        const ids = el.anatomy ? el.anatomy.idsInOrder() : []
        root.focusAt = root.focusAt + 1
        if (root.focusAt >= ids.length) root.focusAt = -1
        root.flowActions()["focus"](root.focusAt < 0 ? "" : ids[root.focusAt])
    }
    function toggleLabels() {
        root.flowActions()["label"](root.labelsOn ? "none" : "all")
    }
    function resetAll() {
        root.flowActions()["explode"](0)
        root.flowActions()["xray"](0)
        root.flowActions()["focus"]("")
        root.flowActions()["label"]("none")
        root.focusAt = -1
        rig.applyState({ yaw: 20, pitch: 28, distance: 26, px: 0, py: 3, pz: 0 })
    }

    // --- flow actions --------------------------------------------------------
    // One mutation API, three drivers: the buttons below, the lesson and an
    // agent's eval. Each sets a GOAL; the eased interpolants are read-only,
    // which is what lets Lab.runFlow assert them without an event loop.
    function flowActions() {
        return {
            "explode": (v) => { el.spread = v === undefined ? 1 : v },
            // 1 would delete the case (opacity is 1 - xray); a ghost keeps the
            // part recognisable
            "xray":    (v) => { el.xray = v === undefined ? 0.75 : v },
            "focus":   (id) => { el.focus = id === undefined || id === null ? "" : id },
            "label":   (what) => root.label(what),
            "frame":   () => root.frameAll()
        }
    }

    // "all", "none", or a list of part ids.
    function label(what) {
        if (what === undefined || what === null || what === "none") el.labelled = []
        else if (what === "all") el.labelled = "all"
        else el.labelled = what
    }

    // Frames where every part is GOING, not where it is: the camera has to hold
    // the whole explosion from the first frame of it, and partAt(id, spread)
    // answers the goal. The ground square goes in as well, so a nearly
    // assembled part is not framed so tightly that the board it stands on
    // leaves the picture.
    function frameAll() {
        const pts = []
        const ids = el.anatomy ? el.anatomy.partIds : []
        for (let i = 0; i < ids.length; ++i) {
            const p = el.partAt(ids[i], el.spread)
            if (p.x === p.x) pts.push(p)     // NaN is the only value unequal to itself
        }
        const g = 5
        pts.push(Qt.vector3d(-g, 0, -g), Qt.vector3d(g, 0, -g),
                 Qt.vector3d(-g, 0, g), Qt.vector3d(g, 0, g))
        return rig.fit(pts, { pitch: 24, pad: 1.25 })
    }

    // The bench's verification seam: goals, the interpolants, and where every
    // part's anchor actually is. `at` is what a claim about the picture is
    // checked against - a slab said to be above another one is two numbers, not
    // a screenshot.
    function report() {
        const a = el.anatomy
        const ids = a ? a.partIds : []
        const at = ({})
        for (let i = 0; i < ids.length; ++i) {
            const p = el.partAt(ids[i])
            at[ids[i]] = [p.x, p.y, p.z]
        }
        return {
            spread: el.spread, spreadNow: a ? a.spreadNow : 0,
            xray: el.xray, xrayNow: a ? a.xrayNow : 0,
            focus: el.focus, focusNow: a ? a.focusNow : 0,
            animating: a ? a.animating : false,
            stages: a ? a.stages : 0,
            partIds: ids, order: a ? a.idsInOrder() : [], at: at,
            lines: a ? a.lines.length : 0,
            marks: el.marks.map((m) => [m.id, m.label])
        }
    }

    function flows() { return [anatomyFlow.flowId] }
    function startFlow(id) {
        if (id !== anatomyFlow.flowId) return false
        anatomyFlow.start()
        return true
    }

    // Keeping your place across a reload - the loader captures this from the
    // outgoing root and applies it to the new one, so editing a slab's
    // thickness does not throw away the pose you were judging it from. The
    // flow uses the same two functions for its per-step checkpoints.
    function viewState() {
        return { spread: el.spread, xray: el.xray, focus: el.focus,
                 labelled: el.labelled, focusAt: root.focusAt, cam: rig.state() }
    }
    function applyViewState(s) {
        if (!s) return
        if (s.spread !== undefined) el.spread = s.spread
        if (s.xray !== undefined) el.xray = s.xray
        if (s.focus !== undefined) el.focus = s.focus
        if (s.labelled !== undefined) el.labelled = s.labelled
        if (s.focusAt !== undefined) root.focusAt = s.focusAt
        if (s.cam) rig.applyState(s.cam)
    }

    View3D {
        id: view3d
        anchors.fill: parent
        camera: rig.camera
        environment: stage.environment

        LabStage3D {
            id: stage
            cellSize: 1
            majorEvery: 5
            gridMode: grid
            workExtent: Qt.vector2d(40, 40)
        }

        // Close enough to read a 0.2-unit slab, which is what the near plane
        // has to be told about: the default is 10 units and a part 4 across
        // vanishes into it long before the camera is near enough to see the die.
        OrbitCamera3D {
            id: rig
            view: view3d
            pivot: Qt.vector3d(0, 3, 0)
            homePivot: Qt.vector3d(0, 3, 0)
            yaw: 20; pitch: 28; distance: 26
            minDistance: 3; maxDistance: 120
            minHeight: 0.5
            Component.onCompleted: rig.camera.clipNear = 0.5
        }

        // The real part, at the origin: the bench's whole claim is that this
        // one component is both the thing on the board and the thing that
        // comes apart.
        CircuitElement3D {
            id: el
            type: "transistor"
            mode: "active"
            position: Qt.vector3d(0, 0, 0)
            labels: root.partLabels
        }
    }

    OrbitInput3D { id: nav; rig: rig; view: view3d }
    GridMode { id: grid }

    // Outside the View3D: the rings are screen furniture over the scene, not
    // geometry in it.
    MarkLayer {
        id: markLayer
        objectName: "markLayer"
        anchors.fill: parent
        view: view3d
        camera: view3d.camera
        marks: el.marks
    }

    LabPanel {
        id: controls
        objectName: "controls"
        x: LabTheme.px(12); y: LabTheme.px(12)
        width: LabTheme.px(215)
        title: LabLang.t("bench.anatomy.title")
        tag: "Q"

        component BenchButton: Rectangle {
            id: btn
            property string label: ""
            property bool active: false
            signal hit()
            width: controls.body.width
            height: LabTheme.px(24)
            radius: LabTheme.px(4)
            color: btn.active ? LabTheme.secondary
                 : hover.containsMouse ? LabTheme.step(LabTheme.panel, 1.2)
                                       : LabTheme.panel
            border.color: LabTheme.panelEdge
            border.width: Math.max(1, LabTheme.uiScale)
            Text {
                anchors.left: parent.left
                anchors.leftMargin: LabTheme.spaceL
                anchors.verticalCenter: parent.verticalCenter
                text: btn.label
                color: btn.active ? LabTheme.inkOn(LabTheme.secondary) : LabTheme.ink
                font.pixelSize: LabTheme.fontSmall
                font.family: LabTheme.monoFont
            }
            MouseArea {
                id: hover
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: { root.forceActiveFocus(); btn.hit() }
            }
        }

        BenchButton {
            label: el.spread > 0.01 ? LabLang.t("bench.anatomy.together")
                                    : LabLang.t("bench.anatomy.apart")
            active: el.spread > 0.01
            onHit: root.nextSpread()
        }
        BenchButton {
            label: el.xray > 0.5 ? LabLang.t("bench.anatomy.xray.off")
                                 : LabLang.t("bench.anatomy.xray.on")
            active: el.xray > 0.5
            onHit: root.toggleXray()
        }
        BenchButton {
            label: root.labelsOn ? LabLang.t("bench.anatomy.labels.off")
                                 : LabLang.t("bench.anatomy.labels.on")
            active: root.labelsOn
            onHit: root.toggleLabels()
        }
        Item { width: 1; height: LabTheme.spaceM }
        BenchButton {
            label: LabLang.t("bench.anatomy.focus") + ": "
                   + (el.focus === "" ? "-" : el.focus) + " (F)"
            active: el.focus !== ""
            onHit: root.cycleFocus()
        }
        BenchButton {
            label: LabLang.t("bench.anatomy.reset")
            onHit: root.resetAll()
        }
    }

    // What the mechanism is doing, in numbers. Three of the eight taught parts,
    // because the one thing a reader has to be able to check by eye is that the
    // die comes apart in the right order.
    LabPanel {
        objectName: "state"
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: LabTheme.px(12)
        width: LabTheme.px(210)
        title: LabLang.t("bench.anatomy.state")
        Text {
            readonly property vector3d pc: el.partAt("die.collector")
            readonly property vector3d pb: el.partAt("die.base")
            readonly property vector3d pe: el.partAt("die.emitter")
            function triple(v) {
                return v.x !== v.x ? "-"
                     : v.x.toFixed(2) + " " + v.y.toFixed(2) + " " + v.z.toFixed(2)
            }
            text: "spread    " + el.spread.toFixed(2)
                + "\nspreadNow " + (el.anatomy ? el.anatomy.spreadNow.toFixed(3) : "-")
                + "\nxray      " + el.xray.toFixed(2)
                + "\nmoving    " + (el.anatomy ? el.anatomy.animating : false)
                + "\nfocus     " + (el.focus === "" ? "-" : el.focus)
                + "\nstages    " + (el.anatomy ? el.anatomy.stages : 0)
                + "\nparts     " + (el.anatomy ? el.anatomy.partIds.length : 0)
                + "\nlabelled  " + el.marks.length
                + "\ndie.coll  " + triple(pc)
                + "\ndie.base  " + triple(pb)
                + "\ndie.emit  " + triple(pe)
            color: LabTheme.inkSoft
            font.pixelSize: LabTheme.fontSmall
            font.family: LabTheme.monoFont
        }
    }

    // --- the lesson ----------------------------------------------------------
    // Seven steps, each one a goal the next expect can assert: the package
    // comes off in stage 1, the inside comes apart in stage 2, and the part is
    // put back at the end so the bench is left the way it was found.
    Flow {
        id: anatomyFlow
        lab: root
        camera: rig
        flowId: "anatomy"
        titleKey: "flow.anatomy.title"

        FlowStep {
            key: "meet"
            demo: [["explode", 0], ["xray", 0], ["focus", ""], ["label", "none"]]
            expect: () => el.spread === 0
        }
        FlowStep {
            key: "legs"
            demo: [["label", ["leg.collector", "leg.base", "leg.emitter"]]]
            mark: ["leg.collector", "leg.base", "leg.emitter"]
            expect: () => el.marks.length === 3
        }
        FlowStep {
            key: "shell"
            demo: [["explode", 1], ["frame"]]
            mark: ["case"]
            expect: () => el.spread === 1 && el.anatomy.stages === 2
        }
        FlowStep {
            key: "inside"
            demo: [["explode", 2], ["frame"]]
            expect: () => el.spread === 2
        }
        FlowStep {
            key: "layers"
            demo: [["focus", "die.base"]]
            mark: ["die.base"]
            expect: () => el.focus === "die.base"
        }
        FlowStep {
            key: "named"
            demo: [["label", "all"]]
            expect: () => el.marks.length === el.anatomy.idsInOrder().length
        }
        FlowStep {
            key: "close"
            demo: [["focus", ""], ["label", "none"], ["explode", 0]]
            expect: () => el.spread === 0 && el.focus === "" && el.marks.length === 0
        }
    }

    LabKeys {
        id: keymap
        lab: root
        camera: rig
        pointer: nav
        flow: anatomyFlow
        keys: [
            { key: "E", label: "bench.anatomy.key.explode",
              action: () => root.nextSpread() },
            { key: "X", label: "bench.anatomy.key.xray",
              action: () => root.toggleXray() },
            { key: "F", label: "bench.anatomy.key.focus",
              action: () => root.cycleFocus() },
            { key: "L", label: "bench.anatomy.key.labels",
              action: () => root.toggleLabels() }
        ]
    }
    LabHelp { keymap: keymap; anchors.centerIn: parent; width: LabTheme.px(300) }

    // 0 is the bench's own, not a LabKeys entry: LabKeys only dispatches
    // LETTERS to a lab, and the digit is already the camera's reset - which is
    // half of what "reset" has to mean here, so the bench does both and keeps
    // the key.
    Keys.onPressed: (ev) => {
        if (ev.key === Qt.Key_0 && !(ev.modifiers & Qt.ControlModifier)) {
            root.resetAll()
            ev.accepted = true
            return
        }
        keymap.handle(ev)
    }
    Keys.onReleased: (ev) => keymap.handleRelease(ev)
}
