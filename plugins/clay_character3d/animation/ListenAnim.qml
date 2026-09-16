// (c) Clayground Contributors - MIT License, see "LICENSE" file
import QtQuick

/*!
    \qmltype ListenAnim
    \inqmlmodule Clayground.Character3D
    \inherits QtObject
    \brief What a character does while somebody else is talking.

    Everything else in this plugin describes a character while it SPEAKS -
    emotion, gesture, gaze, lip-sync. The one who is not speaking has had no
    behaviour at all, which is what makes two characters in conversation read
    as two monologues taking turns rather than as a conversation.

    A listener is mostly its eyes. It holds the speaker, breaks away every
    few seconds because a continuous stare is not attention but a threat, and
    marks the ends of phrases - a blink, sometimes a brow.

    The phrase boundaries come from the SPEAKER'S MOUTH rather than from its
    script: a gap in \l Speech::mouthOpen while it is still speaking is the
    end of a phrase, whatever produced the timeline. That works for a plain
    envelope reading of an unknown recording exactly as it does for an
    aligned one, which is what makes this usable on dialogue nobody wrote
    down.

    A nod is the signature of listening, and it needs the head to be able to
    do two things at once - hold an aim and dip - which is what
    \l Head::poseEuler and \l Head::offsetEuler are for. A nod here does not
    disturb where the listener is looking.

    \sa Character::listeningTo, GazeAnim, Speech
*/
QtObject {
    id: root

    /*! The character doing the listening - needs \c head and \c lookAt(). */
    property var listener: null

    /*! Who is being listened to. Anything with \c speaking, \c speech and
        \c head will do; a \l Character is what this is for. */
    property var speaker: null

    property bool running: true

    /*! Same seed, same rhythm, every run - see \l GazeAnim for why nothing
        in an idle face is allowed to read a wall clock. */
    property int seed: 1

    /*! True while a phrase boundary has just gone by. Mostly of interest to
        whatever wants to hang something else off one. */
    signal phraseEnded()

    readonly property QtObject _s: QtObject {
        // Ticks the speaker's mouth has been shut for.
        property int quiet: 0
        property bool inPhrase: false
        // Ticks until the next deliberate glance away, and how long it lasts.
        property int untilBreak: 90
        property int breakLeft: 0
        // real, not int - see GazeAnim: a QML int is signed 32-bit and an
        // LCG state that reaches 2^32 comes back out negative.
        property real rng: Math.max(1, root.seed)
    }

    function _rand() {
        _s.rng = (_s.rng * 16807) % 2147483647
        return _s.rng / 2147483647
    }

    function _valid(o) { return o !== null && o !== undefined }

    function _speaking() {
        return _valid(root.speaker) && root.speaker.speaking === true
    }

    // Where on the speaker to look: the face, not the feet.
    function _focus() {
        const sp = root.speaker
        if (!_valid(sp) || !_valid(sp.head))
            return null
        const p = sp.head.scenePosition
        if (!_valid(p))
            return null
        const eye = sp.head.eyeLine === undefined ? 0 : sp.head.eyeLine
        return Qt.vector3d(p.x, p.y + eye, p.z)
    }

    // What a listener does at the end of a phrase. Not every one gets
    // something: a reaction to all of them is a nodding dog, and the silence
    // between them is what makes the ones that land read as agreement rather
    // than as a tic.
    //
    // A nod is the strongest of these and the one a viewer names, so it is
    // the most likely - shallow, because this is acknowledgement and not
    // assent to a proposal.
    function _react() {
        const h = root._valid(root.listener) ? root.listener.head : null
        if (!root._valid(h))
            return
        const r = root._rand()
        if (r < 0.40) {
            if (h.nod !== undefined)
                h.nod(5 + root._rand() * 4, root._rand() < 0.25 ? 2 : 1)
        } else if (r < 0.62) {
            if (h.flashBrows !== undefined)
                h.flashBrows(0.22 + root._rand() * 0.18)
        } else if (r < 0.80) {
            if (h.blink !== undefined)
                h.blink()
        }
    }

    function _release() {
        if (_valid(root.listener) && root.listener.lookAt !== undefined)
            root.listener.lookAt(null)
    }

    onRunningChanged: if (!running) _release()

    readonly property Timer _tick: Timer {
        running: root.running && root._valid(root.listener) && root._valid(root.speaker)
        interval: 50
        repeat: true
        onTriggered: {
            const L = root.listener

            // A glance away every few seconds. Handing the target back to
            // null is enough - GazeAnim's wander is already what eyes do
            // with nothing in particular to look at, so a break needs no
            // behaviour of its own.
            if (_s.breakLeft > 0) {
                if (--_s.breakLeft === 0)
                    _s.untilBreak = 60 + Math.floor(root._rand() * 100)
            } else if (--_s.untilBreak <= 0) {
                _s.breakLeft = 8 + Math.floor(root._rand() * 10)   // .4 - .9 s
                root._release()
            }

            if (_s.breakLeft === 0) {
                const f = root._focus()
                if (f !== null && L.lookAt !== undefined)
                    L.lookAt(f)
            }

            // Phrase boundaries, read off the speaker's mouth. Only while it
            // is actually speaking - the silence AFTER a line is not a
            // phrase ending, it is the end of the turn.
            const sp = root.speaker
            const open = (root._valid(sp.speech) && sp.speech.mouthOpen !== undefined)
                       ? sp.speech.mouthOpen : 0
            if (root._speaking()) {
                if (open > 0.12) {
                    _s.inPhrase = true
                    _s.quiet = 0
                } else if (_s.inPhrase && ++_s.quiet >= 3) {   // 150 ms shut
                    _s.inPhrase = false
                    _s.quiet = 0
                    root.phraseEnded()
                    root._react()
                }
            } else {
                _s.inPhrase = false
                _s.quiet = 0
            }
        }
    }
}
