// (c) Clayground Contributors - MIT License, see "LICENSE" file
//
// The professor's bench - one character, four things to point at, and a button
// per behaviour.
//
// Deliberately not inside a real lab. A professor built into electronics-101
// would grow hooks into circuits within a day, and checking an arm angle would
// mean rebuilding a board first. Isolated, the professor has to earn a stated
// contract - appear, vanish, point at a world point, say a line - and that
// contract is what makes it droppable into any lab afterwards.
//
// Keys: E arrive · X leave · G fly to the next thing and show it · O fly back ·
// J previous target · K next target · U thumbs up · L stop gesturing · N say a
// line · P perform a scripted scene · C hush · I next inspection view ·
// Y hair · B beard · M mood. Camera as
// everywhere else: right-drag turns, middle drags, wheel zooms, Space+left pans
// - but set up to come much closer than a lab camera, see the rig below.
import QtQuick
import QtQuick3D
import Clayground.Canvas3D
import Clayground.Character3D
import Clayground.Lab

Item {
    id: root
    anchors.fill: parent
    focus: true

    Component.onCompleted: {
        forceActiveFocus()
        prof.appear()
    }

    // --- what there is to point at ------------------------------------------
    // Chosen to break a naive aim rather than to look tidy: one low and close,
    // one high, one behind, one far out to the side.
    // `at` is the thing itself; `from` is where a person would stand to show
    // it to you - beside it, not on top of it, and always on the ground. The
    // kit knows how to fly somewhere and how to point at something; only the
    // lab can know which spot in ITS scene is the good spot to say it from.
    readonly property var targets: [
        { name: "the bench",   at: Qt.vector3d(2.6, 0.15, 2.2),
                               from: Qt.vector3d(1.5, 0, 3.4) },
        { name: "the shelf",   at: Qt.vector3d(-4.5, 4.2, 1.0),
                               from: Qt.vector3d(-3.4, 0, 1.9) },
        { name: "the far peg", at: Qt.vector3d(7.5, 0.4, -3.0),
                               from: Qt.vector3d(6.2, 0, -1.9) },
        { name: "behind me",   at: Qt.vector3d(-1.0, 1.6, -6.0),
                               from: Qt.vector3d(-0.2, 0, -4.7) }
    ]

    // Home, so there is always somewhere to come back to.
    readonly property vector3d lectern: Qt.vector3d(0, 0, 0)
    property int picked: -1        // -1 = pointing at nothing

    function pointTo(i) {
        cheering = false
        perf.stop()
        endLesson()
        picked = ((i % targets.length) + targets.length) % targets.length
        prof.pointAt(targets[picked].at)
    }
    function release() { picked = -1; prof.stopGesture() }

    // The thumb is a toggle here rather than a button that fires and forgets:
    // it is a held pose, and the thing you want to look at is how it holds.
    property bool cheering: false
    function toggleThumb() {
        perf.stop()
        cheering = !cheering
        if (cheering) { picked = -1; prof.thumbsUp() }
        else prof.stopGesture()
    }

    // --- a pretend lesson ----------------------------------------------------
    // Four steps that go nowhere, for one reason: this is the shape a real
    // lab's flow has, and driving FlowGuide with it here is what proves the
    // component before a lab depends on it. The bench is where a professor
    // is allowed to be wrong.
    //
    // Note what the bench does NOT do: it does not fly the professor, point
    // it, or fill its bubble. It sets a step number. Everything else is
    // FlowGuide's, which is the whole point.

    property bool lesson: false
    property int lessonStep: -1

    function nextLesson() {
        cheering = false
        perf.stop()
        if (!lesson) { lesson = true; lessonStep = 0 }
        else lessonStep = (lessonStep + 1) % targets.length
    }

    function endLesson() {
        lesson = false
        lessonStep = -1
    }

    function goHome() {
        perf.stop()
        endLesson()
        cheering = false
        picked = -1
        prof.travelTo(root.lectern)
    }

    // A line long enough to see the bubble wrap and the mouth run, short
    // enough to read at a glance.
    function talk() {
        perf.stop()
        prof.say(picked < 0 ? "Ask me about something on the bench."
                            : "This is " + targets[picked].name
                              + " - watch what happens when I turn it on.")
    }

    // --- a scripted performance ----------------------------------------------
    // The same professor, directed from one string instead of from a handler
    // per beat. The names in the directives are the pegs' objectNames, found
    // by the Performance's own scene walk - nothing here translates them.
    // Every kind of cue the format has appears once, so this one key is the
    // whole vocabulary demo: point with a time hint, face the viewer, emotion,
    // a pause, a plain estimated line, and a held thumbs up to close.
    readonly property string scene1:
        "*point at the shelf* Up on the shelf is where finished experiments"
        + " retire. (3s)"
        + " *face viewer* *happy* *gesticulate* But nothing up there ever"
        + " surprised anyone."
        + " *pause 600ms*"
        + " *point at the bench* This is the bench I meant! (2600ms)"
        + " *face viewer* *neutral* What happens on it is far less predictable."
        + " *thumbs up* *happy* Stay curious - you will like it here. (2600ms)"

    function playScript() {
        if (perf.running) { perf.stop(); prof.quiet(); return }
        endLesson()
        cheering = false
        picked = -1
        if (!prof.present) prof.appear()
        perf.play(root.scene1)
    }

    // --- where to stand ------------------------------------------------------
    // Read off the professor rather than typed in: a taller one, or one with a
    // bigger head, must not leave the camera looking at its chest.
    readonly property real eyeY: prof.faceY

    // Where to look when the whole figure is the subject. Also the rig's home,
    // because the height floor is measured from THERE: with home at eye level
    // every close view would be pushed back out to keep the camera above the
    // ground it is nowhere near.
    readonly property real midY: prof.standHeight * 0.55

    // The inspection tour, in the order you would actually walk it: the face
    // first, then round it, then the two angles that show what the front view
    // hides - the crown, where the hair is built, and up under the chin, where
    // the beard is.
    readonly property var views: ["face", "profile", "back", "crown", "chin", "figure"]
    property int viewAt: 5

    function nextView() {
        viewAt = (viewAt + 1) % views.length
        rig.goTo(views[viewAt])
    }
    function showView(name) {
        const i = views.indexOf(name)
        if (i >= 0) viewAt = i
        rig.goTo(name)
    }

    // --- the look, as things you cycle through --------------------------------
    // Hair, beard and mood are choices from a list, not points on a slider, so
    // they get buttons rather than Parameters - a slider whose only meaningful
    // positions are 0, 1, 2 and 3 is a menu that lies about being continuous.

    readonly property var hairStyles: ["wild", "swept", "tidy", "ring", "none"]
    readonly property var beardStyles: ["walrus", "full", "goatee", "chin", "none"]
    readonly property var moods: ["happy", "neutral", "sad", "cross"]

    property int hairAt: 0
    property int beardAt: 0
    property int moodAt: 0

    function cycleHair() { hairAt = (hairAt + 1) % hairStyles.length }
    function cycleBeard() { beardAt = (beardAt + 1) % beardStyles.length }
    function cycleMood() { moodAt = (moodAt + 1) % moods.length }

    // --- the look, as knobs you can turn -------------------------------------
    // Parameters rather than hard-coded numbers, because getting a cartoon old
    // man right is a matter of taste and taste is faster found by dragging than
    // by editing. ParamPanel renders these for free, in the same style as every
    // other lab's sliders.
    //
    // `maturity` is the character plugin's own name for the knob that decides
    // how many head-heights fit in a body: turn it DOWN for a bigger head and
    // shorter legs, which with grey hair reads as old rather than young.
    Parameter { name: "height";    from: 1.4; to: 5.0; value: 1.48 }
    Parameter { name: "head";      from: 1.0; to: 2.0; value: 1.69 }
    Parameter { name: "maturity";  from: 0.0; to: 1.0; value: 0.64 }
    Parameter { name: "mass";      from: 0.0; to: 1.0; value: 0.32 }
    Parameter { name: "hair";      from: 0.0; to: 1.6; value: 1.0 }
    Parameter { name: "nose";      from: 0.4; to: 2.2; value: 1.73 }
    Parameter { name: "beard";     from: 0.0; to: 1.0; value: 0.62 }
    Parameter { name: "glasses";   from: 0.0; to: 1.0; value: 1.0; stepSize: 1 }

    View3D {
        id: view3d
        anchors.fill: parent
        camera: rig.camera

        // The same ground every other lab stands on, so the professor is being
        // judged against the surface it will actually appear on.
        LabStage3D {
            id: stage
            cellSize: 1
            majorEvery: 5
            gridMode: grid
            workExtent: Qt.vector2d(24, 24)
            // Pushed well past the defaults that workExtent would give: the
            // camera sits low here to look a standing figure in the eye, and a
            // near horizon at eye level fills half the frame with sky.
            horizonNear: 120
            horizonFar: 420
        }
        environment: stage.environment

        // The bench is for looking CLOSE - a beard is judged at the width of a
        // face, not at the width of a room - so the rig is set up for that and
        // not for surveying a board:
        //
        // - minDistance is a hand's width rather than four units, and the near
        //   plane follows it down. The default near plane is 10; even at 0.4
        //   the nose starts vanishing before the camera is close enough to see
        //   how the moustache is built.
        // - the pitch range reaches under the chin and over the crown, which
        //   is exactly where hair and beard geometry hides.
        // - the pivot sits at eye height, so orbiting close in circles the
        //   FACE. Pivoting at the feet and zooming in swings the head out of
        //   frame at the first drag, which is what made close inspection feel
        //   impossible before.
        OrbitCamera3D {
            id: rig
            pivot: Qt.vector3d(0, root.midY, 0)
            homePivot: Qt.vector3d(0, root.midY, 0)
            yaw: 18; pitch: 10; distance: 8
            minPitch: -35; maxPitch: 88
            minDistance: 0.8; maxDistance: 60
            minHeight: 0.25
            panLeash: stage.workRadius
            smoothMs: 140
            fieldOfView: 45
            viewpoints: ({
                "face":    { yaw: 0,   pitch: 2,  distance: 2.4,
                             px: 0, py: root.eyeY, pz: 0 },
                "profile": { yaw: 90,  pitch: 2,  distance: 2.6,
                             px: 0, py: root.eyeY, pz: 0 },
                "back":    { yaw: 180, pitch: 6,  distance: 2.6,
                             px: 0, py: root.eyeY, pz: 0 },
                "crown":   { yaw: 20,  pitch: 62, distance: 2.6,
                             px: 0, py: root.eyeY, pz: 0 },
                "chin":    { yaw: 0,   pitch: -28, distance: 2.4,
                             px: 0, py: root.eyeY, pz: 0 },
                "figure":  { yaw: 18,  pitch: 10, distance: 8,
                             px: 0, py: root.midY, pz: 0 }
            })
            Component.onCompleted: rig.camera.clipNear = 0.05
        }
        CameraAnchorMark { pointer: nav }

        Professor {
            id: prof
            view: view3d
            height3d: Lab.p("height")
            headScale: Lab.p("head")
            maturity: Lab.p("maturity")
            mass: Lab.p("mass")
            hairVolume: Lab.p("hair")
            noseSize: Lab.p("nose")
            beardLength: Lab.p("beard")
            spectacles: Lab.p("glasses") > 0.5
            hairStyle: root.hairStyles[root.hairAt]
            beardStyle: root.beardStyles[root.beardAt]
            mood: root.moods[root.moodAt]
        }

        // The lesson, handed over. `subjectOf` is the lab's half - the only
        // thing here that knows a peg from a shelf.
        FlowGuide {
            id: guide
            professor: prof
            running: root.lesson
            step: root.lessonStep
            text: root.lessonStep < 0 ? ""
                : "Let me go to " + root.targets[root.lessonStep].name
                  + " - look, this is the one I meant."
            subjectOf: (i) => ({ stand: root.targets[i].from,
                                 look: root.targets[i].at })
            // Two of the four steps are DIRECTED - they carry a script and
            // the built-in speak/point/address beat stands aside. The other
            // two keep the text choreography, which is the point: a flow
            // scripts only the steps that earn it.
            scriptTargets: view3d.scene
            scriptOf: (i) => i === 0
                ? "*point at the bench* The lesson starts here, at the"
                  + " bench. (2500ms)"
                  + " *face viewer* *gesticulate* Everything in this room ends"
                  + " up on it eventually."
                : i === 2
                ? "*point at the far peg* And out there sits the far"
                  + " peg. (2500ms)"
                  + " *face viewer* *happy* *gesticulate* Nobody remembers why"
                  + " - which is the best reason to go and look."
                : ""
        }

        // The targets, as plain pegs. Lit ones are what is being pointed at.
        // Each carries its name as objectName, which is what lets a script
        // say `*point at the shelf*` and have the Performance find it.
        Repeater3D {
            model: root.targets
            Model {
                id: peg
                required property int index
                required property var modelData
                objectName: peg.modelData.name
                source: "#Sphere"
                position: peg.modelData.at
                scale: Qt.vector3d(0.004, 0.004, 0.004)
                castsShadows: false
                materials: PrincipledMaterial {
                    baseColor: root.picked === peg.index ? LabTheme.alarm
                                                         : LabTheme.highlight
                    lighting: PrincipledMaterial.NoLighting
                }
            }
        }

        // A post under the two targets that float, so they read as things in
        // the room rather than as dots hanging in the air.
        Repeater3D {
            model: root.targets
            Model {
                id: post
                required property var modelData
                source: "#Cylinder"
                visible: post.modelData.at.y > 1
                position: Qt.vector3d(post.modelData.at.x,
                                      post.modelData.at.y / 2,
                                      post.modelData.at.z)
                scale: Qt.vector3d(0.0004, post.modelData.at.y / 100, 0.0004)
                materials: PrincipledMaterial {
                    baseColor: LabTheme.step(LabTheme.sheet, 1.3)
                }
            }
        }
    }

    OrbitInput3D { id: nav; rig: rig; view: view3d }
    GridMode { id: grid }

    // The director. Silent on purpose: a bare line goes through tell() - the
    // bubble and the mouth - exactly as FlowGuide narrates, not through the
    // speech engine (that stays on its own key, N).
    Performance {
        id: perf
        performer: prof
        searchRoot: view3d.scene
        viewerPosition: () => rig.camera.scenePosition
        spoken: false
        debug: true
    }

    // --- the bench controls -------------------------------------------------
    // Buttons as well as keys. A bench is for poking at, and a key you have to
    // remember is slower than a thing you can see.
    LabPanel {
        id: controls
        objectName: "controls"
        x: LabTheme.px(12); y: LabTheme.px(12)
        width: LabTheme.px(210)
        title: "PROFESSOR BENCH"
        tag: "?"

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
            label: prof.present ? "leave    (X)" : "arrive   (E)"
            active: prof.present
            onHit: prof.present ? prof.vanish() : prof.appear()
        }
        Item { width: 1; height: LabTheme.spaceM }
        Repeater {
            model: root.targets
            BenchButton {
                required property int index
                required property var modelData
                label: "point at " + modelData.name
                active: root.picked === index
                onHit: root.pointTo(index)
            }
        }
        Item { width: 1; height: LabTheme.spaceM }
        BenchButton {
            label: root.lesson ? "next step   (G)" : "run a lesson (G)"
            active: root.lesson
            onHit: root.nextLesson()
        }
        BenchButton {
            label: "end the lesson (O)"
            onHit: root.endLesson()
        }
        BenchButton {
            label: "fly back to the middle"
            onHit: root.goHome()
        }
        Item { width: 1; height: LabTheme.spaceM }
        BenchButton {
            label: "thumbs up (U)"
            active: root.cheering
            onHit: root.toggleThumb()
        }
        BenchButton {
            label: "stop gesturing (L)"
            onHit: root.release()
        }
        BenchButton {
            label: prof.character.speaking ? "hush     (C)" : "say a line (N)"
            active: prof.character.speaking
            onHit: prof.character.speaking ? prof.hush() : root.talk()
        }
        BenchButton {
            label: perf.running ? "stop the scene (P)" : "perform a scene (P)"
            active: perf.running
            onHit: root.playScript()
        }
        Item { width: 1; height: LabTheme.spaceM }
        BenchButton {
            label: "view:  " + root.views[root.viewAt] + " (I)"
            onHit: root.nextView()
        }
        Item { width: 1; height: LabTheme.spaceM }
        BenchButton {
            label: "hair:  " + prof.hairStyle + " (Y)"
            onHit: root.cycleHair()
        }
        BenchButton {
            label: "beard: " + prof.beardStyle + " (B)"
            onHit: root.cycleBeard()
        }
        BenchButton {
            label: "mood:  " + prof.mood + " (M)"
            onHit: root.cycleMood()
        }
    }

    // What the professor is actually doing, in numbers. A bench that only
    // shows the puppet cannot tell you why the puppet is wrong.
    LabPanel {
        objectName: "state"
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: LabTheme.px(12)
        width: LabTheme.px(180)
        title: "STATE"
        Text {
            text: "present  " + prof.present
                + "\ngesture  " + (prof.gesture === "" ? "-" : prof.gesture)
                + "\npointing " + (root.picked < 0 ? "-" : root.targets[root.picked].name)
                + "\nflying   " + prof.travelling
                + "\nat       " + prof.stand.x.toFixed(1) + ", " + prof.stand.z.toFixed(1)
                + "\nsettled  " + prof.settled
                + "\nspeaking " + prof.character.speaking
                + "\nscript   " + (perf.running
                                   ? (perf.cueIndex + 1) + "/" + perf.cueCount
                                   : guide.script.running
                                   ? "step " + (guide.script.cueIndex + 1)
                                     + "/" + guide.script.cueCount
                                   : (perf.done || guide.script.done) ? "done" : "-")
            color: LabTheme.inkSoft
            font.pixelSize: LabTheme.fontSmall
            font.family: LabTheme.monoFont
        }
    }

    // The look knobs, bottom left, out of the way of the buttons.
    ParamPanel {
        anchors.left: parent.left
        anchors.bottom: parent.bottom
        anchors.margins: LabTheme.px(12)
        width: LabTheme.px(210)
    }

    // --- keeping your place across a reload ----------------------------------
    // The loader captures this from the outgoing root before every reload -
    // mine and yours alike - and applies it to the new one. Without it, every
    // edit to any file in this directory threw away whatever look had just
    // been dialled in on the sliders, which is how a set of settings worth
    // keeping nearly got lost.
    //
    // The look, the camera and the pose, because those are what you are in the
    // middle of. Not what the professor is saying: a sentence that survived a
    // reload would be a sentence nobody asked for.

    function viewState() {
        return {
            // labInfo() already carries every registered parameter as a
            // name-to-value map, so adding a slider does not mean coming
            // back here to list it.
            params: Lab.labInfo().params,
            hairAt: root.hairAt, beardAt: root.beardAt, moodAt: root.moodAt,
            viewAt: root.viewAt, picked: root.picked, cheering: root.cheering,
            lesson: root.lesson, lessonStep: root.lessonStep,
            // Where it is standing, so an edit does not teleport it home.
            sx: prof.stand.x, sy: prof.stand.y, sz: prof.stand.z,
            heading: prof.heading,
            cam: rig.state()
        }
    }

    function applyViewState(s) {
        if (!s) return
        if (s.params)
            for (const k in s.params) Lab.set(k, s.params[k])
        if (s.hairAt !== undefined) root.hairAt = s.hairAt
        if (s.beardAt !== undefined) root.beardAt = s.beardAt
        if (s.moodAt !== undefined) root.moodAt = s.moodAt
        if (s.viewAt !== undefined) root.viewAt = s.viewAt
        if (s.cam) rig.applyState(s.cam)
        if (s.sx !== undefined) prof.stand = Qt.vector3d(s.sx, s.sy, s.sz)
        if (s.heading !== undefined) prof.heading = s.heading
        if (s.lessonStep !== undefined) root.lessonStep = s.lessonStep
        if (s.lesson !== undefined) root.lesson = s.lesson
        // The pose last, and re-issued rather than restored: it is an
        // animation, and the arm has to be driven into it again.
        if (s.cheering) { root.cheering = true; prof.thumbsUp() }
        else if (s.picked !== undefined && s.picked >= 0) root.pointTo(s.picked)
    }

    LabKeys {
        id: keymap
        lab: root
        camera: rig
        pointer: nav
        keys: [
            { key: "E", label: "the professor arrives", action: () => prof.appear() },
            { key: "X", label: "the professor leaves", action: () => prof.vanish() },
            { key: "K", label: "point at the next thing",
              action: () => root.pointTo(root.picked + 1) },
            { key: "J", label: "point at the previous thing",
              action: () => root.pointTo(root.picked - 1) },
            { key: "G", label: "run a lesson / next step",
              action: () => root.nextLesson() },
            { key: "O", label: "end the lesson", action: () => root.endLesson() },
            { key: "U", label: "thumbs up", action: () => root.toggleThumb() },
            { key: "L", label: "stop gesturing", action: () => root.release() },
            { key: "N", label: "say a line", action: () => root.talk() },
            { key: "P", label: "perform a scripted scene / stop it",
              action: () => root.playScript() },
            { key: "T", label: "talk to the viewer",
              action: () => { prof.faceViewer(); prof.gesticulate() } },
            { key: "C", label: "hush", action: () => prof.hush() },
            { key: "I", label: "next inspection view", action: () => root.nextView() },
            { key: "Y", label: "next hair style", action: () => root.cycleHair() },
            { key: "B", label: "next beard style", action: () => root.cycleBeard() },
            { key: "M", label: "next mood", action: () => root.cycleMood() }
        ]
    }
    LabHelp { keymap: keymap; anchors.centerIn: parent; width: LabTheme.px(300) }

    Keys.onPressed: (ev) => keymap.handle(ev)
    Keys.onReleased: (ev) => keymap.handleRelease(ev)
}
