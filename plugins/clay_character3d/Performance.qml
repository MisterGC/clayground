// (c) Clayground Contributors - MIT License, see "LICENSE" file

// Import Strategy:
// - Subdirectories use relative imports (e.g., 'import ".."' to access root)
// - This enables hot-reloading in sandbox development
// - Example files use module imports to demonstrate proper usage
// - Internal components use relative imports for cross-directory access

import QtQuick
import "scripting/performancescript.js" as Script

/*!
    \qmltype Performance
    \inqmlmodule Clayground.Character3D
    \inherits Item
    \brief Plays a performance script - speech and stage directions in one
           string - against a character.

    A performance script is written the way a director writes one: what is said
    and what is done, in the order it happens. Directives sit between asterisks
    and everything else is spoken.

    \qml
    Performance {
        id: perf
        performer: prof
        searchRoot: view3d.scene
    }

    Component.onCompleted: perf.play(
        "*point at battery* This is the battery. (2s) " +
        "*face viewer* *happy* It stores the energy our circuit spends.")
    \endqml

    The vocabulary and the exact grammar are documented in the plugin's
    README; the parser is \c scripting/performancescript.js and is Qt-free, so
    a script can be checked without a running engine.

    \b{Timing.} Directives are instant: they are dispatched and the script
    moves on. Only two things consume time - a \c{*pause*} and a spoken line.
    A line ends when its time hint runs out if it has one, otherwise when the
    performer stops reporting that it is talking, and in either case no later
    than a backstop timeout, so a performer that never reports an end cannot
    hang the script.

    \b{The performer is duck-typed.} Nothing here requires \l Character: a cue
    is dispatched to whatever method of that name the performer has, and a cue
    the performer cannot do is skipped and recorded rather than being an error.
    That is what lets the same script drive a plain \l Character and a kit's
    own character component unchanged.

    \b{Observability.} A script is verified by reading state, not by watching
    it: \l running, \l done, \l cueIndex, \l currentCue, \l firedLog,
    \l skipped and \l errors are all readable from an inspector or a headless
    render, and \l debug narrates every cue to the console.

    \sa Character
*/
Item {
    id: root

    visible: false

    // ============================================================================
    // WHAT IT DRIVES
    // ============================================================================

    /*!
        \qmlproperty var Performance::performer
        \brief The character that acts the script.

        Duck-typed. Cues call, when present: \c say(), \c tell(what, clip),
        \c setEmotion(), \c pointAt(), \c lookAt(), \c turnTo(),
        \c faceViewer(), \c thumbsUp(), \c gesticulate(), \c stopGesture(),
        \c stopSpeaking() / \c quiet(). Speech end is read from \c talking if
        the performer has it, otherwise from \c speaking.
    */
    property var performer: null

    /*!
        \qmlproperty var Performance::searchRoot
        \brief Where the default target resolver looks.

        A target name in a script (\c{*point at battery*}) is a QML
        \c objectName. The default resolver walks this node's children
        recursively for it and uses its \c scenePosition. Ignored when
        \l resolveTarget is set.
    */
    property var searchRoot: null

    /*!
        \qmlproperty var Performance::resolveTarget
        \brief Optional \c{function(name)} returning a vector3d, or null.

        Overrides the \l searchRoot walk for scenes that name their subjects
        themselves. Returning null skips the cue - see \l skipped.
    */
    property var resolveTarget: null

    /*!
        \qmlproperty var Performance::viewerPosition
        \brief Where "viewer" is: a vector3d, or a \c{function()} returning one.

        Needed for \c{*look at viewer*}, and for \c{*face viewer*} when the
        performer has no \c faceViewer() of its own.
    */
    property var viewerPosition: null

    /*!
        \qmlproperty var Performance::voiceOf
        \brief Optional \c{function(sayIndex)} returning a clip url per spoken line.

        The seam for pre-rendered narration: when it returns a non-empty url
        and the performer has \c tell(), the line is played from that file
        instead of being synthesised. \c sayIndex counts spoken lines in the
        current script from 0.
    */
    property var voiceOf: null

    /*!
        \qmlproperty bool Performance::spoken
        \brief Whether lines without a clip are voiced at all.

        True routes them through the performer's \c say(), which for a
        \l Character means the speech engine - text-to-speech where the
        platform has it. False keeps the lab silent: a performer with
        \c tell() shows and mouths the line without asking for audio, which
        is the professor's narration mode. A line with a \l voiceOf clip is
        always played; this switch only decides what a bare line does.
    */
    property bool spoken: true

    /*!
        \qmlproperty var Performance::extraVerbs
        \brief Extra directive names the parser accepts, lower case.

        Directives only one character has. They parse into custom cues and are
        dispatched to a handler registered with \l registerVerb(); an
        unregistered one is skipped and the \l customCue signal is emitted.
        \l registerVerb() adds to this list on its own, so setting this
        property is only needed for verbs handled through the signal.
    */
    property var extraVerbs: []

    /*!
        \qmlproperty bool Performance::debug
        \brief Narrates every cue to the console as it fires.

        \c{[perform] 1234ms cue 3/7: point at battery}
    */
    property bool debug: false

    // ============================================================================
    // WHAT IT REPORTS
    // ============================================================================

    /*! True between \l play() and the last cue (or \l stop()). */
    readonly property bool running: _running
    /*! True once the last cue of the last script has fired. */
    readonly property bool done: _done
    /*! Index of the cue currently being played, -1 before the first one. */
    readonly property int cueIndex: _cueIndex
    /*! How many cues the current script has. */
    readonly property int cueCount: _cues.length
    /*! The current cue as a one-liner, e.g. "point at battery". */
    readonly property string currentCue: _currentCue
    /*!
        Parse errors of the last \l play(), each \c {{at, directive, message}}.
        A script with errors is not played.
    */
    readonly property var errors: _errors
    /*!
        Cues that could not be carried out, each \c {{cue, reason}} - an
        unresolved target, a verb the performer does not have, a custom verb
        whose handler threw. The script continues past every one of them.
    */
    readonly property var skipped: _skipped
    /*!
        Every cue that fired, each \c {{ms, cue}}, with ms measured from
        \l play(). The record of what actually happened, for a script that has
        to be debugged without being watched.
    */
    readonly property var firedLog: _firedLog

    /*! Emitted after the last cue of a script. Not emitted by \l stop(). */
    signal finished()
    /*!
        Emitted as each cue is dispatched: \a type is the cue's kind
        ("point", "say", "face", "emotion", ...) and \a arg its argument
        (the target name, the spoken text, the emotion). The hook for
        choreography AROUND the performer - a scene that moves its camera in
        when the character turns to the viewer listens for
        \c {type === "face"} here rather than polling state.
    */
    signal cueFired(string type, string arg)
    /*! Emitted for a custom cue that has no handler registered. */
    signal customCue(string verb, string arg)

    // ============================================================================
    // API
    // ============================================================================

    /*!
        \qmlmethod bool Performance::play(string script)
        \brief Parses \a script strictly and plays it from the first cue.

        Returns false and plays nothing when the script has parse errors; they
        are then in \l errors and summarized with one console error. Stops
        whatever was running first.
    */
    function play(script) {
        stop()
        const parsed = Script.parse("" + script, { strict: true,
                                                   extraVerbs: _verbNames() })
        _cues = parsed.cues
        _errors = parsed.errors
        _firedLog = []
        _skipped = []
        _warned = ({})
        _sayIndex = 0
        _emotion = ""
        _cueIndex = -1
        _currentCue = ""
        _done = false
        if (_errors.length > 0) {
            console.error("[perform] " + _errors.length + " error(s), not playing:\n  "
                          + _errors.map(function (e) {
                              return "at " + e.at + ": " + e.message
                          }).join("\n  "))
            return false
        }
        // An empty script is not an error: it starts, finds no cues and
        // reports finished(), so a caller waiting on that never hangs.
        _start(0)
        return true
    }

    /*!
        \qmlmethod bool Performance::playFrom(int index)
        \brief Plays the script parsed by the last \l play() from cue \a index.

        A debugging aid: it skips straight to the cue in question instead of
        sitting through the ones before it. Returns false when there is
        nothing parsed, or the index is past the end.
    */
    function playFrom(index) {
        if (_cues.length === 0) {
            console.warn("[perform] nothing parsed - call play(script) first")
            return false
        }
        if (index < 0 || index >= _cues.length) {
            console.warn("[perform] no cue " + index + " (script has "
                         + _cues.length + ")")
            return false
        }
        _start(index)
        return true
    }

    function _start(index) {
        _stopTimers()
        _next = index
        _done = false
        _running = true
        _t0 = Date.now()
        _advance.restart()
    }

    /*!
        \qmlmethod void Performance::stop()
        \brief Halts the script where it is and silences the performer.

        Disarms every timer, ends any speech (\c stopSpeaking() or \c quiet())
        and drops any gesture (\c stopGesture()). Does not emit \l finished().
    */
    function stop() {
        _stopTimers()
        _running = false
        _currentCue = ""
        // Whichever of the three the performer calls it.
        if (!_call("stopSpeaking") && !_call("hush"))
            _call("quiet")
        _call("stopGesture")
    }

    /*!
        \qmlmethod void Performance::registerVerb(string name, var handler)
        \brief Teaches the parser a directive and what to do with it.

        \a name is a lower-case directive name, possibly several words
        ("board out"); \a handler is called with the directive's argument
        (the empty string when it has none). A handler that throws does not
        stop the script - the cue is recorded in \l skipped.
    */
    function registerVerb(name, handler) {
        const n = ("" + name).trim().replace(/\s+/g, " ").toLowerCase()
        if (n === "") return
        _handlers[n] = handler
        if (extraVerbs.indexOf(n) < 0)
            extraVerbs = extraVerbs.concat([n])
    }

    /*!
        \qmlmethod int Performance::estimateMs(string text)
        \brief How long the performer is expected to take over \a text, in ms.

        The speech engine's own estimate when it can be reached
        (\c{performer.character.speech}), otherwise 72 ms per character - the
        rate measured off pre-rendered narration. This is what the backstop
        timeout is built from; a line with a time hint does not use it.
    */
    function estimateMs(text) {
        const t = "" + text
        const engines = [performer && performer.character ? performer.character.speech : null,
                         performer ? performer.speech : null]
        for (let i = 0; i < engines.length; ++i) {
            const e = engines[i]
            if (e && typeof e.estimateDurationMs === "function") {
                const ms = e.estimateDurationMs(t)
                if (ms > 0) return ms
            }
        }
        return 72 * t.length
    }

    // ============================================================================
    // INTERNALS
    // ============================================================================

    property var _cues: []
    property var _errors: []
    property var _skipped: []
    property var _firedLog: []
    property var _handlers: ({})
    property var _warned: ({})
    property bool _running: false
    property bool _done: false
    property int _cueIndex: -1
    property int _next: 0
    property int _sayIndex: 0
    property string _currentCue: ""
    property string _emotion: ""
    property bool _emotionPending: false
    // What the wait timer is waiting for: "", "pause", "hint" or "speech".
    property string _waiting: ""
    // Whether the performer was seen to START the line we are waiting on. The
    // talking flag is false before a line as well as after it, so without this
    // the falling edge that arms us is the one from the previous line.
    property bool _sawTalking: false
    property double _t0: 0

    // Script time: milliseconds since play(), off a base this component owns.
    function _elapsed() { return Math.round(Date.now() - _t0) }

    function _verbNames() {
        let names = (extraVerbs || []).slice()
        for (const k in _handlers)
            if (names.indexOf(k) < 0) names.push(k)
        return names
    }

    function _stopTimers() {
        _advance.stop()
        _wait.stop()
        _waiting = ""
        _sawTalking = false
    }

    // Calls a method on the performer if it has one. false = it has not.
    // Arity matters: a C++ invokable refuses arguments it did not ask for.
    function _call(name, arg) {
        if (!performer || typeof performer[name] !== "function")
            return false
        if (arg === undefined)
            performer[name]()
        else
            performer[name](arg)
        return true
    }

    function _skip(cue, reason) {
        _skipped = _skipped.concat([{ cue: Script.describe(cue), reason: reason }])
        const key = Script.describe(cue) + "|" + reason
        if (!_warned[key]) {
            _warned[key] = true
            console.warn("[perform] skipped " + Script.describe(cue) + ": " + reason)
        }
    }

    // Every advance goes through the zero-interval timer, so a script of
    // instant directives runs one cue per event-loop turn instead of one deep
    // call stack.
    function _advanceLater() {
        if (_running)
            _advance.restart()
    }

    function _play() {
        if (!_running)
            return
        if (_next >= _cues.length) {
            _running = false
            _done = true
            _currentCue = ""
            if (debug)
                console.log("[perform] " + _elapsed() + "ms done, "
                            + _cues.length + " cues")
            root.finished()
            return
        }
        const cue = _cues[_next]
        _cueIndex = _next
        _next++
        _currentCue = Script.describe(cue)
        const ms = _elapsed()
        _firedLog = _firedLog.concat([{ ms: ms, cue: _currentCue }])
        if (debug)
            console.log("[perform] " + ms + "ms cue " + (_cueIndex + 1) + "/"
                        + _cues.length + ": " + _currentCue)
        cueFired(cue.type,
                 cue.target !== undefined ? "" + cue.target
                 : cue.text !== undefined ? "" + cue.text
                 : cue.value !== undefined ? "" + cue.value
                 : cue.verb !== undefined ? "" + cue.verb : "")
        _dispatch(cue)
    }

    function _dispatch(cue) {
        switch (cue.type) {
        case "emotion":
            // The face is the performer's business if it has one; otherwise the
            // annotation rides along in the next spoken line, which is the path
            // Character.say() has always understood.
            _emotion = cue.value
            _emotionPending = !_call("setEmotion", cue.value)
            _advanceLater()
            break
        case "point":
        case "look":
        case "face":
            _aim(cue)
            _advanceLater()
            break
        case "thumbsUp":
            if (!_call("thumbsUp")) _skip(cue, "performer has no thumbsUp()")
            _advanceLater()
            break
        case "gesticulate":
            if (!_call("gesticulate")) _skip(cue, "performer has no gesticulate()")
            _advanceLater()
            break
        case "rest":
            if (!_call("stopGesture")) _skip(cue, "performer has no stopGesture()")
            _advanceLater()
            break
        case "pause":
            _waiting = "pause"
            _wait.interval = Math.max(1, cue.ms)
            _wait.restart()
            break
        case "say":
            _say(cue)
            break
        case "custom":
            _custom(cue)
            _advanceLater()
            break
        default:
            _skip(cue, "no dispatch for cue type '" + cue.type + "'")
            _advanceLater()
        }
    }

    // --- directions -------------------------------------------------------------

    function _aim(cue) {
        const viewer = cue.target === "viewer"
        // A performer that knows how to face the camera knows better than we do
        // where the camera is.
        if (cue.type === "face" && viewer && _call("faceViewer"))
            return
        const pos = _resolve(cue.target)
        if (!pos) {
            _skip(cue, "target '" + cue.target + "' did not resolve")
            return
        }
        if (cue.type === "point") {
            if (!_call("pointAt", pos)) _skip(cue, "performer has no pointAt()")
        } else if (cue.type === "look") {
            // Head-only if the performer has a head aim, whole body otherwise.
            if (!_call("lookAt", pos) && !_call("turnTo", pos))
                _skip(cue, "performer has neither lookAt() nor turnTo()")
        } else {
            if (!_call("turnTo", pos)) _skip(cue, "performer has no turnTo()")
        }
    }

    function _resolve(name) {
        if (name === "viewer") {
            // viewerPosition first; a scene that would rather resolve "viewer"
            // itself can still do so through the resolver below.
            const vp = _viewerPos()
            if (vp) return vp
        }
        if (typeof resolveTarget === "function") {
            const p = resolveTarget(name)
            return (p && p.x !== undefined) ? p : null
        }
        const node = _findNamed(searchRoot, name, 0)
        if (!node)
            return null
        if (node.scenePosition !== undefined)
            return node.scenePosition
        if (node.position !== undefined)
            return node.position
        return null
    }

    function _viewerPos() {
        const v = viewerPosition
        if (!v) return null
        const p = (typeof v === "function") ? v() : v
        return (p && p.x !== undefined) ? p : null
    }

    // Walks the scene for an objectName. Depth-capped: a resolver that has to
    // be told where to look is better than one that recurses forever.
    function _findNamed(node, name, depth) {
        if (!node || depth > 16)
            return null
        if (node.objectName === name)
            return node
        // `children` where the type has it (Item, Node), `data` otherwise -
        // and `data` also when children is empty, because a plain QtObject
        // holder keeps its content there.
        let list = node.children
        if (list === undefined || list === null || list.length === 0)
            list = node.data
        if (list === undefined || list === null || list.length === undefined)
            return null
        for (let i = 0; i < list.length; ++i) {
            const hit = _findNamed(list[i], name, depth + 1)
            if (hit) return hit
        }
        return null
    }

    function _custom(cue) {
        const h = _handlers[cue.verb]
        if (typeof h !== "function") {
            _skip(cue, "no handler registered for '" + cue.verb + "'")
            root.customCue(cue.verb, cue.arg)
            return
        }
        try {
            h(cue.arg)
        } catch (e) {
            // One bad verb must not take the rest of the performance with it.
            _skip(cue, "handler threw: " + e)
        }
    }

    // --- speech -----------------------------------------------------------------

    function _say(cue) {
        if (!performer) {
            _skip(cue, "no performer")
            _advanceLater()
            return
        }
        const clip = _clipFor(_sayIndex)
        _sayIndex++
        const timed = cue.hintMs !== null && cue.hintMs !== undefined
        // Armed BEFORE the performer is asked to speak: a performer that
        // reports itself talking inside say() - most of them do - would
        // otherwise raise its edge into a sequencer that is not listening yet,
        // and the line could then only end on the backstop.
        _waiting = timed ? "hint" : "speech"
        _sawTalking = false

        const hasTell = typeof performer.tell === "function"
        const hasSay = typeof performer.say === "function"
        if (clip !== "" && hasTell) {
            performer.tell(cue.text, clip)
        } else if (!spoken && hasTell) {
            // Silent narration: the line is shown and mouthed, never voiced.
            performer.tell(cue.text)
        } else if (hasSay) {
            // Only the say() path carries an inline annotation: tell() puts its
            // argument on screen, where "*happy*" would be read by the eye.
            performer.say(_emotionPending && _emotion !== ""
                          ? "*" + _emotion + "* " + cue.text : cue.text)
        } else if (hasTell) {
            performer.tell(cue.text)
        } else {
            _waiting = ""
            _skip(cue, "performer can neither say() nor tell()")
            _advanceLater()
            return
        }

        if (timed) {
            // One clock, and the author owns it: the hint decides, even if the
            // performer is still talking when it runs out.
            _wait.interval = Math.max(1, cue.hintMs)
        } else {
            // The performer's own end, with a backstop under it - a clip that
            // never decodes or an engine that never reports must not hang the
            // script for the rest of the session.
            if (_speechState.talking)
                _sawTalking = true
            _wait.interval = Math.max(500, Math.round(estimateMs(cue.text) * 1.5) + 2000)
        }
        _wait.restart()
    }

    function _clipFor(index) {
        if (typeof voiceOf !== "function")
            return ""
        const c = voiceOf(index)
        return (c === undefined || c === null) ? "" : "" + c
    }

    // The performer's talking state, whatever it calls it.
    QtObject {
        id: _speechState
        readonly property bool talking: {
            const p = root.performer
            if (!p) return false
            if (p.talking !== undefined) return p.talking
            if (p.speaking !== undefined) return p.speaking
            return false
        }
        onTalkingChanged: {
            if (!root._running || root._waiting !== "speech")
                return
            if (talking) {
                root._sawTalking = true
                return
            }
            if (!root._sawTalking)
                return
            _wait.stop()
            root._waiting = ""
            root._advanceLater()
        }
    }

    // --- timers -------------------------------------------------------------------

    // Cue advance. Zero interval, so the stack never nests one cue inside the
    // dispatch of the one before it.
    Timer {
        id: _advance
        interval: 0
        repeat: false
        onTriggered: root._play()
    }

    // Pause, time hint, and the backstop under a spoken line.
    Timer {
        id: _wait
        repeat: false
        onTriggered: {
            if (root.debug && root._waiting === "speech")
                console.log("[perform] " + root._elapsed()
                            + "ms backstop fired - the performer never reported an end")
            root._waiting = ""
            root._advanceLater()
        }
    }
}
