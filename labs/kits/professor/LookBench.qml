// (c) Clayground Contributors - MIT License, see "LICENSE" file
//
// LookBench - a throwaway rig for looking at Beard and Spectacles. One
// character on the standard lab ground, a fixed camera with named viewpoints,
// and setters for every property the two components expose.
//
//   clayrender labs/kits/professor/LookBench.qml --size 900x700 \
//       --eval 'look("threequarter")' --settle --out /tmp/a.png
//
// The head dimensions can be scaled at runtime (headScale) to prove nothing
// in either component is a fixed world number; detach() proves both cope with
// no character at all.

import QtQuick
import QtQuick3D
import Clayground.Character3D
import Clayground.Lab

pragma ComponentBehavior: Bound

Item {
    id: root
    anchors.fill: parent

    // Camera, as a yaw/pitch/distance orbit around the face.
    property real camYaw: 0
    property real camPitch: 4
    property real camDist: 1.5

    /*! Move the fixed camera to a named viewpoint. */
    function look(preset) {
        if (preset === "front") { root.camYaw = 0; root.camPitch = 4; root.camDist = 1.5 }
        else if (preset === "threequarter") { root.camYaw = 38; root.camPitch = 8; root.camDist = 1.5 }
        else if (preset === "side") { root.camYaw = 90; root.camPitch = 4; root.camDist = 1.5 }
        else if (preset === "back") { root.camYaw = 165; root.camPitch = 6; root.camDist = 1.6 }
        else if (preset === "below") { root.camYaw = 20; root.camPitch = -28; root.camDist = 1.5 }
        else if (preset === "above") { root.camYaw = 20; root.camPitch = 42; root.camDist = 1.6 }
        else if (preset === "body") { root.camYaw = 25; root.camPitch = 10; root.camDist = 6 }
    }

    /*! Turn and tilt the head, in degrees - the ride-along test. */
    function turnHead(yaw, pitch) {
        root._headEuler = Qt.vector3d(pitch === undefined ? 0 : pitch, yaw, 0)
        root._headHeld = true
    }

    property vector3d _headEuler: Qt.vector3d(0, 0, 0)
    property bool _headHeld: false

    Timer {
        // The character's idle animation writes head.eulerRotation itself and
        // wins over both a binding and a one-off assignment, so a held turn
        // has to be re-asserted rather than set once. Re-writing the same
        // value changes no pixels, so --settle still terminates.
        interval: 40
        repeat: true
        running: root._headHeld
        onTriggered: prof.head.eulerRotation = root._headEuler
    }

    /*!
        Multiply every head dimension by \a f. Deliberately assigns over
        ParametricCharacter's bindings: this is a bench, each render is a
        fresh process, and nothing needs to be put back.
    */
    function headScale(f) {
        prof.upperHeadWidth = root._base.uw * f
        prof.upperHeadHeight = root._base.uh * f
        prof.upperHeadDepth = root._base.ud * f
        prof.lowerHeadWidth = root._base.lw * f
        prof.lowerHeadHeight = root._base.lh * f
        prof.lowerHeadDepth = root._base.ld * f
    }

    /*! Beard settings, in one call. */
    function setBeard(length, fullness, moustache) {
        beard.length = length
        beard.fullness = fullness
        beard.moustache = moustache
    }

    /*! Spectacle settings, in one call. */
    function setSpecs(size, slip) {
        specs.size = size
        specs.slip = slip
    }

    /*! Shrink the whole character - both pieces have to shrink with it. */
    function setScale(s) { prof.scale = Qt.vector3d(s, s, s) }

    /*! Hair volume, which decides how much of the face there is to work with. */
    function setHair(v) { prof.hairVolume = v }

    /*! Open the mouth by hand, without running a speech engine. */
    function talk(on) { prof.faceActivity = on ? Head.Activity.Talk : Head.Activity.Idle }

    /*! Take the character away from both pieces. Nothing may be drawn, or logged. */
    function detach() {
        beard.character = null
        specs.character = null
    }

    /*! One line of what the bench is currently showing. */
    function report() {
        return "yaw=" + root.camYaw.toFixed(0)
             + " beard(len=" + beard.length.toFixed(2)
             + ",full=" + beard.fullness.toFixed(2)
             + ",tache=" + beard.moustache + ")"
             + " specs(size=" + specs.size.toFixed(2)
             + ",slip=" + specs.slip.toFixed(2) + ")"
             + " attached=" + (beard.character !== null)
    }

    // Head dimensions as ParametricCharacter derived them, captured before
    // headScale() overwrites the bindings.
    property var _base: ({})

    Component.onCompleted: {
        root._base = { uw: prof.upperHeadWidth, uh: prof.upperHeadHeight, ud: prof.upperHeadDepth,
                       lw: prof.lowerHeadWidth, lh: prof.lowerHeadHeight, ld: prof.lowerHeadDepth }
    }

    // Where the camera looks: the middle of the face, wherever the head
    // dimensions and the character scale have put it.
    readonly property real faceY: (prof.height - prof.headHeight
                                   + prof.lowerHeadHeight
                                   + prof.upperHeadHeight * 0.45) * prof.scale.y

    View3D {
        id: view3d
        anchors.fill: parent

        LabStage3D {
            id: stage
            cellSize: 0.5
            majorEvery: 4
            workExtent: Qt.vector2d(8, 8)
            shadowMapFar: 40
            horizonNear: 30
            horizonFar: 120
        }
        environment: stage.environment

        Node {
            position: Qt.vector3d(0, root.faceY, 0)
            eulerRotation: Qt.vector3d(-root.camPitch, root.camYaw, 0)

            PerspectiveCamera {
                // The default near plane is 10 units out, which is three times
                // taller than this character - without this the frame is sky.
                clipNear: 0.03
                clipFar: 200
                z: root.camDist
            }
        }

        ParametricCharacter {
            id: prof
            name: "professor"
            bodyHeight: 3.2
            maturity: 1.0
            // A full head of hair on this character is a slab deep enough to
            // hide the temples, the ears and anything routed past them - which
            // is most of what these two components have to be judged on.
            hair: 0.55
            skinColor: LabTheme.clay
            hairColor: LabTheme.inkFaint
            torsoColor: LabTheme.teal
            hipColor: LabTheme.plum
            legColor: LabTheme.plum
            armColor: LabTheme.teal
            activity: Character.Activity.Idle

            Beard {
                id: beard
                character: prof
            }

            Spectacles {
                id: specs
                character: prof
                frameTone: LabTheme.inkSolid
                // Paper, at a quarter alpha: a lens has to tint the eye behind
                // it without hiding it, and the alpha is the whole point.
                lensTone: Qt.rgba(LabTheme.paper.r, LabTheme.paper.g,
                                  LabTheme.paper.b, 0.25)
            }
        }
    }

    Text {
        anchors.left: parent.left
        anchors.bottom: parent.bottom
        anchors.margins: LabTheme.spaceM
        color: LabTheme.ink
        font.family: LabTheme.monoFont
        font.pixelSize: LabTheme.fontSmall
        text: root.report()
    }
}
