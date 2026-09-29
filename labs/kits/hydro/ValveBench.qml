// (c) Clayground Contributors - MIT License, see "LICENSE" file
//
// ValveBench - the kit's own visual test for the valve anatomy, and the one
// question it lives or dies by: at spread 0, is this the hydro kit's valve?
// The part on the board here IS HydroElement3D with `type: "valve"`, not a
// copy of it, so the anatomy cannot quietly drift away from the part a
// learner operates - if it does, this picture stops matching the board.
//
//   clayrender labs/kits/hydro/ValveBench.qml --out /tmp/valve-bench.png \
//       --size 900x600 --settle
//
// Keys: E come apart (0 -> 1 -> 2 -> assembled) · F walk the teaching order ·
// L name every piece / none · O open or shut the valve · 0 reset everything
// and the camera. Camera as everywhere else: right-drag turns, middle drags,
// wheel zooms, Space+left pans.
//
// --eval targets: flowActions() (explode, focus, label, valve, frame),
// report(), startFlow("valve"), and Lab.runFlow("valve") for the lesson.

import QtQuick
import QtQuick3D
import Clayground.Canvas3D
import Clayground.Lab
import "strings.js" as HydroStrings
import "valve.js" as Valve

Item {
    id: root
    anchors.fill: parent
    focus: true
    objectName: "valveBench"

    Component.onCompleted: {
        // vocabulary first, then the part that prints it
        LabLang.register(HydroStrings.dict)
        root.forceActiveFocus()
    }

    // One clock, so a stepped headless run and a live one see the same beats.
    SimClock { id: clock; seed: 7; fixedStep: 1 / 60 }

    // Where the focus walk stands: -1 is "nothing focused", and the walk ends
    // back there rather than looping straight into piece one, so there is
    // always a press that gives the whole valve back.
    property int focusAt: -1

    // The lesson's words for the pieces, by part id. The subject is handed
    // text and never looks anything up itself.
    readonly property var partLabels: {
        const out = ({})
        const ids = Valve.partIds()
        for (let i = 0; i < ids.length; ++i)
            out[ids[i]] = LabLang.t("anatomy." + ids[i])
        return out
    }

    // --- flow actions --------------------------------------------------------
    // One mutation API, three drivers: the keys below, the lesson and an
    // agent's --eval all go through these verbs. Each sets a GOAL; the eased
    // interpolants are read-only, which is what lets Lab.runFlow assert them
    // without an event loop.
    function flowActions() {
        return {
            "explode": (v) => { el.spread = v === undefined ? 1 : v },
            "focus": (id) => { el.focus = id === undefined || id === null ? "" : id },
            "label": (what) => root.setLabelled(what),
            "valve": (open) => { el.switchOn = open === undefined ? true : !!open },
            "frame": () => root.frameParts()
        }
    }

    // "all", "none", or a list of part ids.
    function setLabelled(what) {
        if (what === "all") el.labelled = "all"
        else if (what === undefined || what === null || what === "none") el.labelled = []
        else el.labelled = what
    }

    // Every piece where it is GOING, plus the ground square under the part, so
    // the camera holds the whole explosion before it has happened. The goal,
    // not the interpolant: a fit taken the instant `spread` is set would frame
    // the pieces where they still are and lose the column as it rises.
    function frameParts() {
        const pts = [Qt.vector3d(-5, 0, -5), Qt.vector3d(5, 0, 5)]
        const ids = el.anatomy ? el.anatomy.partIds : []
        for (let i = 0; i < ids.length; ++i) {
            const p = el.partAt(ids[i], el.spread)
            if (!p || p.x !== p.x) continue
            pts.push(p)
        }
        rig.fit(pts, { pitch: 24, pad: 1.25 })
    }

    // --- the keys ------------------------------------------------------------
    function cycleSpread() {
        el.spread = el.spread >= 1.5 ? 0 : (el.spread >= 0.5 ? 2 : 1)
    }
    function cycleFocus() {
        const ids = el.anatomy ? el.anatomy.idsInOrder() : []
        root.focusAt = root.focusAt + 1
        if (root.focusAt >= ids.length) { root.focusAt = -1; el.focus = "" }
        else el.focus = ids[root.focusAt]
    }
    function toggleLabels() {
        root.setLabelled(el.marks.length > 0 ? "none" : "all")
    }
    function toggleValve() { el.switchOn = !el.switchOn }

    function resetAll() {
        el.spread = 0
        el.focus = ""
        el.switchOn = true
        root.setLabelled("none")
        root.focusAt = -1
        rig.applyState({ yaw: 20, pitch: 28, distance: 26, px: 0, py: 3, pz: 0 })
    }

    // The bench's verification seam: goals, interpolants, and where every
    // piece's anchor actually is. `at` is what a claim about the picture is
    // checked against - a rim said to be above its spokes is two numbers, not
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
            focus: el.focus, focusNow: a ? a.focusNow : 0,
            animating: a ? a.animating : false,
            switchOn: el.switchOn, stages: a ? a.stages : 0,
            partIds: ids, order: a ? a.idsInOrder() : [], at: at,
            lines: a ? a.lines.length : 0,
            marks: el.marks.map((m) => [m.id, m.label])
        }
    }

    // --- the lesson ----------------------------------------------------------
    function flows() { return [valveFlow.flowId] }
    function startFlow(id) {
        if (id !== valveFlow.flowId) return false
        valveFlow.start()
        return true
    }

    Flow {
        id: valveFlow
        lab: root
        camera: rig
        flowId: "valve"
        titleKey: "flow.valve.title"

        FlowStep {
            key: "meet"
            demo: [["explode", 0], ["focus", ""], ["label", "none"], ["valve", true]]
            expect: () => el.spread === 0
        }
        FlowStep {
            key: "ports"
            demo: [["label", ["flange.in", "flange.out"]]]
            mark: ["flange.in", "flange.out"]
            expect: () => el.marks.length === 2
        }
        FlowStep {
            key: "shell"
            demo: [["explode", 1], ["frame"]]
            mark: ["handwheel"]
            expect: () => el.spread === 1 && el.anatomy.stages === 2
        }
        FlowStep {
            key: "inside"
            demo: [["explode", 2], ["frame"]]
            expect: () => el.spread === 2
        }
        FlowStep {
            key: "wheel"
            demo: [["focus", "handwheel.rim"]]
            mark: ["handwheel.rim"]
            expect: () => el.focus === "handwheel.rim"
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

    // --- the scene -----------------------------------------------------------
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

        // Close enough to read a 0.3-unit rim, which is what the near plane has
        // to be told about: the default is 10 units, and a part 5 across
        // vanishes into it long before the camera is near enough to see a spoke.
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
        CameraAnchorMark { pointer: nav }

        // The real component, not a copy of its valve: the control this bench
        // exists to be, and the thing that would drift if the anatomy were
        // built twice.
        HydroElement3D {
            id: el
            type: "valve"
            switchOn: true
            labels: root.partLabels
        }
    }

    OrbitInput3D { id: nav; rig: rig; view: view3d }
    GridMode { id: grid }

    // Screen space over the scene, so a ring is never depth-tested against the
    // piece it is naming.
    MarkLayer {
        anchors.fill: parent
        view: view3d
        camera: view3d.camera
        marks: el.marks
    }

    LabPanel {
        id: question
        objectName: "question"
        x: LabTheme.px(12); y: LabTheme.px(12)
        width: LabTheme.px(230)
        title: LabLang.t("bench.valve.title")
        tag: "?"
        Text {
            // the panel's body, not `parent`: a stacked child is laid out by
            // the column and has no width of its own to wrap against
            width: question.body.width
            wrapMode: Text.WordWrap
            text: LabLang.t("bench.valve.question")
            color: LabTheme.inkSoft
            font.pixelSize: LabTheme.fontSmall
            font.family: LabTheme.monoFont
        }
    }

    // What the mechanism is doing, in numbers. Three of the pieces, because
    // the one thing a reader has to be able to check by eye is that the valve
    // comes apart in the right order: the wheel first, then the stem and the
    // rim inside it.
    LabPanel {
        objectName: "state"
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: LabTheme.px(12)
        width: LabTheme.px(230)
        title: "STATE"
        Text {
            readonly property vector3d ps: el.partAt("stem")
            readonly property vector3d pw: el.partAt("handwheel")
            readonly property vector3d pr: el.partAt("handwheel.rim")
            text: "spread    " + el.spread.toFixed(2)
                + "\nspreadNow " + (el.anatomy ? el.anatomy.spreadNow.toFixed(3) : "-")
                + "\nfocus     " + (el.focus === "" ? "-" : el.focus)
                + "\nstages    " + (el.anatomy ? el.anatomy.stages : 0)
                + "\nparts     " + (el.anatomy ? el.anatomy.partIds.length : 0)
                + "\nlabelled  " + el.marks.length
                + "\nstem      " + ps.x.toFixed(2) + " " + ps.y.toFixed(2) + " " + ps.z.toFixed(2)
                + "\nwheel     " + pw.x.toFixed(2) + " " + pw.y.toFixed(2) + " " + pw.z.toFixed(2)
                + "\nrim       " + pr.x.toFixed(2) + " " + pr.y.toFixed(2) + " " + pr.z.toFixed(2)
            color: LabTheme.inkSoft
            font.pixelSize: LabTheme.fontSmall
            font.family: LabTheme.monoFont
        }
    }

    LabKeys {
        id: keymap
        lab: root
        camera: rig
        pointer: nav
        keys: [
            { key: "E", label: "come apart: outside off, then inside, then back",
              action: () => root.cycleSpread() },
            { key: "F", label: "focus the next piece in teaching order",
              action: () => root.cycleFocus() },
            { key: "L", label: "name every piece / none",
              action: () => root.toggleLabels() },
            { key: "O", label: "open or shut the valve",
              action: () => root.toggleValve() }
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
