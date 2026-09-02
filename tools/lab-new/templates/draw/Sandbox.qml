// (c) Clayground Contributors - MIT License, see "LICENSE" file

import QtQuick
import QtQuick3D
import Clayground.Canvas3D
import Clayground.Lab
import "strings.js" as Strings

// {{Title}} - a sheet you draw lines on. Started {{date}} from tools/lab-new
// (kind: draw, purpose: {{purpose}}).
//
// THIS IS A STARTING POINT, NOT A LAB. Everything below is real and runs, so
// you can change one thing at a time and keep a loadable lab throughout. What
// is yours to replace: what a segment MEANS, what is derived from the drawing,
// the scenarios, the flow narration and every string in strings.js. What is
// NOT yours to replace: the conventions block, the key map, the HUD slots and
// the gesture rule below.
//
// INTERACTION, IN ONE RULE: A CLICK SELECTS, A DRAG DRAWS. Nothing is decided
// on press, because on press we do not yet know which it is - the press only
// remembers where it grabbed, and the first real movement commits. The LEFT
// BUTTON IS ALWAYS THE SHEET'S: navigation never competes for it. Right-drag
// turns the world about the point under the cursor, a right CLICK cancels, the
// middle button drags the world, the wheel zooms towards the cursor, and
// holding Space pans on the left button while held.
//
// The gesture lives in NAMED functions (pressAt / moveAt / releaseAt /
// clickAt / dragFrom) rather than in the signal handlers, because the
// inspector can synthesize a click but not a drag - and drawing is the one
// thing this lab is for. A flow, a test and an agent perform the same drag a
// hand does.
//
// Keys: 1-2 presets · T tour · C clear · E eraser · Del remove the selected ·
// # snap on/off · F frame the selection · 0 frame the sheet ·
// arrows/WASD travel · Shift+arrows turn · +/- zoom · Space holds the view ·
// Shift+R record · Ctrl +/-/0 text size · ? every key.
Item {
    id: root
    anchors.fill: parent
    focus: true

    // Register the dictionary BEFORE the first scenario: a scenario may set a
    // hint, and a lab that translates itself afterwards has already shown one
    // raw key. A kit's vocabulary would be registered on the line above.
    Component.onCompleted: {
        LabLang.register(Strings.dict)
        forceActiveFocus()
        applyScenario("intro")
    }

    // --- what is drawn ------------------------------------------------------
    // A plain JS list of plain objects: {id, x1, z1, x2, z2}. Plain because it
    // has to survive JSON - viewState carries the whole drawing, which is what
    // makes a reload and a flow checkpoint seamless.
    //
    // Every mutation ASSIGNS A NEW ARRAY. Mutating the existing one in place
    // emits no change signal, and the line batch below would silently keep
    // drawing the old set.
    property var segments: []
    property int segRev: 0              // for consumers that copy (WatchMonitor)
    property int nextId: 1
    property int selectedId: -1
    property bool eraser: false

    // the gesture in flight, read by the preview line
    property var drawFrom: null
    property var drawTo: null

    readonly property real hitRadius: 0.9
    readonly property int maxSegments: 40

    // WatchChip and WatchMark declare a property named `monitor`, which shadows
    // the id of the same name inside them - so `monitor: monitor` would assign
    // the property to itself and the chip would silently never appear. A second
    // name on the root is the fix.
    readonly property alias watchMonitor: monitor

    readonly property real totalLength: {
        segRev
        let sum = 0
        for (const s of segments) sum += Math.hypot(s.x2 - s.x1, s.z2 - s.z1)
        return sum
    }

    function lengthOf(id) {
        for (const s of segments)
            if (s.id === id) return Math.hypot(s.x2 - s.x1, s.z2 - s.z1)
        return 0
    }

    // --- the verbs the lab is operated with ---------------------------------
    // The UI calls these, a flow calls these, an agent calls these. No mutation
    // path goes behind their back.
    function addSegment(x1, z1, x2, z2) {
        if (Math.hypot(x2 - x1, z2 - z1) < 1e-6) return -1
        const seg = { id: nextId++, x1: x1, z1: z1, x2: x2, z2: z2 }
        segments = segments.concat([seg])
        segRev++
        selectedId = seg.id
        return seg.id
    }
    function removeSegment(id) {
        segments = segments.filter(s => s.id !== id)
        segRev++
        if (selectedId === id) selectedId = -1
        monitor.setWatched(id, false)
    }
    function clearAll() {
        segments = []
        segRev++
        selectedId = -1
        monitor.clear()
    }

    // Point-to-segment distance, so a click selects what it LOOKS like it is
    // over rather than what happens to be nearest an endpoint.
    function hitAt(x, z) {
        let best = -1, bestD = hitRadius
        for (const s of segments) {
            const dx = s.x2 - s.x1, dz = s.z2 - s.z1
            const len2 = dx * dx + dz * dz
            let t = len2 > 0 ? ((x - s.x1) * dx + (z - s.z1) * dz) / len2 : 0
            t = Math.max(0, Math.min(1, t))
            const d = Math.hypot(x - (s.x1 + t * dx), z - (s.z1 + t * dz))
            if (d < bestD) { bestD = d; best = s.id }
        }
        return best
    }

    // --- parameters ---------------------------------------------------------
    Parameter {
        id: pSnap
        name: "snapStep"; value: 1; from: 0.5; to: 4; stepSize: 0.5; unit: "m"
    }
    Parameter {
        id: pPenSpeed
        name: "penSpeed"; value: 3; from: 0; to: 12; unit: "m/s"
    }

    // The grid owns both rules - Alt inverting the mode for one gesture, and
    // the rounding itself - so every lab quantizes alike. `#` toggles it.
    GridMode { id: grid; step: pSnap.value }

    // --- the clock ----------------------------------------------------------
    // A drawing lab still has time in it: a pen walks the drawing at penSpeed,
    // which is what the probes measure and what makes a run record of this lab
    // mean something. Fixed steps, because a frame is a wall-clock interval.
    SimClock {
        id: clock
        seed: 42
        sampleInterval: 0.1
        fixedStep: 1 / 60
        onStepped: (dt) => root.stepSim(dt)
    }
    property real walked: 0
    function stepSim(dt) {
        if (totalLength <= 0) { walked = 0; return }
        walked += pPenSpeed.value * dt
        while (walked > totalLength) walked -= totalLength
    }
    // Where the pen is, as a pure function of `walked`: no state of its own, so
    // it can never disagree with the number the probe reports.
    function penPoint() {
        let left = walked
        for (const s of segments) {
            const len = Math.hypot(s.x2 - s.x1, s.z2 - s.z1)
            if (left <= len || len <= 0) {
                const t = len > 0 ? left / len : 0
                return Qt.vector3d(s.x1 + t * (s.x2 - s.x1), 0,
                                   s.z1 + t * (s.z2 - s.z1))
            }
            left -= len
        }
        return Qt.vector3d(0, -99, 0)     // nothing drawn: park it out of sight
    }

    // --- probes -------------------------------------------------------------
    Probe { name: "segments"; expr: () => root.segments.length }
    Probe { name: "length"; unit: "m"; expr: () => root.totalLength }
    Probe { name: "walked"; unit: "m"; expr: () => root.walked }

    // --- scenarios ----------------------------------------------------------
    // Applying one resets the clock and the RNG, so a script must reset
    // EVERYTHING a probe can see - here, the drawing itself.
    ScenarioSet {
        id: scenarioSet
        Scenario {
            name: "intro"; description: "one line already on the sheet"
            script: () => {
                root.clearAll()
                root.nextId = 1
                root.addSegment(-4, 0, 4, 0)
                root.selectedId = -1
                root.eraser = false
                root.walked = 0
            }
        }
        Scenario {
            name: "blank"; description: "an empty sheet"
            script: () => {
                root.clearAll()
                root.nextId = 1
                root.eraser = false
                root.walked = 0
            }
        }
    }

    // --- inspector / agent / flow conventions -------------------------------
    function scenarios() { return scenarioSet.names() }
    function applyScenario(n) { return scenarioSet.apply(n) }

    // Language-neutral: ids, numbers and types, never a translated label.
    function labInfo() {
        const info = Lab.labInfo()
        info.flow = { id: introFlow.running ? introFlow.flowId : "",
                      step: introFlow.index }
        info.segments = segments.length
        info.totalLength = totalLength
        info.selected = selectedId
        info.eraser = eraser
        return info
    }
    function flagInfo() { return labInfo() }

    // The user's WHOLE place, the drawing included - that is what makes the
    // fix loop and the flow checkpoints seamless.
    function viewState() {
        return Object.assign(Lab.viewState(), {
            cam: rig.state(),
            segments: segments,
            nextId: nextId,
            selected: selectedId,
            snap: grid.snap,
            lang: LabLang.lang
        })
    }
    // Ordering contract: (1) the scenario, because applying it resets clock +
    // RNG and repopulates the sheet, (2) the user's own drawing ON TOP of the
    // preset - serialized state wins, (3) Lab.applyViewState, which re-steps
    // the world-less clock, (4) the camera and the view-only toggles.
    function applyViewState(s) {
        if (!s) return
        if (s.scenario) applyScenario(s.scenario)
        if (s.segments) {
            segments = s.segments
            segRev++
            nextId = s.nextId !== undefined ? s.nextId : segments.length + 1
        }
        Lab.applyViewState(s)
        if (s.cam) rig.applyState(s.cam)
        if (s.selected !== undefined) selectedId = s.selected
        if (s.snap !== undefined) grid.snap = s.snap
        if (s.lang) LabLang.lang = s.lang
    }

    function flowActions() {
        return {
            "scenario": (n) => applyScenario(n),
            "setParam": (n, v) => Lab.set(n, v),
            "draw":     (x1, z1, x2, z2) => addSegment(x1, z1, x2, z2),
            "erase":    (id) => removeSegment(id),
            "clear":    () => clearAll(),
            "select":   (id) => { root.selectedId = id },
            "frame":    (what) => what === "selection" ? frameSelection()
                                                       : frameAll(),
            "record":   (on) => { recorder.recording = on }
        }
    }
    function flows() { return [introFlow.flowId] }
    function startFlow(id) {
        if (id === introFlow.flowId) { introFlow.start(); return true }
        return false
    }

    function frameAll() {
        rig.frame([Qt.vector3d(-9, 0, -7), Qt.vector3d(9, 0, 7)], 1.3)
    }
    function frameSelection() {
        for (const s of segments) {
            if (s.id !== selectedId) continue
            rig.frame([Qt.vector3d(Math.min(s.x1, s.x2) - 1, 0,
                                   Math.min(s.z1, s.z2) - 1),
                       Qt.vector3d(Math.max(s.x1, s.x2) + 1, 0,
                                   Math.max(s.z1, s.z2) + 1)], 1.3)
            return
        }
        frameAll()
    }

    // Shift+R writes a scratch record of a FRAME-driven run, which is not
    // reproducible and must never be quoted. The citable ones come from
    // records/make.sh, which steps the clock by hand.
    DataRecorder {
        id: recorder
        lab: "{{slug}}"
        destination: "labs/{{slug}}/records/session.labrec"
    }

    // --- the scene ----------------------------------------------------------
    View3D {
        id: view3d
        anchors.fill: parent
        environment: stage.environment
        camera: rig.camera

        LabStage3D {
            id: stage
            cellSize: pSnap.value
            majorEvery: 5
            workExtent: Qt.vector2d(20, 16)
            gridMode: grid                 // draws the snap cue while snapping
        }

        OrbitCamera3D {
            id: rig
            pivot: Qt.vector3d(0, 0, 0)
            yaw: 0; pitch: 55; distance: 26
            minPitch: 10; maxPitch: 88
            minDistance: 6; maxDistance: 90
            minHeight: 3
            homePivot: Qt.vector3d(0, 0, 0)
            panLeash: stage.workRadius * 1.2
        }
        CameraAnchorMark { pointer: nav }

        // The drawing. Flat and depth-biased, because these are markings ON the
        // sheet: a camera-facing ribbon splays on a corner and reads as a wall.
        // The selected one is drawn in the interactive colour and thicker.
        LineBatch3D {
            id: inkLayer
            widthUnits: LineBatch3D.World
            orientation: LineBatch3D.Flat
            opaque: true
            depthBias: stage.overlayMinBias + 2
            lines: {
                root.segRev
                const out = []
                for (const s of root.segments) {
                    const on = s.id === root.selectedId
                    out.push({ points: [Qt.vector3d(s.x1, stage.overlayY(1), s.z1),
                                        Qt.vector3d(s.x2, stage.overlayY(1), s.z2)],
                               color: on ? LabTheme.secondary : LabTheme.ink,
                               width: on ? 0.24 : 0.15,
                               styleId: 0 })
                }
                return out
            }
        }

        // The gesture in flight: what will be committed if the button comes up
        // now. Answering "where will this land?" before the release is most of
        // what makes a snapped drag feel like a tool rather than a guess.
        LineBatch3D {
            id: previewLayer
            visible: root.drawFrom !== null && root.drawTo !== null
            widthUnits: LineBatch3D.World
            orientation: LineBatch3D.Flat
            depthBias: stage.overlayMinBias + 4
            lines: root.drawFrom && root.drawTo
                   ? [{ points: [Qt.vector3d(root.drawFrom.x, stage.overlayY(2),
                                             root.drawFrom.z),
                                 Qt.vector3d(root.drawTo.x, stage.overlayY(2),
                                             root.drawTo.z)],
                        color: LabTheme.accent, width: 0.12, styleId: 0 }]
                   : []
        }

        // The pen walking the drawing - the one thing here the clock drives.
        Model {
            source: "#Sphere"
            visible: root.totalLength > 0
            position: root.penPoint()
            scale: Qt.vector3d(0.006, 0.006, 0.006)
            castsShadows: false
            materials: PrincipledMaterial {
                baseColor: LabTheme.highlight
                lighting: PrincipledMaterial.NoLighting
            }
        }
    }

    // --- navigation ---------------------------------------------------------
    // The left button is the sheet's, always - not "not while drawing", not
    // "not over a line", but always. The camera gets the right button, the
    // middle one, the wheel, the arrows, and the left button only while Space
    // is held (LabKeys drives that through `pointer`).
    OrbitInput3D {
        id: nav
        rig: rig
        view: view3d
    }

    MouseArea {
        id: sheetMouse
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
        cursorShape: nav.cursorShape

        property var pressW: null
        property string mode: ""      // "" until the first movement decides

        function worldAt(mx, my) { return stage.worldAt(view3d, mx, my) }
        function snapped(w, mods) {
            return { x: grid.quantize(w.x, mods), z: grid.quantize(w.z, mods) }
        }

        // Nothing is decided here: the press only remembers what it grabbed.
        function pressAt(mx, my, button, mods) {
            root.forceActiveFocus()
            nav.cancel()
            mode = ""; pressW = null
            root.drawFrom = null; root.drawTo = null
            // Ask the camera first, and with the default buttons the answer for
            // the left button is always no - so nothing below thinks about the
            // camera again and no press on the sheet can be stolen by it.
            if (nav.begin(mx, my, button, mods) !== "") { mode = "nav"; return }
            const w = worldAt(mx, my)
            if (!w) return                 // aimed at the sky
            pressW = { x: w.x, z: w.z }
            // The eraser is a mode and acts immediately - a modal tool that
            // waited for a drag would feel broken.
            if (root.eraser) {
                mode = "erase"
                const hit = root.hitAt(w.x, w.z)
                if (hit !== -1) root.removeSegment(hit)
            }
        }

        function moveAt(mx, my, mods, isDown) {
            if (isDown && mode === "nav") { nav.move(mx, my); return }
            if (!isDown) { nav.hoverAt(mx, my); return }
            if (mode === "erase") return
            const w = worldAt(mx, my)
            if (!w) return
            // First real movement decides what this gesture is. The slop is a
            // world distance, not a pixel one, so it means the same at every
            // zoom.
            if (mode === "" && pressW) {
                if (Math.hypot(w.x - pressW.x, w.z - pressW.z) < grid.step * 0.5)
                    return
                mode = "draw"
                root.drawFrom = snapped(pressW, mods)
            }
            if (mode === "draw") root.drawTo = snapped(w, mods)
        }

        function releaseAt() {
            if (mode === "nav") {
                nav.end()                  // a flicked drag coasts from here
            } else if (mode === "draw" && root.drawFrom && root.drawTo) {
                root.addSegment(root.drawFrom.x, root.drawFrom.z,
                                root.drawTo.x, root.drawTo.z)
            } else if (mode === "" && pressW) {
                // never moved: this was a click, so it selects (or clears)
                root.selectedId = root.hitAt(pressW.x, pressW.z)
            }
            root.drawFrom = null; root.drawTo = null
            pressW = null; mode = ""
        }

        // The whole gesture as one call, for a flow, a test or an agent - none
        // of which can hold a button down.
        function dragFrom(x1, y1, x2, y2, mods) {
            pressAt(x1, y1, Qt.LeftButton, mods || 0)
            moveAt(x2, y2, mods || 0, true)
            releaseAt()
        }
        function clickAt(x, y, mods) {
            pressAt(x, y, Qt.LeftButton, mods || 0)
            releaseAt()
        }

        onPressed: (m) => pressAt(m.x, m.y, m.button, m.modifiers)
        onPositionChanged: (m) => moveAt(m.x, m.y, m.modifiers, pressed)
        onReleased: releaseAt()
        onWheel: (w) => nav.wheel(w.angleDelta.y, w.x, w.y)
        onDoubleClicked: (m) => {
            const w = worldAt(m.x, m.y)
            if (w && root.hitAt(w.x, w.z) === -1) nav.recenterAt(m.x, m.y)
        }
    }

    // A right CLICK is "put it down" - the RTS cancel. One press walks back one
    // step: leave the eraser first, then drop the selection. A right DRAG still
    // turns the view and cancels nothing.
    Connections {
        target: nav
        function onCancelled() {
            if (root.eraser) { root.eraser = false; return }
            root.selectedId = -1
        }
    }

    // --- HUD: palette top-left ----------------------------------------------
    LabPanel {
        id: palette
        x: LabTheme.px(12); y: LabTheme.px(12)
        width: LabTheme.px(240)
        title: LabLang.t("lab.title")
        spacing: LabTheme.spaceS

        ScenarioBar { lab: root; width: palette.body.width }
        // The visible offer of the guided tour, from the first frame: a flow
        // nobody finds teaches nobody.
        FlowChip { flow: introFlow }

        Text {
            width: palette.body.width
            wrapMode: Text.WordWrap
            text: LabLang.tf("palette.count", root.segments.length,
                             LabLang.num(root.totalLength, 1))
            color: LabTheme.inkSoft
            font.pixelSize: LabTheme.fontSmall
            font.family: LabTheme.monoFont
        }
        WatchChip {
            visible: root.selectedId !== -1
            monitor: root.watchMonitor
            target: root.selectedId
        }
    }

    Compass {
        id: compass
        anchors.left: palette.left
        anchors.top: palette.bottom
        anchors.topMargin: LabTheme.px(10)
        yaw: rig.yaw
    }

    // --- HUD: language, size, theme top-right, parameters under them ---------
    Row {
        id: topSwitches
        anchors.right: parent.right; anchors.top: parent.top
        anchors.margins: LabTheme.px(10)
        spacing: LabTheme.spaceM
        LangSwitch { anchors.verticalCenter: parent.verticalCenter }
        ScaleSwitch { anchors.verticalCenter: parent.verticalCenter }
        ThemeSwitch { anchors.verticalCenter: parent.verticalCenter }
    }
    ParamPanel {
        id: params
        anchors.right: parent.right; anchors.top: topSwitches.bottom
        anchors.rightMargin: LabTheme.px(10); anchors.topMargin: LabTheme.px(10)
    }

    // --- HUD: the monitor, bottom-right --------------------------------------
    WatchMonitor {
        id: monitor
        anchors.right: parent.right; anchors.bottom: parent.bottom
        anchors.margins: LabTheme.px(10)
        idPrefix: "seg"
        quantities: [{ key: "len", label: "quantity.length", unit: "m" }]
        windowSeconds: 30
        placeholder: LabLang.t("plot.empty")
        valueOf: (id) => root.lengthOf(id)
        labelOf: (id) => "S" + id
        revision: root.segRev
    }

    // --- HUD: banner, hint bar, transport, recording -------------------------
    // Inactive on a fresh sheet: it only speaks once the drawing outgrows what
    // this template's arithmetic was written for.
    LabBanner {
        active: root.segments.length > root.maxSegments
        guard: palette
        text: LabLang.tf("banner.full", root.maxSegments)
    }
    HintBar {
        id: hintBar
        flow: introFlow
        rightGuard: monitor
        text: {
            if (root.eraser) return LabLang.t("hint.eraser")
            if (root.selectedId !== -1) return LabLang.t("hint.selected")
            return LabLang.t("hint.idle")
        }
    }
    TransportChip {
        id: transport
        clock: clock
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top; anchors.topMargin: LabTheme.spaceXl
    }
    RecIndicator {
        recorder: recorder
        anchors.left: parent.left; anchors.leftMargin: LabTheme.spaceXl
        anchors.bottom: parent.bottom; anchors.bottomMargin: LabTheme.spaceL
    }

    // --- the guided tour -----------------------------------------------------
    // Three steps, one of each kind: the lab acts, the learner acts, the lab
    // checks. Narration lives in strings.js under flow.<flowId>.<stepKey>.
    Flow {
        id: introFlow
        lab: root
        camera: rig
        flowId: "{{id}}-intro"
        titleKey: "flow.{{id}}-intro.title"

        // demo: the lab acts through its own verbs, the learner watches
        FlowStep {
            key: "intro"
            demo: [["scenario", "intro"], ["draw", -4, -3, 4, -3],
                   ["frame", "all"]]
        }
        // task: the learner acts. `until` is a predicate on LAB STATE, never on
        // a particular click, so there is more than one way to satisfy it - and
        // `solve` is the "show me" path, so nobody is stuck.
        FlowStep {
            key: "try"
            task: ({ "until": () => root.segments.length >= 3,
                     "hint": "flow.{{id}}-intro.try.hint",
                     "hintAfter": 8,
                     "solve": [["draw", -4, 3, 4, 3]] })
        }
        // expect: the assertion that makes the flow a test.
        FlowStep {
            key: "check"
            expect: () => root.totalLength > 0
        }
    }
    Narrator {
        flow: introFlow
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: LabTheme.px(10)
        // Centred, so its half-width is bounded by the NEARER panel - the
        // monitor on the right here. Capping against root.width instead lets a
        // German narration, a quarter longer than the English, slide under it.
        width: Math.max(LabTheme.px(280),
                        Math.min(LabTheme.px(680),
                                 2 * (monitor.x - root.width / 2
                                      - LabTheme.spaceL)))
    }

    // --- keys ----------------------------------------------------------------
    // The reserved half of the map (presets, flow, view, record, help) is
    // LabKeys'. What is declared here is what this lab ADDS - and declaring it
    // here is also what documents it in LabHelp and in the ? list. Never
    // reassign 1-9, T, F, 0, Shift+R, W/A/S/D, the arrows, Space, H, P, Tab,
    // Esc or Ctrl +/-/0.
    LabKeys {
        id: keymap
        lab: root
        camera: rig
        pointer: nav
        flow: introFlow
        recorder: recorder
        keys: [
            { key: "Del", label: "key.delete",
              action: () => { if (root.selectedId !== -1)
                                  root.removeSegment(root.selectedId) } },
            { key: "C", label: "key.clear", action: () => root.clearAll() },
            { key: "E", label: "key.eraser",
              action: () => root.eraser = !root.eraser },
            { key: "#", label: "key.snap", action: () => grid.toggle() }
        ]
    }
    LabHelp {
        keymap: keymap
        anchors.centerIn: parent
        width: LabTheme.px(320)
    }

    Keys.onPressed: (ev) => {
        if (keymap.handle(ev)) return
        // Esc walks back one step, same as a right click.
        if (ev.key === Qt.Key_Escape) {
            if (root.eraser) root.eraser = false
            else root.selectedId = -1
        }
    }
    Keys.onReleased: (ev) => keymap.handleRelease(ev)
}
