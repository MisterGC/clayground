// (c) Clayground Contributors - MIT License, see "LICENSE" file
// @brief Two characters, one talking - and the other one either present or not
// @tags 3D, Character, Speech, Listening
// @category Plugin Benches
//
// The bench for the half of a conversation nobody was animating. One
// character says a line; the other either listens or does not, and L swaps
// between the two so the difference can be seen rather than remembered.
//
// What it is for:
//
//   * A listener is mostly its eyes. Whether holding a face, breaking away
//     and marking phrase endings actually reads as attention - rather than
//     as a character with a twitch - is not something the change can prove
//     about itself.
//   * The phrase boundaries come off the SPEAKER'S MOUTH, not its script, so
//     this has to look right on a line that was never written down. Press 2
//     for the recording nobody has a transcript of.
//   * Both characters are the same component with one property different.
//     Anything that looks wrong on the listener and right on the speaker is
//     this bench's fault, not the feature's.
//
//   ./build/bin/claydojo --sbx plugins/clay_character3d/bench/ConversationSandbox.qml
//
// Launch the dojo with QT_DISABLE_SHADER_DISK_CACHE=1.

import QtQuick
import QtQuick.Controls
import QtQuick3D
import Clayground.Character3D

Item {
    id: root
    anchors.fill: parent
    focus: true

    /*! Off pins the listener to what it was before any of this: a body that
        happens to be standing there while someone talks at it. */
    property bool listening: true

    /*! Who is talking. The other one listens. */
    property int speakerIndex: 0

    // Two people facing each other can only ever show ONE face to a camera -
    // which is why film shoots a conversation over a shoulder and cuts, and
    // why this is staged the same way rather than as two figures side by
    // side. The subject is the LISTENER, placed deep and near-frontal; the
    // speaker stands closer to the lens and off to one side, so the listener
    // has a real angle to cover with a head turn small enough to keep its
    // face pointed this way. S swaps the two positions with the roles.
    readonly property vector3d _farPos: Qt.vector3d(2.5, 0, -2)
    readonly property vector3d _nearPos: Qt.vector3d(-5.0, 0, 8)
    property string lastLine: "-"

    function speak(what) {
        const a = root.speakerIndex === 0 ? _a : _b
        root.lastLine = what
        a.say(what)
    }

    function swap() {
        root.speakerIndex = root.speakerIndex === 0 ? 1 : 0
    }

    // Halfway between the other one and the camera, not straight at the other
    // one. Two characters squared up to each other are two profiles from
    // every seat in the house - which is why a film puts them at an angle and
    // why this bench, whose whole subject is a face, has to as well. It also
    // leaves a real angle for the eyes to cover, which a full turn does not.
    // The listener's BODY stays pointed at the lens and only its head turns,
    // which is what keeps its face readable; the speaker squares up to the
    // listener and gives the camera a profile, which is enough to see a
    // mouth move. Turning both toward each other shows two profiles and
    // defeats the bench.
    function _stage() {
        const spk = root.speakerIndex === 0 ? _a : _b
        const lis = root.speakerIndex === 0 ? _b : _a
        spk.turnTo(lis.scenePosition)
        lis.turnTo(Qt.vector3d(_cam.scenePosition.x, 0, _cam.scenePosition.z))
    }

    // A speaker looks at the person it is speaking to. ListenAnim only
    // animates the listening half - the other half is staging, and a bench
    // that leaves the speaker staring into the middle distance is testing
    // the listener against a wall.
    function _aim() {
        const spk = root.speakerIndex === 0 ? _a : _b
        const to = root.speakerIndex === 0 ? _b : _a
        if (!to.head) return
        const p = to.head.scenePosition
        spk.lookAt(Qt.vector3d(p.x, p.y + to.head.eyeLine, p.z))
    }

    onSpeakerIndexChanged: { root._stage(); _aimLater.restart() }

    Component.onCompleted: {
        root._stage()
        _aimLater.start()
        _kick.start()
    }
    // After the turn has been asked for: lookAt is solved against where the
    // body is going, and asking in the same tick solves it against where the
    // body still is.
    Timer { id: _aimLater; interval: 120; onTriggered: root._aim() }
    Timer { id: _kick; interval: 700
            onTriggered: root.speak("Hello there. This is one phrase, and this is another. "
                                    + "Do you follow me so far?") }

    View3D {
        anchors.fill: parent
        camera: _cam
        environment: SceneEnvironment {
            clearColor: "#e8e4dc"
            backgroundMode: SceneEnvironment.Color
            antialiasingMode: SceneEnvironment.MSAA
            antialiasingQuality: SceneEnvironment.High
        }
        PerspectiveCamera {
            id: _cam
            // Well inside the default clipNear of 10, which would swallow the
            // pair entirely.
            clipNear: 0.05; clipFar: 400; fieldOfView: 40
            position: Qt.vector3d(0, 11.5, 26)
            eulerRotation: Qt.vector3d(-6, 0, 0)
        }
        DirectionalLight { eulerRotation: Qt.vector3d(-25, -35, 0); brightness: 1.5 }
        DirectionalLight { eulerRotation: Qt.vector3d(10, 150, 0); brightness: 0.5 }

        Character {
            id: _a
            // The listener takes the deep spot, so whichever one is speaking
            // stands nearer the lens.
            basePos: root.speakerIndex === 0 ? root._nearPos : root._farPos
            detail: Character.Detail.High
            blinkSeed: 3
            // Whoever is not speaking listens - and only while the bench says
            // listening is on, which is the whole comparison.
            listeningTo: (root.listening && root.speakerIndex === 1) ? _b : null
        }
        Character {
            id: _b
            basePos: root.speakerIndex === 0 ? root._farPos : root._nearPos
            detail: Character.Detail.High
            blinkSeed: 11
            skinColor: "#c98a63"
            listeningTo: (root.listening && root.speakerIndex === 0) ? _a : null
        }
    }

    Label {
        anchors.left: parent.left; anchors.top: parent.top; anchors.margins: 10
        color: "#3a3f45"; font.family: "monospace"; font.pixelSize: 13
        text: "listening   " + (root.listening ? "ON" : "off")
            + "\nspeaker     " + (root.speakerIndex === 0 ? "left" : "right")
            + "\nleft  gaze  " + _a.head.gaze.x.toFixed(2) + " " + _a.head.gaze.y.toFixed(2)
            + "   brow " + _a.head.browFlash.toFixed(3)
            + "\nright gaze  " + _b.head.gaze.x.toFixed(2) + " " + _b.head.gaze.y.toFixed(2)
            + "   brow " + _b.head.browFlash.toFixed(3)
    }

    Label {
        anchors.right: parent.right; anchors.bottom: parent.bottom; anchors.margins: 8
        horizontalAlignment: Text.AlignRight
        color: "#6b7075"; font.family: "monospace"; font.pixelSize: 12
        text: "1 say a line   2 play a recording   S swap speaker\n"
            + "L listening on/off"
    }

    Keys.onPressed: (e) => {
        switch (e.key) {
        case Qt.Key_1:
            root.speak("Hello there. This is one phrase, and this is another. "
                       + "Do you follow me so far?"); break
        case Qt.Key_2:
            // No transcript exists for this one, which is the point: the
            // boundaries are read off the mouth either way.
            root.speak(Qt.resolvedUrl("../demo/hello.wav").toString()); break
        case Qt.Key_S: root.swap(); break
        case Qt.Key_L: root.listening = !root.listening; break
        default: return
        }
        e.accepted = true
    }
    MouseArea { anchors.fill: parent; onClicked: root.forceActiveFocus() }
}
