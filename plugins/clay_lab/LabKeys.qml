// (c) Clayground Contributors - MIT License, see "LICENSE" file

import QtQuick

/*!
    \qmltype LabKeys
    \inqmlmodule Clayground.Lab
    \brief The canonical lab key map, and the help text that describes it.

    Every lab reserves the same keys for the same things - scenarios on
    \c 1..9, \c T for the guided flow, \c F/\c 0 for the view, \c Shift+R to
    record - and every lab used to re-implement them in one long
    \c Keys.onPressed. This owns the reserved half, takes the lab's own keys
    as data, and can then \e describe the whole map, which is how a lab stops
    hiding its features behind undocumented letters.

    The navigation half, on a camera that has the exploration layer
    (\c panBy / \c goalDistance - see \l {OrbitCamera3D}): \b arrows and
    \b WASD move across the scene, \b {Shift+arrows} turn it, \c + / \c -
    zoom, \c F frames the selection and \c 0 or \c Home frames everything.
    With a \l jump wired, \c f (no Shift) starts keyboard selection and
    framing moves to \c Shift+F - f acquires, F frames.
    WASD is reserved for the same reason the arrows are - it is the gesture
    every viewer already knows - which is why a lab may not spend those four
    letters on anything else. The arrows used to
    turn, which is what a drag already did; travelling was the thing a
    keyboard could not do at all. While a flow runs, \c → and \c ← belong to
    the flow, so the arrows are the camera's only when nothing is narrating.

    The interaction half, on a lab that hands over its \l pointer: \b Space
    pans on the left button while it is held, which is the one gesture the
    left button ever lends the camera. There is no build key, because there is
    no build mode - a tool is something you pick up. With an \l hands belt
    wired up, \c H takes the next instrument (and past the last one, puts
    everything down), \c P keeps the reading it is showing, \b Backspace takes
    the last point back and \b Esc ends the measurement. All of them are
    described here for the same reason as everything else - a key nobody can
    find is a key the lab does not have.

    Non-visual: keep focus handling where it is and call \l handle() from the
    lab's own key handler, and \l handleRelease() from \c Keys.onReleased.

    \qml
    Item {
        focus: true
        Keys.onPressed: (ev) => keymap.handle(ev)
        Keys.onReleased: (ev) => keymap.handleRelease(ev)

        LabKeys {
            id: keymap
            lab: root
            camera: rig
            pointer: nav
            flow: introFlow
            recorder: recorder
            keys: [
                { key: "R", label: "key.simulate", action: () => root.toggleSim() },
                { key: "V", label: "key.values",   action: () => root.showValues = !root.showValues }
            ]
        }
    }
    \endqml

    \sa LabHelp, ScenarioBar, Flow
*/
Item {
    id: root
    visible: false

    /*!
        \qmlproperty var LabKeys::lab
        \brief The sandbox root - supplies \c scenarios(), \c applyScenario()
        and the framing functions.
    */
    property var lab: null

    /*!
        \qmlproperty var LabKeys::camera
        \brief An OrbitCamera3D (or anything with orbitBy/zoomBy).
    */
    property var camera: null

    /*!
        \qmlproperty var LabKeys::flow
        \brief The lab's Flow, if it has one.
    */
    property var flow: null

    /*!
        \qmlproperty var LabKeys::recorder
        \brief A DataRecorder toggled by Shift+R.
    */
    property var recorder: null

    /*!
        \qmlproperty var LabKeys::pointer
        \brief An \c OrbitInput3D, for the one key that touches the mouse.

        \b Space lends the left button to the camera \e while it is held - a
        quasimode, which is why this lives here rather than in the lab: a key
        RELEASE has to be seen too. Wire \l handleRelease from the lab's
        \c Keys.onReleased.

        Space is shared with a running \l flow, which keeps it: while a
        narration is on screen, Space is "next step" in every lab, and the
        temporary hand is not what a reader is reaching for. Nothing else in
        the map claims it.
    */
    property var pointer: null

    /*!
        \qmlproperty var LabKeys::hands
        \brief An \l InstrumentBelt - the keys that take, edit and keep a reading.

        \c H walks the belt, \c P keeps the reading, \c Backspace (and
        \c Delete) takes the last point back and \c Esc ends the measurement -
        the editing keys only while something is actually in the hand, which is
        what lets a lab keep \c Del for deleting the thing it builds.
    */
    property var hands: null

    /*!
        \qmlproperty var LabKeys::jump
        \brief A \l HintJump - keyboard selection on \c f.

        Wiring one SPLITS the frame key: \c f (no Shift) puts the jump labels
        up, \c Shift+F frames the selection - the map's first
        Shift-differentiated letter pair, after the precedent of \c Shift+R
        and the Shift-arrows. A lab without a jump keeps plain \c F framing,
        so nothing existing changes until a lab opts in. While the labels are
        up every key is routed to the jump - a text-entry context, like the
        pin prompt, not a mode.
    */
    property var jump: null

    /*!
        \qmlproperty var LabKeys::hints
        \brief A \l HintBar for refusals - a key that cannot act says why.

        A refused key must never be silent (and must never touch the clock,
        the RNG or the view state): with a bar wired, "no earlier view" is a
        flashed line instead of nothing happening. \l refused fires either
        way, for a lab that wants its own channel.
    */
    property var hints: null

    /*!
        \qmlsignal LabKeys::refused(string reason)
        \brief A reserved key was pressed and could not act; \a reason is the
        LabLang key describing what was missing.
    */
    signal refused(string reason)

    function _refuse(reason) {
        refused(reason)
        if (hints && hints.flash) hints.flash(LabLang.t(reason))
    }

    /*!
        \qmlproperty var LabKeys::selection
        \brief The selected part's card as a keyboard target.

        An adapter the lab supplies: \c {active} (something is selected),
        \c {moveFocus(d)}, \c {adjust(d) -> bool} and \c {operate() -> bool}.
        While active, \c j/\c k walk the card's control rows, \c h/\c l
        adjust the focused one (step a value, flip a toggle, cycle an
        option) and \b Enter operates the part's actuator. These live
        \e only under a selection - the nearest-context rule, which is also
        how \c h can belong to the card here and to the belt otherwise
        (\c Esc clears the selection first). \c adjust/\c operate return
        false to refuse, and the refusal is spoken through \l hints.
    */
    property var selection: null

    /*!
        \qmlproperty bool LabKeys::selectionKeys
        \readonly
        \brief A card is selected, so its keys are live.
    */
    readonly property bool selectionKeys:
        selection !== null && selection !== undefined && selection.active

    /*!
        \qmlproperty string LabKeys::handKey
        \brief The letter that walks the belt.
    */
    property string handKey: "H"

    /*!
        \qmlproperty string LabKeys::pinKey
        \brief The letter that keeps a reading.
    */
    property string pinKey: "P"

    /*!
        \qmlproperty bool LabKeys::navKeys
        \readonly
        \brief There is a pointer, so Space can lend it to the camera.
    */
    readonly property bool navKeys: pointer !== null && pointer !== undefined

    /*!
        \qmlproperty bool LabKeys::handKeys
        \readonly
        \brief There is a belt to take instruments from.
    */
    readonly property bool handKeys: hands !== null && hands !== undefined

    /*!
        \qmlproperty bool LabKeys::measureKeys
        \readonly
        \brief A measurement is being taken right now, so its editing keys are live.
    */
    readonly property bool measureKeys: handKeys && hands.held !== null

    /*!
        \qmlproperty var LabKeys::keys
        \brief The lab's own keys: \c {[{key, label, action, hidden}]}.

        \c key is the printable letter (\c "V"), \c label a LabLang key
        describing it, \c action the function to run. Entries appear in
        \l entries and therefore in LabHelp, so declaring a key is the same
        act as documenting it.

        These are dispatched \e before the travel keys, so \c W, \c A, \c S
        and \c D are effectively reserved: claiming one wins, and the lab
        silently loses that pan direction. Pick another letter - it is why
        watching a thing sits on \c Q rather than \c W.
    */
    property var keys: []

    /*!
        \qmlproperty var LabKeys::scenarioNames
        \brief Names bound to \c 1..9; defaults to the lab's own scenario list.
    */
    property var scenarioNames: lab && lab.scenarios ? lab.scenarios() : []

    /*!
        \qmlproperty bool LabKeys::helpVisible
        \brief Toggled by \c ?, rendered by LabHelp.
    */
    property bool helpVisible: false

    /*!
        \qmlproperty bool LabKeys::viewKeys
        \brief Handle the arrow/zoom/frame keys.
    */
    property bool viewKeys: true

    /*!
        \qmlproperty real LabKeys::panStep
        \brief One arrow-key pan, as a fraction of the camera's distance.

        Relative rather than absolute so the same key press covers the same
        part of the picture at every zoom - a fixed step in world units either
        crawls when you are far out or throws you off the board when you are
        close in.
    */
    property real panStep: 0.14

    /*!
        \qmlproperty real LabKeys::orbitStep
        \brief Degrees of yaw per \c Shift+Left / \c Shift+Right.
    */
    property real orbitStep: 6

    /*!
        \qmlproperty bool LabKeys::scaleKeys
        \brief Handle \c Ctrl+Plus / \c Ctrl+Minus / \c Ctrl+0 for \l LabTheme::uiScale.

        On by default, so every lab that already has a keymap gained the text
        size control for free the day it landed.
    */
    property bool scaleKeys: true

    /*!
        \qmlproperty var LabKeys::frameAll
        \brief Called on \c 0; defaults to the lab's \c frameAll().
    */
    property var frameAll: lab && lab.frameAll ? lab.frameAll : null

    /*!
        \qmlproperty var LabKeys::frameSelection
        \brief Called on \c F; defaults to the lab's \c frameSelection().
    */
    property var frameSelection: lab && lab.frameSelection ? lab.frameSelection : null

    /*!
        \qmlproperty var LabKeys::entries
        \readonly
        \brief The complete map as \c {[{key, label}]} - reserved keys included.
    */
    readonly property var entries: {
        const out = []
        if (scenarioNames.length > 0)
            out.push({ key: "1-" + Math.min(9, scenarioNames.length),
                       label: "keys.scenarios" })
        for (const k of keys)
            if (!k.hidden) out.push({ key: k.key, label: k.label })
        if (flow) {
            out.push({ key: "T", label: "keys.flow" })
            out.push({ key: "␣", label: "keys.next" })
        }
        if (navKeys) out.push({ key: "␣", label: "keys.nav" })
        if (jump) out.push({ key: "f", label: "keys.jump" })
        if (selection) {
            out.push({ key: "jk", label: "keys.cardwalk" })
            out.push({ key: "hl", label: "keys.cardadjust" })
            out.push({ key: "⏎", label: "keys.operate" })
        }
        if (handKeys) {
            out.push({ key: handKey, label: "keys.hand" })
            out.push({ key: pinKey, label: "keys.pin" })
            out.push({ key: "⌫", label: "keys.unmeasure" })
        }
        if (viewKeys) {
            out.push({ key: "←↑↓→ / WASD", label: "keys.pan" })
            out.push({ key: "⇧←↑↓→", label: "keys.orbit" })
            out.push({ key: "+-", label: "keys.zoom" })
            out.push({ key: jump ? "⇧F" : "F", label: "keys.frame" })
            out.push({ key: "0", label: "keys.reset" })
            if (camera && camera.jumpBack)
                out.push({ key: "⌃O ⌃I", label: "keys.jumplist" })
        }
        if (scaleKeys) out.push({ key: "⌃+ ⌃− ⌃0", label: "keys.uiscale" })
        if (recorder) out.push({ key: "⇧R", label: "keys.record" })
        out.push({ key: "⇥", label: "keys.focus" })
        out.push({ key: "Esc", label: "keys.cancel" })
        out.push({ key: "?", label: "keys.help" })
        return out
    }

    /*!
        \qmlmethod string LabKeys::helpText()
        \brief One line describing the map, for a hint bar.
    */
    function helpText() {
        return entries.map(e => e.key + " " + LabLang.t(e.label)).join(" · ")
    }

    /*!
        \qmlmethod bool LabKeys::handle(var event)
        \brief Runs the key's action; returns true when the key was consumed.

        While a flow runs, \c Space / \c → advance it and \c ← steps back, so
        the narration reads the same in every lab. The lab's own keys keep
        working throughout: what a running flow takes is the board (see
        \l {Flow::control}), not the key map - the view, the text size, the
        help and the transport are the reader's at every moment. The one
        exception is the selected part's card, whose \c h / \c l / \b Enter
        go through \l selection and are refused for a part the flow has not
        lent out.
    */
    function handle(ev) {
        // --- the name prompt, before ANYTHING: while it is open the keyboard
        // is its own, and a name with a b or an h in it must not switch modes
        // underneath the typing. In the running lab the prompt holds focus and
        // these never arrive, which is exactly why the guard belongs here -
        // the one path that could deliver them is a lab that kept focus.
        if (handKeys && hands.pinning) return false

        // --- jump labels, right after it and for the same reason: while
        // they are up the letters ARE the input, and an 'h' in a label must
        // not pick up an instrument under the typing.
        if (jump && jump.active) return jump.handleKey(ev)

        // --- text size, BEFORE everything else: the bare +/-/0 keys are the
        // camera's, and a modifier is the only thing telling the two apart.
        // Accepts Meta as well as Control because Qt swaps the two on macOS,
        // where the natural chord is Cmd+Plus.
        if (scaleKeys && (ev.modifiers & (Qt.ControlModifier | Qt.MetaModifier))) {
            if (ev.key === Qt.Key_Plus || ev.key === Qt.Key_Equal) {
                LabTheme.stepScale(1); return true
            }
            if (ev.key === Qt.Key_Minus || ev.key === Qt.Key_Underscore) {
                LabTheme.stepScale(-1); return true
            }
            if (ev.key === Qt.Key_0) { LabTheme.resetScale(); return true }
        }

        // --- the view jumplist, on the same modifier (and Meta, for the
        // same macOS reason). Camera-side: OrbitCamera3D records every
        // deliberate jump; these two walk the record.
        if (camera && camera.jumpBack
            && (ev.modifiers & (Qt.ControlModifier | Qt.MetaModifier))) {
            if (ev.key === Qt.Key_O) {
                if (!camera.jumpBack()) _refuse("jump.endBack")
                return true
            }
            if (ev.key === Qt.Key_I) {
                if (!camera.jumpForward()) _refuse("jump.endFwd")
                return true
            }
        }

        // --- flow transport (only while one runs, so arrows stay the view's)
        if (flow && flow.running) {
            if (ev.key === Qt.Key_Space || ev.key === Qt.Key_Right) { flow.next(); return true }
            if (ev.key === Qt.Key_Left) { flow.prev(); return true }
            if (ev.key === Qt.Key_Escape) { flow.stop(); return true }
        }
        if (ev.key === Qt.Key_T && flow) {
            if (flow.running) flow.stop(); else flow.start()
            return true
        }

        // --- the view you can hold down
        // After the flow block on purpose: a running narration keeps Space.
        if (navKeys && ev.key === Qt.Key_Space) {
            pointer.springNav = true
            return true
        }

        // --- the selected part's card
        // Before the belt on purpose: while a part is selected, h belongs
        // to its card - the same nearest-context layering that gives Del to
        // a measurement while one is being taken. Esc clears the selection
        // and hands h back to the belt.
        if (selectionKeys) {
            const cl = _letterOf(ev)
            if (cl === "J") { selection.moveFocus(1); return true }
            if (cl === "K") { selection.moveFocus(-1); return true }
            if (cl === "H" || cl === "L") {
                if (!selection.adjust(cl === "H" ? -1 : 1)) _refuse("card.noAdjust")
                return true
            }
            if (ev.key === Qt.Key_Return || ev.key === Qt.Key_Enter) {
                if (!selection.operate()) _refuse("card.noOperate")
                return true
            }
        }

        // --- what is in the hand
        // Before the lab's own keys, like the editing keys below: an
        // instrument is the nearer context while one is out.
        if (handKeys) {
            if (_letterOf(ev) === handKey) { hands.cycle(); return true }
            if (_letterOf(ev) === pinKey && hands.held && hands.held.pinnable) {
                hands.beginPin(); return true
            }
        }

        // --- the measurement being taken, if one is
        // Before the lab's own keys on purpose: Del removes what a lab BUILT,
        // and while a tape measure is out there is nothing built under it -
        // so the same key can mean "one point fewer" without either lab
        // having to give its Del up.
        if (measureKeys) {
            if (ev.key === Qt.Key_Backspace || ev.key === Qt.Key_Delete) {
                hands.held.undo(); return true
            }
            // Esc empties the measurement first and the hand second: one key,
            // walked back one step at a time, which is what Esc means
            // everywhere else too.
            if (ev.key === Qt.Key_Escape && !helpVisible) {
                if (hands.held.count > 0) { hands.held.clear(); return true }
                hands.putAway(); return true
            }
        }

        // --- scenarios on the digits
        if (ev.key >= Qt.Key_1 && ev.key <= Qt.Key_9) {
            const i = ev.key - Qt.Key_1
            if (i < scenarioNames.length && lab && lab.applyScenario) {
                lab.applyScenario(scenarioNames[i])
                return true
            }
        }

        // --- the lab's own keys
        const letter = _letterOf(ev)
        if (letter !== "") {
            for (const k of keys) {
                if (k.key !== letter) continue
                // Shift+R is the recorder's, never a lab key's
                if (letter === "R" && (ev.modifiers & Qt.ShiftModifier)) break
                k.action()
                return true
            }
        }

        if (ev.key === Qt.Key_R && (ev.modifiers & Qt.ShiftModifier) && recorder) {
            recorder.recording = !recorder.recording
            return true
        }
        // Tab clears the HUD. Photoshop's key for the same act, and the one
        // letter-free key left in the reserved half - F was already framing
        // the selection. Accepting it is also what stops Qt walking the focus
        // chain, which is the other thing Tab does in a Quick scene.
        if (ev.key === Qt.Key_Backtab
            || (ev.key === Qt.Key_Tab && !(ev.modifiers & Qt.ControlModifier))) {
            LabView.toggleFocus()
            return true
        }
        if (ev.key === Qt.Key_Question
            || (ev.key === Qt.Key_Slash && (ev.modifiers & Qt.ShiftModifier))) {
            helpVisible = !helpVisible
            return true
        }
        if (ev.key === Qt.Key_Escape) {
            if (helpVisible) { helpVisible = false; return true }
            return false        // the lab clears its own selection/tool
        }

        if (!viewKeys) return false

        // The arrows TRAVEL. They used to turn the view, which is the one
        // thing a mouse drag already did well, while the thing a keyboard
        // user could not do at all - cross the scene - had no key at all.
        // Turning moved onto Shift, where it is still one hand's reach.
        const arrow = _arrow(ev)
        if (arrow !== null && camera) {
            if (ev.modifiers & Qt.ShiftModifier) {
                camera.orbitBy(arrow.x * orbitStep, -arrow.y * orbitStep * 0.66)
                return true
            }
            if (camera.panBy) {
                const step = (camera.goalDistance !== undefined
                              ? camera.goalDistance : camera.distance) * panStep
                camera.panBy(arrow.x * step, -arrow.y * step)
                return true
            }
            // a rig without the exploration layer keeps the old meaning
            camera.orbitBy(arrow.x * orbitStep, -arrow.y * orbitStep * 0.66)
            return true
        }

        if ((ev.key === Qt.Key_Plus || ev.key === Qt.Key_Equal) && camera) {
            camera.zoomBy(0.88); return true
        }
        if (ev.key === Qt.Key_Minus && camera) { camera.zoomBy(1.14); return true }
        if (ev.key === Qt.Key_F) {
            // f acquires, ⇧F frames - but only once a lab wires a jump; a
            // plain F in a jump-less lab keeps its old meaning, so the split
            // costs existing labs nothing.
            if (jump && !(ev.modifiers & Qt.ShiftModifier)) { jump.begin(); return true }
            if (frameSelection) { frameSelection(); return true }
        }
        if ((ev.key === Qt.Key_0 || ev.key === Qt.Key_Home) && frameAll) {
            frameAll(); return true
        }
        return false
    }

    /*!
        \qmlmethod bool LabKeys::handleRelease(var event)
        \brief The other half of the quasimode; call it from \c Keys.onReleased.

        Only Space needs it, and only while there is a \l pointer. Auto-repeat
        is ignored: a held key repeats as press-release pairs on some
        platforms, and taking those at face value makes the hand flicker.
    */
    function handleRelease(ev) {
        if (navKeys && ev.key === Qt.Key_Space && !ev.isAutoRepeat) {
            pointer.springNav = false
            return true
        }
        return false
    }

    /*!
        \qmlmethod void LabKeys::releaseSprings()
        \brief Drops any held-key mode. For when the lab stops being the one
        receiving keys.
    */
    function releaseSprings() {
        if (pointer) pointer.springNav = false
        // Jump labels die with the focus too: their release (the typed
        // letter) can no more arrive after a focus loss than Space's can.
        if (jump && jump.active) jump.cancel()
    }

    // The release of a held key never arrives if the lab lost focus while it
    // was down (a dialog, another window, a click into a panel), and a hand
    // tool stuck on is the worst possible end state: every drag moves the
    // scene and nothing says why.
    Connections {
        target: root.lab
        enabled: root.lab !== null && root.pointer !== null
        function onActiveFocusChanged() {
            if (!root.lab.activeFocus) root.releaseSprings()
        }
    }

    // Screen directions, +y being down as a screen counts: what both the pan
    // and the orbit branch above are expressed in.
    function _arrow(ev) {
        if (ev.key === Qt.Key_Left || ev.key === Qt.Key_A) return { x: -1, y: 0 }
        if (ev.key === Qt.Key_Right || ev.key === Qt.Key_D) return { x: 1, y: 0 }
        if (ev.key === Qt.Key_Up || ev.key === Qt.Key_W) return { x: 0, y: -1 }
        if (ev.key === Qt.Key_Down || ev.key === Qt.Key_S) return { x: 0, y: 1 }
        return null
    }

    // Key letters stay PHYSICAL across languages - a German keyboard must not
    // move the shortcuts - so the map is keyed on the key code, not on text().
    function _letterOf(ev) {
        if (ev.key >= Qt.Key_A && ev.key <= Qt.Key_Z)
            return String.fromCharCode("A".charCodeAt(0) + ev.key - Qt.Key_A)
        if (ev.key === Qt.Key_NumberSign) return "#"
        if (ev.key === Qt.Key_Delete || ev.key === Qt.Key_Backspace) return "Del"
        return ""
    }
}
