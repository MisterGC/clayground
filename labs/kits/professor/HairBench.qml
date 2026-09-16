// (c) Clayground Contributors - MIT License, see "LICENSE" file
//
// HairBench - the four cuts side by side, on the ground the labs actually use.
//
// Deliberately not a Professor: Professor.qml owns its own look and does not
// take a hair style, so the bench builds the smallest thing Hair needs - a
// ParametricCharacter with its built-in hair turned off, plus a pair of
// spectacles, which is the piece the hair is most likely to collide with.
//
//   clayrender --sbx labs/kits/professor/HairBench.qml -o /tmp/hair.png \
//       --size 1600x900 --settle --settle-timeout 900
//   ... --set 'yaw=90'     from the side
//   ... --set 'pitch=-22'  from below
//   ... --set 'volume=1.6' --set 'beards=true'
//
// Left to right: wild, swept, tidy, ring. "none" is not on the bench because
// what it draws is nothing, which is better checked by the gap it leaves.

import QtQuick
import QtQuick3D
import Clayground.Canvas3D
import Clayground.Character3D
import Clayground.Lab

pragma ComponentBehavior: Bound

Item {
    id: root
    anchors.fill: parent

    // Camera knobs, as plain properties so one render command can move the
    // camera without the bench growing an input handler.
    property real yaw: 0
    property real pitch: 6
    property real dist: root.bodyHeight * 1.08

    /*! Look at one bust alone, by index into styles. -1 shows all four. */
    property int only: -1

    /*! Passed straight through to every head of hair on the bench. */
    property real volume: 1.0

    /*! Whether the busts also wear a beard - the other thing hair has to share
        a head with. Off by default: it hides the jaw the sides run down to. */
    property bool beards: false

    /*! How tall the characters are. Small values check that nothing here is a
        world constant. */
    property real bodyHeight: 2.4

    /*! Which cut each bust wears, left to right. Overridable from a render
        command, which is how "none" gets looked at. */
    property var styles: ["wild", "swept", "tidy", "ring"]

    /*! Take the character away from every head of hair. Nothing may be drawn,
        and nothing may be logged. */
    function detach() {
        _bust0.hair.character = null
        _bust1.hair.character = null
        _bust2.hair.character = null
        _bust3.hair.character = null
    }

    // Where the faces are, so the camera can look at them rather than at a
    // number that happens to be right for one body height. Read off the first
    // bust; they are all built the same.
    readonly property real faceY: _bust0.faceY

    // Where a bust stands. In body heights rather than in a fixed gap, so the
    // row stays a row whatever size the characters are.
    function slotX(i) { return (i - (root.styles.length - 1) * 0.5) * root.bodyHeight * 0.46 }

    View3D {
        id: view3d
        anchors.fill: parent
        camera: rig.camera

        LabStage3D {
            id: stage
            cellSize: 0.5
            majorEvery: 4
            workExtent: Qt.vector2d(12, 12)
            shadowMapFar: 40
            horizonNear: 60
            horizonFar: 240
        }
        environment: stage.environment

        OrbitCamera3D {
            id: rig
            pivot: Qt.vector3d(root.only < 0 ? 0 : root.slotX(root.only), root.faceY, 0)
            homePivot: rig.pivot
            yaw: root.yaw
            pitch: root.pitch
            // Closer in for a single bust - but not much closer: at a
            // portrait distance the near side of the head looms and every
            // judgement about the silhouette is a judgement about perspective.
            distance: root.only < 0 ? root.dist : root.dist * 1.35
            minPitch: -60; maxPitch: 80
            minDistance: 1; maxDistance: 60
            minHeight: 0.2
            // No smoothing: a bench that eases into position is a bench whose
            // first frames are a different picture, and --settle pays for it.
            smoothMs: 0
            // The rig's near plane sits ten units out by default, which is four
            // characters deep - without this the whole bench is clipped away.
            Component.onCompleted: rig.camera.clipNear = 0.4
        }

        // One bust per style, written out rather than repeated: the camera
        // needs to ask one of them how high its face is, and a Repeater3D
        // delegate is not something the rest of the file can name.
        component Bust: Node {
            id: bust
            property string style: "wild"
            property int slot: 0

            readonly property real faceY: who.height - who.headHeight
                                          + who.lowerHeadHeight
                                          + who.upperHeadHeight * 0.5
            readonly property var hair: _hair

            x: root.slotX(bust.slot)

            ParametricCharacter {
                id: who
                name: "bust" + bust.slot
                bodyHeight: root.bodyHeight
                maturity: 0.15
                mass: 0.55
                muscle: 0.3
                femininity: 0.2
                nose: 1.3
                // What the professor actually runs. Larger eyes push _faceFloor
                // up into the forehead and every cut on the bench comes out
                // bald - which is a property of the head, not of the hair.
                eyes: 1.0
                chinForm: 0.35
                // The head's own hair off: it and Hair draw on the same skull
                // and would interleave into one grey lump.
                hair: 0.0
                skinColor: LabTheme.clay
                hairColor: LabTheme.muted
                torsoColor: LabTheme.forest
                armColor: LabTheme.forest
                hipColor: LabTheme.inkFaint
                legColor: LabTheme.inkFaint
                activity: Character.Activity.Idle

                Hair {
                    id: _hair
                    character: who
                    style: bust.style
                    volume: root.volume
                }

                Beard {
                    character: who
                    visible: root.beards
                    length: 0.62
                    fullness: 0.72
                }

                Spectacles {
                    character: who
                    frameTone: LabTheme.ink
                    lensTone: Qt.rgba(LabTheme.sheet.r, LabTheme.sheet.g,
                                      LabTheme.sheet.b, 0.22)
                    slip: 0.2
                }
            }
        }

        Bust { id: _bust0; slot: 0; style: root.styles[0] }
        Bust { id: _bust1; slot: 1; style: root.styles[1] }
        Bust { id: _bust2; slot: 2; style: root.styles[2] }
        Bust { id: _bust3; slot: 3; style: root.styles[3] }
    }

    // A legend rather than labels under each head: the camera moves, and a
    // label pinned to a screen position lies as soon as it does.
    Text {
        anchors.left: parent.left
        anchors.bottom: parent.bottom
        anchors.margins: LabTheme.spaceM
        color: LabTheme.ink
        font.family: LabTheme.monoFont
        font.pixelSize: LabTheme.fontSmall
        text: "left to right: " + root.styles.join("  ")
            + "   volume=" + root.volume.toFixed(2)
            + "   yaw=" + root.yaw.toFixed(0)
            + " pitch=" + root.pitch.toFixed(0)
    }
}
