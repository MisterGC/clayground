// (c) Clayground Contributors - MIT License, see "LICENSE" file

pragma ComponentBehavior: Bound

import QtQuick

/*!
    \qmltype HintJump
    \inqmlmodule Clayground.Lab
    \brief Keyboard selection: label every target, type the label.

    Press \c f (LabKeys routes it here) and every target the lab names grows
    a short label - one or two characters, home-row first, so the common case
    is a single keystroke on a strong finger. Typing the label selects the
    target exactly as a click would, and the camera does not move; framing
    stays a separate, deliberate act. Off-screen targets appear as a grouped
    badge strip at the bottom edge, and choosing one of those \e does fly to
    it - the one sanctioned exception, because selecting what you cannot see
    helps nobody.

    A hint label is sized for reading, not for the object's pixel footprint,
    which is why the same mechanism also retires the tiny-hit-region class of
    bug: a switch lever a few pixels wide costs the same two keystrokes as a
    board-filling part.

    The mechanism is the kernel's; the vocabulary is the lab's: \l targets
    returns what can be jumped to, with a display name and a group per entry.
    Place the item as a \e sibling of the View3D, filling the same area, and
    hand it to \l LabKeys via its \c jump property - the keymap starts it,
    routes keys while it is up, and documents it in the help.

    While labels are up the keyboard is this component's (a text-entry
    context, like the pin prompt - not a mode): letters refine, the matching
    label selects, anything else puts the labels away.

    \sa LabKeys, SelectionFrame3D, WorldLabel
*/
Item {
    id: root

    /*!
        \qmlproperty var HintJump::view
        \brief The View3D to project through.

        \c var, not \c View3D, for the same reason as \l WorldLabel: the
        kernel should not need a 3D dependency to draw a paper chip.
    */
    property var view: null

    /*!
        \qmlproperty var HintJump::camera
        \brief The camera the View3D renders with (projection dependency).
    */
    property var camera: null

    /*!
        \qmlproperty var HintJump::rig
        \brief An OrbitCamera3D; only \c focusOn is used, and only for
        off-screen targets (select-and-fly).
    */
    property var rig: null

    /*!
        \qmlproperty var HintJump::targets
        \brief \c {() => [{id, pos, name, group}]} - what can be jumped to.

        \c pos is a world-space vector3d (label anchor and fly-to point),
        \c name the display label beside the letter, \c group the badge-strip
        grouping for off-screen entries (a net, a road - the part type when a
        kit has nothing better). The list is asked for fresh on every \l
        begin, so it always reflects the scene.
    */
    property var targets: null

    /*!
        \qmlproperty int HintJump::maxBadges
        \brief Off-screen entries shown before the strip says "+N".
    */
    property int maxBadges: 10

    /*!
        \qmlproperty bool HintJump::active
        \readonly
        \brief Labels are up and the keyboard is this component's.
    */
    readonly property bool active: _active

    /*!
        \qmlsignal HintJump::selected(var target)
        \brief A label was typed to the end; \c target is the lab's own entry.

        Selection is the lab's act - the component neither knows nor sets
        what "selected" means in the scene.
    */
    signal selected(var target)

    property bool _active: false
    property var _entries: []          // [{label, target, offscreen}]
    property string _prefix: ""
    property bool _twoLetter: false

    // grafli's alphabet, verbatim: home row first, then the reachable rest.
    readonly property string _alphabet: "asdfjklghqweruioptyzxcvbnm"

    anchors.fill: parent

    /*!
        \qmlmethod bool HintJump::begin()
        \brief Puts the labels up; a second call puts them away.

        Returns false - after showing a short "nothing to jump to" notice -
        when the lab has no targets, so a caller never has to distinguish
        the two.
    */
    function begin() {
        if (_active) { cancel(); return true }
        const list = root.targets ? root.targets() : []
        if (!list || list.length === 0) {
            _toast.show()
            return false
        }

        // Split by where the anchor lands NOW; the split stays fixed while
        // the labels are up (typing takes well under a second - reprojecting
        // the visible/off-screen decision mid-typing would move labels
        // between chip and badge under the reader's eyes).
        const visible = [], off = []
        const w = root.width, h = root.height
        const cx = w / 2, cy = h / 2
        for (const t of list) {
            const p = root._project(t.pos)
            if (p.z > 0 && p.x >= 0 && p.x <= w && p.y >= 0 && p.y <= h)
                visible.push(t)
            else
                off.push({ t: t, d: (p.x - cx) * (p.x - cx) + (p.y - cy) * (p.y - cy) })
        }
        off.sort((a, b) => a.d - b.d)

        const all = visible.concat(off.map(o => o.t))
        const n = all.length
        const keys = _alphabet
        _twoLetter = n > keys.length
        const out = []
        for (let i = 0; i < n; ++i) {
            const label = _twoLetter
                ? keys[Math.floor(i / keys.length) % keys.length] + keys[i % keys.length]
                : keys[i]
            out.push({ label: label, target: all[i], offscreen: i >= visible.length })
        }
        _entries = out
        _prefix = ""
        _active = true
        return true
    }

    /*!
        \qmlmethod bool HintJump::handleKey(var event)
        \brief Every key while active; LabKeys routes them here.
    */
    function handleKey(ev) {
        if (!_active) return false
        if (ev.isAutoRepeat) return true
        if (ev.key === Qt.Key_Escape) { cancel(); return true }

        // Physical letters, like the keymap itself: a German keyboard must
        // not move the labels.
        if (ev.key < Qt.Key_A || ev.key > Qt.Key_Z) { cancel(); return true }
        const letter = String.fromCharCode("a".charCodeAt(0) + ev.key - Qt.Key_A)
        _prefix += letter

        const hit = _entries.find(e => e.label === _prefix)
        if (hit) { _select(hit); return true }

        if (!_entries.some(e => e.label.startsWith(_prefix))) {
            cancel()
            return true
        }
        // Refinement: drop what no longer matches; the delegates render the
        // label with the typed prefix stripped, so what you see is always
        // exactly what is left to type.
        _entries = _entries.filter(e => e.label.startsWith(_prefix))
        return true
    }

    /*!
        \qmlmethod void HintJump::cancel()
        \brief Puts the labels away without selecting.
    */
    function cancel() {
        _active = false
        _entries = []
        _prefix = ""
    }

    function _select(e) {
        const flew = e.offscreen
        const t = e.target
        cancel()
        root.selected(t)
        // Select-and-fly, off-screen only: the sanctioned exception to
        // no-auto-frame. focusOn re-centres without diving (and, with the
        // jumplist, records the view being left).
        if (flew && root.rig && root.rig.focusOn)
            root.rig.focusOn(t.pos, 1.4)
    }

    function _project(pos) {
        if (!root.view || !root.camera) return Qt.vector3d(0, 0, -1)
        // Same explicit dependencies as WorldLabel, same reason: the
        // projection reads all four without naming them.
        root.camera.scenePosition
        root.camera.sceneRotation
        root.view.width
        root.view.height
        return root.view.mapFrom3DScene(pos)
    }

    // --- visible chips ----------------------------------------------------
    Repeater {
        model: root._active ? root._entries.filter(e => !e.offscreen) : []
        delegate: Rectangle {
            id: chip
            required property var modelData
            readonly property vector3d _p: root._project(chip.modelData.target.pos)
            visible: _p.z > 0
            x: _p.x - width / 2
            y: _p.y - height / 2
            width: _row.width + LabTheme.px(12)
            height: _row.height + LabTheme.px(8)
            radius: LabTheme.radius
            color: LabTheme.ink
            z: 100
            Row {
                id: _row
                anchors.centerIn: parent
                spacing: LabTheme.px(5)
                Text {
                    text: chip.modelData.label.substring(root._prefix.length)
                    color: LabTheme.inkOn(LabTheme.ink)
                    font.pixelSize: LabTheme.fontBody
                    font.bold: true
                    font.family: LabTheme.monoFont
                }
                Text {
                    text: chip.modelData.target.name || ""
                    visible: text !== ""
                    color: LabTheme.inkOn(LabTheme.ink)
                    opacity: 0.75
                    font.pixelSize: LabTheme.fontSmall
                    font.family: LabTheme.monoFont
                    anchors.verticalCenter: parent.verticalCenter
                }
            }
        }
    }

    // --- off-screen badge strip -------------------------------------------
    Rectangle {
        id: _badges
        visible: root._active && _badgeText.text !== ""
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: LabTheme.px(64)   // above the hint bar's ground
        width: Math.min(_badgeText.implicitWidth + LabTheme.spaceL * 2,
                        parent.width - LabTheme.spaceXxl * 2)
        height: _badgeText.implicitHeight + LabTheme.spaceM
        radius: LabTheme.radius
        color: LabTheme.ink
        opacity: 0.92
        z: 100
        Text {
            id: _badgeText
            anchors.centerIn: parent
            width: parent.width - LabTheme.spaceL * 2
            elide: Text.ElideRight
            maximumLineCount: 1
            color: LabTheme.inkOn(LabTheme.ink)
            font.pixelSize: LabTheme.fontSmall
            font.family: LabTheme.monoFont
            text: {
                if (!root._active) return ""
                const off = root._entries.filter(e => e.offscreen)
                if (off.length === 0) return ""
                // Group by the kit's key; entries read "[a] R2", groups read
                // "net A: [a] R2  [s] R3", the tail past maxBadges reads +N.
                const groups = {}
                const order = []
                for (const e of off) {
                    const g = e.target.group || ""
                    if (!(g in groups)) { groups[g] = []; order.push(g) }
                    groups[g].push(e)
                }
                const parts = []
                let shown = 0
                for (const g of order) {
                    if (shown >= root.maxBadges) break
                    const items = []
                    for (const e of groups[g]) {
                        if (shown >= root.maxBadges) break
                        const rest = e.label.substring(root._prefix.length)
                        items.push("[" + rest + "] " + (e.target.name || ""))
                        ++shown
                    }
                    parts.push(g !== "" ? g + ": " + items.join("  ") : items.join("  "))
                }
                const total = off.length
                return parts.join("  |  ") + (total > shown ? "  …+" + (total - shown) : "")
            }
        }
    }

    // --- "nothing to jump to" ---------------------------------------------
    Rectangle {
        id: _toast
        function show() { opacity = 0.92; _toastTimer.restart() }
        visible: opacity > 0
        opacity: 0
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: LabTheme.px(64)
        width: _toastText.implicitWidth + LabTheme.spaceL * 2
        height: _toastText.implicitHeight + LabTheme.spaceM
        radius: LabTheme.radius
        color: LabTheme.ink
        z: 100
        Behavior on opacity { NumberAnimation { duration: 160 } }
        Text {
            id: _toastText
            anchors.centerIn: parent
            text: LabLang.t("jump.none")
            color: LabTheme.inkOn(LabTheme.ink)
            font.pixelSize: LabTheme.fontSmall
            font.family: LabTheme.monoFont
        }
        Timer { id: _toastTimer; interval: 1600; onTriggered: _toast.opacity = 0 }
    }
}
