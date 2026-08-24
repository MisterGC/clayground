// (c) Clayground Contributors - MIT License, see "LICENSE" file
//
// ListenAnim against stub characters.
//
// It asks a listener for a head and a lookAt(), and a speaker for whether it
// is speaking, where its head is, and how open its mouth is. All six are
// answerable by a QtObject, and driving the mouth from the test rather than
// from a speech engine is what makes "a gap of 150 ms ends a phrase"
// something this suite can state rather than hope for.

import QtQuick
import QtTest
import "../../animation"

Item {
    id: root
    width: 50; height: 50

    component StubHead: QtObject {
        property real eyeLine: 0.8
        property vector3d scenePosition: Qt.vector3d(0, 0, 0)
        property int nods: 0
        property int brows: 0
        property int blinks: 0
        function nod(deg, times) { nods++ }
        function flashBrows(a) { brows++ }
        function blink() { blinks++ }
        function reactions() { return nods + brows + blinks }
        function reset() { nods = 0; brows = 0; blinks = 0 }
    }

    component StubChar: QtObject {
        property StubHead head: StubHead {}
        property bool speaking: false
        property QtObject speech: QtObject { property real mouthOpen: 0 }
        // What lookAt() was last handed, and how often it was handed anything.
        property var lookedAt: undefined
        property int looks: 0
        property int releases: 0
        function lookAt(p) {
            lookedAt = p
            if (p === null || p === undefined) releases++
            else looks++
        }
    }

    TestCase {
        id: tc
        name: "ListenAnim"
        when: windowShown

        StubChar { id: hearer }
        StubChar { id: talker }

        ListenAnim {
            id: listen
            listener: hearer
            speaker: talker
            running: false
            seed: 5
        }

        function init() {
            listen.running = false
            talker.speaking = false
            talker.speech.mouthOpen = 0
            talker.head.scenePosition = Qt.vector3d(4, 9, 2)
            hearer.head.reset()
            hearer.lookedAt = undefined
            hearer.looks = 0
            hearer.releases = 0
        }
        function cleanup() { listen.running = false }

        // One phrase: the mouth opens, then shuts for longer than the gap the
        // component calls a boundary.
        function sayPhrase() {
            talker.speech.mouthOpen = 0.6
            wait(200)
            talker.speech.mouthOpen = 0.0
            wait(350)
        }

        function test_looks_at_the_speakers_face_not_its_feet() {
            listen.running = true
            tryVerify(function() { return hearer.lookedAt !== undefined }, 2000)
            const p = hearer.lookedAt
            verify(p !== null, "handed null while the speaker was there")
            compare(p.x, 4)
            compare(p.z, 2)
            // Raised to the eyes. Aiming at the head node's origin points a
            // listener at the speaker's neck.
            compare(p.y, 9 + talker.head.eyeLine)
        }

        function test_stopping_hands_the_eyes_back() {
            listen.running = true
            tryVerify(function() { return hearer.looks > 0 }, 2000)
            listen.running = false
            compare(hearer.lookedAt, null)
        }

        function test_a_phrase_boundary_is_a_gap_while_still_speaking() {
            listen.running = true
            talker.speaking = true
            let fired = 0
            listen.phraseEnded.connect(function() { fired++ })
            sayPhrase()
            compare(fired, 1)
        }

        function test_a_gap_that_is_only_the_end_of_the_turn_is_not_a_phrase() {
            // Silence AFTER a line is the turn ending, not a phrase ending -
            // otherwise every line is acknowledged twice, once at its end.
            listen.running = true
            talker.speaking = false
            let fired = 0
            listen.phraseEnded.connect(function() { fired++ })
            talker.speech.mouthOpen = 0.6
            wait(200)
            talker.speech.mouthOpen = 0
            wait(350)
            compare(fired, 0)
        }

        function test_a_flicker_shorter_than_the_gap_is_not_a_boundary() {
            listen.running = true
            talker.speaking = true
            let fired = 0
            listen.phraseEnded.connect(function() { fired++ })
            talker.speech.mouthOpen = 0.6
            wait(200)
            talker.speech.mouthOpen = 0     // shut, but only briefly
            wait(60)
            talker.speech.mouthOpen = 0.6
            wait(200)
            compare(fired, 0)
        }

        function test_boundaries_are_acknowledged_but_not_all_of_them() {
            listen.running = true
            talker.speaking = true
            const rounds = 14
            for (var i = 0; i < rounds; ++i)
                sayPhrase()
            const r = hearer.head.reactions()
            // Something has to happen, or it is not a listener.
            verify(r > 0, "no reaction in " + rounds + " phrases")
            // And not on every one: a reaction to all of them is a nodding
            // dog, and the silence between them is what makes the ones that
            // land read as agreement rather than as a tic.
            verify(r < rounds, r + " reactions in " + rounds + " phrases")
        }

        function test_nodding_is_among_what_it_does() {
            // The strongest backchannel there is and the one a viewer names.
            listen.running = true
            talker.speaking = true
            for (var i = 0; i < 20; ++i) {
                sayPhrase()
                if (hearer.head.nods > 0)
                    break
            }
            verify(hearer.head.nods > 0, "never nodded")
        }

        function test_no_speaker_means_no_behaviour() {
            listen.speaker = null
            listen.running = true
            wait(300)
            compare(hearer.looks, 0)
            listen.speaker = talker
        }
    }
}
