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
    (\c panBy / \c goalDistance - see \l {OrbitCamera3D}): \b arrows move
    across the scene, \b {Shift+arrows} turn it, \c + / \c - zoom, \c F frames
    the selection and \c 0 or \c Home frames everything. The arrows used to
    turn, which is what a drag already did; travelling was the thing a
    keyboard could not do at all. While a flow runs, \c → and \c ← belong to
    the flow, so the arrows are the camera's only when nothing is narrating.

    Non-visual: keep focus handling where it is and call \l handle() from the
    lab's own key handler.

    \qml
    Item {
        focus: true
        Keys.onPressed: (ev) => keymap.handle(ev)

        LabKeys {
            id: keymap
            lab: root
            camera: rig
            flow: introFlow
            recorder: recorder
            keys: [
                { key: "S", label: "key.simulate", action: () => root.toggleSim() },
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

    /*! \qmlproperty var LabKeys::camera \brief An OrbitCamera3D (or anything with orbitBy/zoomBy). */
    property var camera: null

    /*! \qmlproperty var LabKeys::flow \brief The lab's Flow, if it has one. */
    property var flow: null

    /*! \qmlproperty var LabKeys::recorder \brief A DataRecorder toggled by Shift+R. */
    property var recorder: null

    /*!
        \qmlproperty var LabKeys::keys
        \brief The lab's own keys: \c {[{key, label, action, hidden}]}.

        \c key is the printable letter (\c "S"), \c label a LabLang key
        describing it, \c action the function to run. Entries appear in
        \l entries and therefore in LabHelp, so declaring a key is the same
        act as documenting it.
    */
    property var keys: []

    /*!
        \qmlproperty var LabKeys::scenarioNames
        \brief Names bound to \c 1..9; defaults to the lab's own scenario list.
    */
    property var scenarioNames: lab && lab.scenarios ? lab.scenarios() : []

    /*! \qmlproperty bool LabKeys::helpVisible \brief Toggled by \c ?, rendered by LabHelp. */
    property bool helpVisible: false

    /*! \qmlproperty bool LabKeys::viewKeys \brief Handle the arrow/zoom/frame keys. */
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

    /*! \qmlproperty real LabKeys::orbitStep \brief Degrees of yaw per \c Shift+Left / \c Shift+Right. */
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
        if (viewKeys) {
            out.push({ key: "←↑↓→", label: "keys.pan" })
            out.push({ key: "⇧←↑↓→", label: "keys.orbit" })
            out.push({ key: "+-", label: "keys.zoom" })
            out.push({ key: "F", label: "keys.frame" })
            out.push({ key: "0", label: "keys.reset" })
        }
        if (scaleKeys) out.push({ key: "⌃+ ⌃− ⌃0", label: "keys.uiscale" })
        if (recorder) out.push({ key: "⇧R", label: "keys.record" })
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
        working throughout - a flow never locks the lab.
    */
    function handle(ev) {
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
        if (ev.key === Qt.Key_F && frameSelection) { frameSelection(); return true }
        if ((ev.key === Qt.Key_0 || ev.key === Qt.Key_Home) && frameAll) {
            frameAll(); return true
        }
        return false
    }

    // Screen directions, +y being down as a screen counts: what both the pan
    // and the orbit branch above are expressed in.
    function _arrow(ev) {
        if (ev.key === Qt.Key_Left) return { x: -1, y: 0 }
        if (ev.key === Qt.Key_Right) return { x: 1, y: 0 }
        if (ev.key === Qt.Key_Up) return { x: 0, y: -1 }
        if (ev.key === Qt.Key_Down) return { x: 0, y: 1 }
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
