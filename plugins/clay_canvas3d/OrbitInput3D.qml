// (c) Clayground Contributors - MIT License, see "LICENSE" file

import QtQuick
import QtQuick3D

/*!
    \qmltype OrbitInput3D
    \inqmlmodule Clayground.Canvas3D
    \brief Turns drags, wheels and double-clicks into \l OrbitCamera3D moves,
    under one two-mode contract.

    The rig knows how to move; this knows what a gesture means. Split in two
    because the half that decides "left drag pans, right drag turns" is the
    half a scene wants to configure - while the arithmetic that turns pixels
    into degrees and metres is the same everywhere and was being re-derived,
    with different constants, in every scene that had a camera.

    \section2 Build and explore

    A scene that builds something has the same problem every editor has: the
    left button belongs to the tool, so the camera ends up on whatever buttons
    are left over, and no two scenes pick the same leftovers. The answer here
    is an explicit \l mode rather than a cleverer split of one pointer:

    \list
    \li \c "explore" - the whole pointer is the camera's. \b LMB drags the
        world along, \b RMB turns it \e about the point under the cursor
        (see \l {OrbitCamera3D::reanchor}{reanchor}), double-click focuses.
    \li \c "build" - LMB and RMB are the scene's, completely. Nothing is
        taken, and nothing has to be given back.
    \endlist

    \b {Universal in both modes}: the wheel zooms towards the cursor and the
    middle button drags the world. Nudging the view is never worth a mode
    switch, and neither gesture can collide with a tool that only has two
    buttons.

    Switching is spring-loaded: \l springExplore is explore \e while it is
    held (the hand-tool pattern - the scene feeds it a key), and \l mode is
    the sticky half. \l modeLocked is for a scene with nothing to build: it
    stays in explore and the chrome hides its mode control.

    \b {Non-visual, and deliberately not a MouseArea.} A scene that also picks
    or drags objects already owns the pointer; it keeps its own \c MouseArea
    and asks \l wants() what this press means before deciding it is its own:

    \qml
    OrbitInput3D { id: nav; rig: rig; view: view3d }

    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
        cursorShape: nav.cursorShape
        onPressed: (m) => {
            if (nav.begin(m.x, m.y, m.button, m.modifiers) !== "") return
            myTool.press(m.x, m.y)                    // build mode: it is yours
        }
        onPositionChanged: (m) => { if (!nav.move(m.x, m.y)) myTool.moveTo(m.x, m.y) }
        onReleased: nav.end()
        onWheel: (w) => nav.wheel(w.angleDelta.y, w.x, w.y)
        onDoubleClicked: (m) => nav.recenterAt(m.x, m.y)
    }
    \endqml

    \l begin returns the drag it took (\c "orbit", \c "pan" or \c "" when it
    declined), so the scene's own gesture is simply the \c "" case.

    \sa OrbitCamera3D
*/
Item {
    id: root

    visible: false

    /*! \qmlproperty var OrbitInput3D::rig \brief The \l OrbitCamera3D to drive. */
    property var rig: null

    /*!
        \qmlproperty var OrbitInput3D::view
        \brief The \c View3D the gestures happen in.

        Supplies the viewport height that scales a pan, and the ray that turns
        a cursor position into a world point - which is what anchors an orbit
        and what the wheel zooms towards.
    */
    property var view: null

    /*! \qmlproperty real OrbitInput3D::groundY \brief Height of the plane \l groundAt() hits. */
    property real groundY: 0

    // --- the mode ----------------------------------------------------------

    /*!
        \qmlproperty string OrbitInput3D::mode
        \brief \c "build" (the default) or \c "explore".

        The sticky half of the switch. \l springExplore overrides it while it
        is held, and \l effectiveMode is what actually decides a gesture.
    */
    property string mode: "build"

    /*!
        \qmlproperty bool OrbitInput3D::springExplore
        \brief Explore \e while this is true - the quasimode.

        The scene feeds it a held key (the labs use Space); the controller
        owns the state, so nothing else has to know what the mode currently
        is. A key that gets stuck - focus lost mid-hold - is the scene's to
        clear, by writing false.
    */
    property bool springExplore: false

    /*!
        \qmlproperty bool OrbitInput3D::modeLocked
        \brief The mode cannot be switched; \l toggleMode does nothing.

        For a scene with nothing to build, which is permanently in whatever
        \l mode says. Chrome reads this to hide a mode control that would
        never do anything.
    */
    property bool modeLocked: false

    /*! \qmlproperty string OrbitInput3D::effectiveMode \readonly \brief \l mode, or explore while \l springExplore. */
    readonly property string effectiveMode: springExplore ? "explore" : mode

    /*! \qmlproperty bool OrbitInput3D::exploring \readonly \brief \l effectiveMode is explore. */
    readonly property bool exploring: effectiveMode === "explore"

    /*! \qmlmethod void OrbitInput3D::toggleMode() \brief Switches build and explore. */
    function toggleMode() {
        if (modeLocked) return
        mode = (mode === "explore") ? "build" : "explore"
    }

    /*! \qmlmethod void OrbitInput3D::setMode(string m) \brief Sets the mode, unless \l modeLocked. */
    function setMode(m) {
        if (modeLocked) return
        if (m === "build" || m === "explore") mode = m
    }

    /*!
        \qmlproperty int OrbitInput3D::cursorShape
        \readonly
        \brief The cursor this mode should show; bind a MouseArea to it.

        An open hand while exploring, closed while a drag is running, and the
        plain arrow in build mode - the pointer itself says which mode you are
        in, before you press anything.
    */
    readonly property int cursorShape: !exploring ? Qt.ArrowCursor
                                     : (active ? Qt.ClosedHandCursor
                                               : Qt.OpenHandCursor)

    // --- what a gesture means ----------------------------------------------

    /*!
        \qmlproperty int OrbitInput3D::universalPanButtons
        \brief Buttons that drag the world in \e both modes.

        The middle button, which no two-button tool can claim.
    */
    property int universalPanButtons: Qt.MiddleButton

    /*!
        \qmlproperty int OrbitInput3D::orbitButtons
        \brief Buttons that turn the rig \e in explore mode.
    */
    property int orbitButtons: Qt.RightButton

    /*!
        \qmlproperty int OrbitInput3D::panButtons
        \brief Buttons that drag the world \e in explore mode.
    */
    property int panButtons: Qt.LeftButton | Qt.MiddleButton

    /*!
        \qmlproperty int OrbitInput3D::panModifiers
        \brief Modifiers that make any button pan, in either mode.

        Empty by default: build mode gives LMB and RMB to the scene
        \e completely, so a modifier-plus-drag would be exactly the kind of
        leftover the two modes exist to abolish. Set it (to
        \c Qt.ShiftModifier, say) in a scene whose domain leaves that modifier
        free and that wants the old escape hatch back.
    */
    property int panModifiers: Qt.NoModifier

    /*!
        \qmlproperty bool OrbitInput3D::anchorOrbit
        \brief An orbit turns about the point under the cursor at press.

        Needs a \l view and a rig with
        \l {OrbitCamera3D::reanchor}{reanchor}; without either it turns about
        the pivot as before.
    */
    property bool anchorOrbit: true

    /*!
        \qmlproperty bool OrbitInput3D::zoomToCursor
        \brief The wheel zooms towards the point under the cursor.

        Needs the cursor position - \c {nav.wheel(delta, w.x, w.y)}. Called
        with the delta alone it zooms towards the pivot, as it always did.
    */
    property bool zoomToCursor: true

    /*! \qmlproperty real OrbitInput3D::yawPerPixel \brief Degrees of yaw per pixel dragged. */
    property real yawPerPixel: 0.33

    /*! \qmlproperty real OrbitInput3D::pitchPerPixel \brief Degrees of pitch per pixel dragged. */
    property real pitchPerPixel: 0.24

    /*!
        \qmlproperty bool OrbitInput3D::invertPitch
        \brief Flip the vertical orbit direction.

        The default is grab-the-scene: dragging down tips the scene down, which
        raises the camera. Two of the three labs had worked that out
        independently; the third had it the other way, which is exactly the
        kind of drift a shared layer is for.
    */
    property bool invertPitch: false

    /*! \qmlproperty real OrbitInput3D::zoomStep \brief Distance factor for one wheel notch inwards. */
    property real zoomStep: 0.88

    /*! \qmlproperty real OrbitInput3D::panSpeed \brief Multiplier on the grab-the-ground pan. */
    property real panSpeed: 1.0

    // --- the glide out of a flick ------------------------------------------

    /*!
        \qmlproperty bool OrbitInput3D::flick
        \brief Let a fast drag coast for a moment after the button comes up.

        The rig's \c smoothMs already smooths each step; this is the other half
        of the feel - throwing the scene and watching it settle. It decays to a
        stop within about a third of a second and never moves further than the
        gesture was already moving.
    */
    property bool flick: true

    /*! \qmlproperty real OrbitInput3D::flickDecay \brief Velocity kept per frame while coasting. */
    property real flickDecay: 0.86

    /*! \qmlproperty real OrbitInput3D::flickThreshold \brief Pixels per frame a drag needs to coast at all. */
    property real flickThreshold: 2.0

    /*!
        \qmlproperty string OrbitInput3D::gesture
        \readonly
        \brief The drag in progress: \c "orbit", \c "pan" or \c "".

        Named \c gesture rather than \c mode since the modes arrived: \l mode
        is which half of the pointer the camera owns, this is what it is doing
        with it right now.
    */
    readonly property alias gesture: _s.gesture

    /*! \qmlproperty bool OrbitInput3D::active \readonly \brief A drag is in progress. */
    readonly property bool active: _s.gesture !== ""

    /*!
        \qmlproperty var OrbitInput3D::anchor
        \readonly
        \brief The world point this orbit is turning about, or null.

        Taken at press and held for the whole drag - including the coast out of
        a flick, so a thrown orbit keeps spinning about the same thing.
    */
    readonly property alias anchor: _s.anchor

    QtObject {
        id: _s
        property string gesture: ""
        property real lastX: 0
        property real lastY: 0
        property real vx: 0
        property real vy: 0
        property var anchor: null
    }

    /*!
        \qmlmethod string OrbitInput3D::wants(int button, int modifiers)
        \brief What this press would do, without doing it.

        \c "orbit", \c "pan" or \c "" - the question a scene asks before it
        decides whether the press is its own. In build mode the only yes is
        the middle button (and \l panModifiers, if a scene set one), which is
        what makes "LMB and RMB are yours" a rule rather than a promise.
    */
    function wants(button, modifiers) {
        const mods = modifiers === undefined ? 0 : modifiers
        if ((button & universalPanButtons) !== 0) return "pan"
        if (panModifiers !== Qt.NoModifier && (mods & panModifiers) !== 0) return "pan"
        if (!exploring) return ""
        if ((button & orbitButtons) !== 0) return "orbit"
        if ((button & panButtons) !== 0) return "pan"
        return ""
    }

    /*!
        \qmlmethod string OrbitInput3D::begin(real x, real y, int button, int modifiers)
        \brief Starts a navigation drag; returns the drag taken, \c "" if none.
    */
    function begin(x, y, button, modifiers) {
        return beginAs(wants(button, modifiers), x, y)
    }

    /*!
        \qmlmethod string OrbitInput3D::beginAs(string g, real x, real y)
        \brief Starts a drag the scene has chosen itself: \c "orbit" or \c "pan".

        For a scene whose own rule decides, so it does not have to fake a
        button to say so. An orbit started this way anchors at (\a x, \a y)
        exactly like one \l begin took.
    */
    function beginAs(g, x, y) {
        _coast.stop()
        _s.gesture = (g === "orbit" || g === "pan") ? g : ""
        _s.lastX = x; _s.lastY = y
        _s.vx = 0; _s.vy = 0
        _s.anchor = null
        // Two halves of the same gesture, and both are needed. reanchor moves
        // the pivot onto the view axis at the point's depth - invisible, and
        // it is what keeps the pivot near the anchor while the drag turns, so
        // the rig stays well behaved. The anchor itself is then what the turn
        // rotates about, which is what actually pins the point to the cursor.
        if (_s.gesture === "orbit" && anchorOrbit && rig) {
            _s.anchor = groundAt(x, y)
            if (rig.reanchor) rig.reanchor(_s.anchor)
        }
        return _s.gesture
    }

    /*!
        \qmlmethod bool OrbitInput3D::move(real x, real y)
        \brief Continues the drag; false when no navigation gesture is running.
    */
    function move(x, y) {
        if (_s.gesture === "" || !rig) return false
        const dx = x - _s.lastX, dy = y - _s.lastY
        _s.lastX = x; _s.lastY = y
        _s.vx = dx; _s.vy = dy
        _step(dx, dy)
        return true
    }

    /*! \qmlmethod void OrbitInput3D::end() \brief Ends the drag, coasting if it was a flick. */
    function end() {
        if (_s.gesture === "") return
        if (flick && Math.hypot(_s.vx, _s.vy) >= flickThreshold) _coast.start()
        else { _s.gesture = ""; _s.anchor = null }
    }

    /*! \qmlmethod void OrbitInput3D::cancel() \brief Ends the drag with no coast. */
    function cancel() {
        _coast.stop(); _s.gesture = ""; _s.anchor = null; _s.vx = 0; _s.vy = 0
    }

    /*!
        \qmlmethod void OrbitInput3D::wheel(real angleDelta, real x, real y)
        \brief One wheel event: zooms in on a positive \a angleDelta.

        Given the cursor position it zooms \e towards what is under it, which
        is how a wheel gets you somewhere instead of merely closer to the
        middle. Both modes, always - see \l zoomToCursor.
    */
    function wheel(angleDelta, x, y) {
        if (!rig) return
        const f = angleDelta > 0 ? zoomStep : 1 / zoomStep
        if (zoomToCursor && x !== undefined && y !== undefined && rig.zoomToward) {
            const w = groundAt(x, y)
            if (w) { rig.zoomToward(w, f); return }
        }
        rig.zoomBy(f)
    }

    /*!
        \qmlmethod var OrbitInput3D::groundAt(real x, real y)
        \brief The point on the \l groundY plane under viewport pixel (\a x, \a y).

        Null when the ray never gets there. Worked out from the ray rather than
        picked, so it answers for every pixel of the plane including the ones
        no geometry covers.
    */
    function groundAt(x, y) {
        if (!view || !view.camera) return null
        const a = view.mapTo3DScene(Qt.vector3d(x, y, 1))
        const b = view.mapTo3DScene(Qt.vector3d(x, y, 100))
        const dy = b.y - a.y
        if (Math.abs(dy) < 1e-9) return null
        const t = (groundY - a.y) / dy
        if (t < 0) return null
        return Qt.vector3d(a.x + (b.x - a.x) * t, groundY, a.z + (b.z - a.z) * t)
    }

    /*!
        \qmlmethod bool OrbitInput3D::recenterAt(real x, real y)
        \brief Travels the pivot to the ground point under (\a x, \a y).

        What a double-click on empty ground should do in either mode, and the
        one bit of click handling this layer offers: a single click belongs to
        the scene, which knows what is worth focusing - it calls
        \c rig.focusOn() itself.
    */
    function recenterAt(x, y) {
        const w = groundAt(x, y)
        if (!w || !rig) return false
        rig.focusOn(w)
        return true
    }

    function _step(dx, dy) {
        if (_s.gesture === "orbit") {
            const dYaw = dx * yawPerPixel
            const dPitch = (invertPitch ? dy : -dy) * pitchPerPixel
            if (_s.anchor && rig.orbitAround) rig.orbitAround(_s.anchor, dYaw, dPitch)
            else rig.orbitBy(dYaw, dPitch)
            return
        }
        // grab-the-ground: the point under the cursor stays under the cursor,
        // so the pivot moves opposite to the drag
        const wpp = rig.worldPerPixel(view ? view.height : root.height) * panSpeed
        rig.panBy(-dx * wpp, -dy * wpp)
    }

    // The coast. Sixteen milliseconds a step so it reads as motion rather than
    // as a second animation, and it stops itself - a coast that outlived the
    // next press would fight it.
    Timer {
        id: _coast
        interval: 16
        repeat: true
        onTriggered: {
            _s.vx *= root.flickDecay
            _s.vy *= root.flickDecay
            if (!root.rig || Math.hypot(_s.vx, _s.vy) < 0.35) {
                stop(); _s.gesture = ""; _s.anchor = null; _s.vx = 0; _s.vy = 0
                return
            }
            root._step(_s.vx, _s.vy)
        }
    }
}
