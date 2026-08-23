// (c) Clayground Contributors - MIT License, see "LICENSE" file
// @brief The same line read by both lip-sync tiers, side by side
// @tags 3D, Character, Speech, Lipsync
// @category Plugin Benches
//
// The bench for the audio path. Two heads, one recording, one clock - the
// left one gets loudness, the right one gets formants - so the thing being
// judged is judged by looking at two mouths at once rather than by
// remembering what the last one did.
//
// What it is for:
//
//   * The envelope tier cannot tell "oo" from "ee": both are a slot at
//     whatever size the loudness asks for. Whether the spectral tier's
//     answer is actually the right shape is not something its unit tests
//     can say - they only prove it is a CONSISTENT shape.
//   * Every recording is a different room, microphone and voice. The two
//     committed wavs are one speaking voice and one singing one, and the
//     singing one is the awkward case on purpose.
//   * effectiveAccuracy in the readout is the honest one: it says what the
//     line actually got, which is not always what was asked for.
//
//   ./build/bin/claydojo --sbx plugins/clay_character3d/bench/SpeechSandbox.qml
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

    /*! Which committed recording to read. */
    property string source: "hello.wav"
    /*! Start speaking as soon as the scene is up - so a one-shot render lands
        mid-line instead of on two closed mouths. */
    property bool autoPlay: true

    readonly property real spread: 1.5

    function play(what) {
        root.source = what
        const url = Qt.resolvedUrl("../demo/" + what)
        _envSpeech.sayAudio(url)
        _spcSpeech.sayAudio(url)
    }
    function stop() { _envSpeech.stop(); _spcSpeech.stop() }

    // Two engines, not one: the tier is a property of the analysis, so
    // comparing tiers means two analyses of the same file. They are started
    // in the same call and both clock off their own player's position, which
    // is what keeps the two mouths on the same syllable.
    Speech { id: _envSpeech; accuracy: Speech.Envelope; volume: 1.0 }
    Speech { id: _spcSpeech; accuracy: Speech.Spectral; volume: 0.0 }

    Component.onCompleted: if (root.autoPlay) root.play(root.source)

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
            // Well inside the default clipNear of 10, which would swallow a
            // head-sized subject entirely.
            clipNear: 0.05; clipFar: 400; fieldOfView: 30
            position: Qt.vector3d(0, 0.72, 6.4)
        }
        DirectionalLight { eulerRotation: Qt.vector3d(-25, -35, 0); brightness: 1.5 }
        DirectionalLight { eulerRotation: Qt.vector3d(10, 150, 0); brightness: 0.5 }

        // basePos, never x. A Head is a BodyPart, and BodyPart binds position
        // to basePos - an x set here is overwritten the moment that binding
        // evaluates and both heads sit on top of each other.
        Head {
            id: _envHead
            basePos: Qt.vector3d(-root.spread, 0, 0)
            detail: Head.Detail.High
            speechSource: _envSpeech
            skinColor: "#d38d5f"; hairColor: "#734120"; eyeColor: "#4a3728"
        }
        Head {
            id: _spcHead
            basePos: Qt.vector3d(root.spread, 0, 0)
            detail: Head.Detail.High
            speechSource: _spcSpeech
            skinColor: "#d38d5f"; hairColor: "#734120"; eyeColor: "#4a3728"
        }
    }

    component Readout: Column {
        required property string title
        required property var engine
        spacing: 2
        Label { text: parent.title; color: "#3a3f45"; font.pixelSize: 15; font.bold: true }
        Label {
            color: "#6b7075"; font.family: "monospace"; font.pixelSize: 12
            text: "open  " + parent.engine.mouthOpen.toFixed(2)
                + "\nwide  " + parent.engine.mouthWide.toFixed(2)
                + "\nround " + parent.engine.mouthRound.toFixed(2)
                + "\ngot   " + (parent.engine.effectiveAccuracy === Speech.Envelope
                                ? "envelope" : "spectral")
        }
    }

    Row {
        anchors.top: parent.top; anchors.topMargin: 12
        anchors.horizontalCenter: parent.horizontalCenter
        spacing: 0
        Readout { width: root.width / 2; title: "Envelope"; engine: _envSpeech }
        Readout { width: root.width / 2; title: "Spectral"; engine: _spcSpeech }
    }

    Label {
        anchors.right: parent.right; anchors.bottom: parent.bottom; anchors.margins: 8
        horizontalAlignment: Text.AlignRight
        color: "#6b7075"; font.family: "monospace"; font.pixelSize: 12
        text: "playing " + root.source + "\n1 hello   2 sing   S stop"
    }

    Keys.onPressed: (e) => {
        switch (e.key) {
        case Qt.Key_1: root.play("hello.wav"); break
        case Qt.Key_2: root.play("sing.wav"); break
        case Qt.Key_S: root.stop(); break
        default: return
        }
        e.accepted = true
    }
    MouseArea { anchors.fill: parent; onClicked: root.forceActiveFocus() }
}
