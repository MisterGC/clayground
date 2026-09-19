// (c) Clayground Contributors - MIT License, see "LICENSE" file
//
// The dive-in's bench - one transistor case, the die inside it, and a key that
// takes you in.
//
// Deliberately without the exploded anatomy (approach 1 owns that): the case
// here is a stand-in, three legs and a black blob at the circuit kit's own
// dimensions, and it is also the thing that gets ghosted. What is being judged
// on this bench is the DIVE - does the camera get inside a 1.6-unit part
// without losing it to the near plane, does the shrunken professor read as
// standing on the die, do the carriers read as two currents - and every one of
// those questions is asked of `report()` first and of the picture second.
//
// Keys: I dive in · O come back out · B cycle the base current · C cycle the
// collector current · R a whole round trip. Camera as everywhere else.
import QtQuick
import QtQuick3D
import Clayground.Canvas3D
import Clayground.Lab
import ".."
import "../../professor"
import "../anatomy.js" as Anatomy

// The buttons are an inline component reading the panel and the root by id.
pragma ComponentBehavior: Bound

Item {
    id: root
    anchors.fill: parent
    focus: true

    Component.onCompleted: {
        forceActiveFocus()
        prof.appear()
    }

    // --- the two currents ----------------------------------------------------
    // Normalised, because that is all the interior wants: a transistor in the
    // active region has a small base current and a large collector one, and
    // the cycles below are the three cases worth looking at - off, working,
    // saturated.

    property real iB: 0.3
    property real iC: 0.8

    readonly property var iBSteps: [0, 0.3, 1]
    readonly property var iCSteps: [0, 0.8, 1]

    function cycleIB() {
        const i = root.iBSteps.indexOf(root.iB)
        root.iB = root.iBSteps[(i + 1) % root.iBSteps.length]
    }
    function cycleIC() {
        const i = root.iCSteps.indexOf(root.iC)
        root.iC = root.iCSteps[(i + 1) % root.iCSteps.length]
    }

    // --- a whole round trip, as one call -------------------------------------
    // A check cannot press two keys a few seconds apart: `--eval` runs before
    // the first frame and `--wait-for` asks one question. So the two-step
    // "go in, come back, is everything where it was" lives here as a state
    // machine and the check waits for `phase === "back"`.

    property string phase: "out"

    function roundTrip() {
        root.phase = "diving"
        dive.enter()
    }

    function _settle() {
        if (root.phase === "diving" && dive.depth > 0.999) {
            root.phase = "in"
            dive.leave()
            return
        }
        if (root.phase === "in" && dive.depth < 0.001 && !dive.travelling)
            root.phase = "back"
    }

    // Both signals, because either can be the last one to arrive: the depth
    // animation and the professor's flight do not end on the same frame.
    Connections {
        target: dive
        function onDepthChanged() { root._settle() }
        function onTravellingChanged() { root._settle() }
    }

    /*! Everything a check needs to know, in numbers. */
    function report() {
        return { inside: dive.inside, depth: dive.depth, phase: root.phase,
                 rigDistance: rig.distance, clipNear: rig.camera.clipNear,
                 profHeight: prof.height3d,
                 profStand: [prof.stand.x, prof.stand.y, prof.stand.z],
                 carriers: interior.carrierCount, iB: root.iB, iC: root.iC }
    }

    SimClock { id: clock; fixedStep: 1 / 60 }

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

        OrbitCamera3D {
            id: rig
            view: view3d
            pivot: Qt.vector3d(0, 1.5, 0)
            homePivot: Qt.vector3d(0, 1.5, 0)
            yaw: 20; pitch: 28; distance: 26
            minDistance: 4; maxDistance: 120
            minHeight: 1
            // The default near plane is 10 units and nothing in the rig sets
            // it: at this scale the whole part would be in front of the lens.
            // The dive relaxes it further still.
            Component.onCompleted: rig.camera.clipNear = 0.5
        }
        CameraAnchorMark { pointer: nav }

        // --- the case, as a stand-in --------------------------------------
        // The circuit kit's own TO-92: a black epoxy blob a little behind the
        // part's centre and three legs out to the board pads. This node is
        // what `ghosts` fades, which is the whole reason it is one node.
        Node {
            id: shell

            Model {                            // the epoxy body
                source: "#Cylinder"
                position: Qt.vector3d(0, 1.55, -0.35)
                scale: Qt.vector3d(0.042, 0.031, 0.042)
                materials: PrincipledMaterial {
                    // The circuit kit's physical part colour, not a theme
                    // token: epoxy is black in every theme.
                    baseColor: "#2a2724"
                    roughness: 1; metalness: 0; specularAmount: 0
                }
            }

            Repeater3D {                       // three legs, flat on the board
                model: [Anatomy.PADS.collector, Anatomy.PADS.base, Anatomy.PADS.emitter]
                Model {
                    id: leg
                    required property var modelData
                    source: "#Cylinder"
                    // From the pad half-way in to the centre, lying down: a
                    // #Cylinder stands along its own Y, so the one that runs
                    // along x is turned about z and the one along z about x.
                    position: Qt.vector3d(leg.modelData.x * 0.75, 0.55,
                                          leg.modelData.z * 0.75)
                    eulerRotation: Math.abs(leg.modelData.x) > 0.001
                                 ? Qt.vector3d(0, 0, 90) : Qt.vector3d(90, 0, 0)
                    scale: Qt.vector3d(0.0026, 0.0175, 0.0026)
                    materials: PrincipledMaterial {
                        baseColor: LabTheme.muted
                        roughness: 1; metalness: 0; specularAmount: 0
                    }
                }
            }
        }

        // --- the die ------------------------------------------------------
        // Standing on where the header's top face would be. Invisible until
        // the dive starts revealing it, so the outside view is a black part
        // with nothing suspiciously glowing through it.
        TransistorInterior3D {
            id: interior
            position: Qt.vector3d(0, 0.95, 0)
            time: clock.time
            baseCurrent: root.iB
            collectorCurrent: root.iC
            // The starting state, and a statement of who drives it. DiveIn
            // WRITES reveal every frame of a dive, which replaces this
            // binding with the same number - keeping the line is what makes
            // the wiring visible in the bench rather than only in DiveIn.
            reveal: dive.depth
        }

        Professor {
            id: prof
            view: view3d
            height3d: 6.2
            travelSpeed: 34
            stand: Qt.vector3d(9, 0, 6)
        }
    }

    OrbitInput3D { id: nav; rig: rig; view: view3d }
    GridMode { id: grid }

    DiveIn {
        id: dive
        rig: rig
        presenter: prof
        view: view3d
        target: interior
        interior: interior
        ghosts: [shell]
    }

    // --- the controls --------------------------------------------------------

    LabPanel {
        id: controls
        objectName: "controls"
        x: LabTheme.px(12); y: LabTheme.px(12)
        width: LabTheme.px(210)
        title: "DIVE BENCH"
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
            label: "dive in       (I)"
            active: dive.inside
            onHit: dive.enter()
        }
        BenchButton {
            label: "come back out (O)"
            onHit: dive.leave()
        }
        BenchButton {
            label: "round trip    (R)"
            onHit: root.roundTrip()
        }
        Item { width: 1; height: LabTheme.spaceM }
        BenchButton {
            label: "base   Ib = " + root.iB.toFixed(1) + " (B)"
            onHit: root.cycleIB()
        }
        BenchButton {
            label: "coll.  Ic = " + root.iC.toFixed(1) + " (C)"
            onHit: root.cycleIC()
        }
    }

    // What the dive is actually doing. A bench that only shows the picture
    // cannot tell you why the picture is wrong.
    LabPanel {
        objectName: "state"
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: LabTheme.px(12)
        width: LabTheme.px(190)
        title: "STATE"
        Text {
            text: "inside    " + dive.inside
                + "\ndepth     " + dive.depth.toFixed(3)
                + "\nphase     " + root.phase
                + "\ndistance  " + rig.distance.toFixed(2)
                + "\nclipNear  " + rig.camera.clipNear.toFixed(3)
                + "\nprof h    " + prof.height3d.toFixed(3)
                + "\nprof at   " + prof.stand.x.toFixed(2) + ", "
                                 + prof.stand.y.toFixed(2) + ", "
                                 + prof.stand.z.toFixed(2)
                + "\nflying    " + prof.travelling
                + "\ncarriers  " + interior.carrierCount
                + "\nt         " + clock.time.toFixed(2)
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
            { key: "I", label: "dive into the part", action: () => dive.enter() },
            { key: "O", label: "come back out", action: () => dive.leave() },
            { key: "R", label: "a whole round trip", action: () => root.roundTrip() },
            { key: "B", label: "cycle the base current", action: () => root.cycleIB() },
            { key: "C", label: "cycle the collector current", action: () => root.cycleIC() }
        ]
    }
    LabHelp { keymap: keymap; anchors.centerIn: parent; width: LabTheme.px(300) }

    Keys.onPressed: (ev) => keymap.handle(ev)
    Keys.onReleased: (ev) => keymap.handleRelease(ev)
}
