// (c) Clayground Contributors - MIT License, see "LICENSE" file

import QtQuick
import QtQuick3D

/*!
    \qmltype OrbitInput3D
    \inqmlmodule Clayground.Canvas3D
    \brief Turns drags, wheels and double-clicks into \l OrbitCamera3D moves,
    under one mode contract.

    The rig knows how to move; this knows what a gesture means. Split in two
    because the half that decides "left drag pans, right drag turns" is the
    half a scene wants to configure - while the arithmetic that turns pixels
    into degrees and metres is the same everywhere and was being re-derived,
    with different constants, in every scene that had a camera.

    \section2 Two modes at most, and navigation is never one of them

    A scene that builds something has the same problem every editor has: the
    left button belongs to the tool, so the camera ends up on whatever buttons
    are left over, and no two scenes pick the same leftovers.

    The answer is \e not a mode per activity. There was briefly one mode for
    turning the view and another for measuring with it, and the shape of that
    mistake is visible the moment a third instrument is imagined: five modes
    for one camera. What a 3D shooter does instead is the model here - moving,
    aiming and firing are live at once, and the only thing you choose is what
    is in your hands.

    So navigation keeps its own inputs \e permanently, and exactly one input
    changes meaning:

    \list
    \li \c "use" - the camera's. \b LMB drags the world along, \b RMB turns it
        \e about the point under the cursor
        (\l {OrbitCamera3D::reanchor}{reanchor} at the press,
        \l {OrbitCamera3D::orbitAround}{orbitAround} for the turn itself),
        double-click focuses. When the scene has put something in the viewer's
        hand it sets \l picking, and then an LMB \e click - a press that
        travelled less than \l clickSlop - reports what it landed on through
        \l picked. Anything further is a pan: repositioning is wanted far more
        often than another point, and a stray point is the more annoying of
        the two mistakes.
    \li \c "build" - LMB and RMB are the scene's, completely. Nothing is
        taken, and nothing has to be given back. It stays a mode of its own
        because it changes what the scene \e affords - previews, snapping,
        delete - not merely what a click does.
    \endlist

    \b Universal: the wheel zooms towards the cursor and the middle button
    drags the world, in both modes. Nudging the view is never worth a mode
    switch, and neither gesture can collide with a tool that only has two
    buttons.

    Switching is spring-loaded: \l springNav navigates \e while it is held
    (the hand-tool pattern - the scene feeds it a key), and \l mode is the
    sticky half. \l modes is which modes a scene has at all, and \l modeLocked
    pins it to the one it is in. A scene with nothing to build declares
    \c {["use"]} and has no mode control at all.

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
        \brief \c "build" (the default) or \c "use".

        The sticky half of the switch. \l springNav overrides it while it is
        held, and \l effectiveMode is what actually decides a gesture.
    */
    property string mode: "build"

    /*!
        \qmlproperty bool OrbitInput3D::springNav
        \brief Navigate \e while this is true - the quasimode.

        The scene feeds it a held key (the labs use Space); the controller
        owns the state, so nothing else has to know what the mode currently
        is. A key that gets stuck - focus lost mid-hold - is the scene's to
        clear, by writing false.

        It suspends \l picking too: a borrowed camera is a look around, and a
        held key must not drop points.
    */
    property bool springNav: false

    /*!
        \qmlproperty var OrbitInput3D::modes
        \brief The modes this scene offers, in cycle order.

        A scene with nothing to build declares \c {["use"]} and thereby has no
        mode control at all; one that builds declares both. The one-mode case
        is simply a list of one - \c modes is what a scene declares, and every
        other rule here is derived from it.

        Order is the cycle order, so \l cycleMode reads off the declaration.
    */
    property var modes: ["build", "use"]

    /*!
        \qmlproperty bool OrbitInput3D::modeLocked
        \brief Pins the mode to the one it is in, whatever \l modes says.

        Kept for the scene that wants to freeze the current mode without
        rewriting its list - it collapses \l allowedModes to \c {[mode]}.
    */
    property bool modeLocked: false

    /*!
        \qmlproperty var OrbitInput3D::allowedModes
        \readonly
        \brief \l modes, or just the current one while \l modeLocked.
    */
    readonly property var allowedModes: modeLocked ? [mode] : modes

    /*!
        \qmlproperty bool OrbitInput3D::modeSwitchable
        \readonly
        \brief There is more than one mode to be in.

        What chrome reads to decide whether a mode control is worth showing -
        a chip that can only ever say one thing is noise.
    */
    readonly property bool modeSwitchable: allowedModes.length > 1

    /*! \qmlproperty string OrbitInput3D::effectiveMode \readonly \brief \l mode, or \c "use" while \l springNav. */
    readonly property string effectiveMode: springNav ? "use" : mode

    /*! \qmlproperty bool OrbitInput3D::navigating \readonly \brief \l effectiveMode is \c "use" - the camera has the pointer. */
    readonly property bool navigating: effectiveMode === "use"

    /*!
        \qmlproperty bool OrbitInput3D::picking
        \brief A short click means something to the scene right now.

        The scene's half of the contract, and the \e only thing that changes
        what an input means: with something in the viewer's hand the scene
        writes true, and a click that travelled no further than \l clickSlop
        comes out as \l picked instead of being nothing. Every navigation
        gesture is unaffected either way.

        Suspended while \l springNav is held - see \l picks.
    */
    property bool picking: false

    /*! \qmlproperty bool OrbitInput3D::picks \readonly \brief Clicks are being reported: \l picking, in a navigating mode, not sprung. */
    readonly property bool picks: picking && mode === "use" && !springNav

    /*! \qmlmethod bool OrbitInput3D::allows(string m) \brief \a m is in \l allowedModes. */
    function allows(m) { return allowedModes.indexOf(m) >= 0 }

    /*!
        \qmlmethod void OrbitInput3D::cycleMode()
        \brief Moves to the next of \l allowedModes, wrapping.

        A scene in a mode its list does not contain lands on the first one,
        which is what makes a list narrowed at runtime safe.
    */
    function cycleMode() {
        const a = allowedModes
        if (a.length === 0) return
        const i = a.indexOf(mode)
        // stranded - the list was narrowed under it - so come back in first
        if (i < 0) { mode = a[0]; return }
        if (a.length < 2) return
        mode = a[(i + 1) % a.length]
    }

    // A scene whose list does not contain the mode it is in is in no mode at
    // all: every gesture rule here derives from `modes`, so the one case that
    // must not exist is `modes: ["use"]` sitting on the default "build".
    onModesChanged: if (modes && modes.length > 0 && modes.indexOf(mode) < 0) mode = modes[0]

    /*!
        \qmlmethod void OrbitInput3D::toggleMode()
        \brief Alias of \l cycleMode, from when there were two modes.
    */
    function toggleMode() { cycleMode() }

    /*! \qmlmethod void OrbitInput3D::setMode(string m) \brief Sets the mode, if \l allows it. */
    function setMode(m) {
        if (allows(m)) mode = m
    }

    /*!
        \qmlproperty int OrbitInput3D::cursorShape
        \readonly
        \brief The cursor this mode should show; bind a MouseArea to it.

        An open hand for the camera, a crosshair when a click would land
        somewhere, closed while a drag is running, and the plain arrow in
        build mode - the pointer itself says what a press will do, before you
        press anything.
    */
    readonly property int cursorShape: active && navigating ? Qt.ClosedHandCursor
                                     : picks ? Qt.CrossCursor
                                     : navigating ? Qt.OpenHandCursor
                                     : Qt.ArrowCursor

    // --- what a gesture means ----------------------------------------------

    /*!
        \qmlproperty int OrbitInput3D::universalPanButtons
        \brief Buttons that drag the world in \e both modes.

        The middle button, which no two-button tool can claim.
    */
    property int universalPanButtons: Qt.MiddleButton

    /*!
        \qmlproperty int OrbitInput3D::orbitButtons
        \brief Buttons that turn the rig \e in a navigating mode.
    */
    property int orbitButtons: Qt.RightButton

    /*!
        \qmlproperty int OrbitInput3D::panButtons
        \brief Buttons that drag the world \e in a navigating mode.
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
        \qmlproperty int OrbitInput3D::pickButtons
        \brief Buttons whose \e click is reported while \l picking.
    */
    property int pickButtons: Qt.LeftButton

    /*!
        \qmlproperty real OrbitInput3D::clickSlop
        \brief Pixels a press may travel and still count as a click.

        The same click-versus-drag rule the labs apply to their own gestures,
        at the one place where the camera has to apply it too: while
        \l picking the same button both reports a point and pans, and only the
        distance travelled tells them apart. This is what makes "navigation is
        never taken away" true rather than aspirational.
    */
    property real clickSlop: 4

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
        // the pending click: what was under the press, and how far the press
        // has travelled since
        property var pickAt: null
        property real pressX: 0
        property real pressY: 0
        property real moved: 0
    }

    /*!
        \qmlmethod string OrbitInput3D::wants(int button, int modifiers)
        \brief What this press would do, without doing it.

        \c "orbit", \c "pan" or \c "" - the question a scene asks before it
        decides whether the press is its own. In build mode the only yes is
        the middle button (and \l panModifiers, if a scene set one), which is
        what makes "LMB and RMB are yours" a rule rather than a promise.

        \l picking does not change the answer: the click it is interested in
        is not visible until the button comes \e up, so the press is taken as
        a pan and \l end decides. That is the whole trick - a hand full or
        empty, the drag is identical.
    */
    function wants(button, modifiers) {
        const mods = modifiers === undefined ? 0 : modifiers
        if ((button & universalPanButtons) !== 0) return "pan"
        if (panModifiers !== Qt.NoModifier && (mods & panModifiers) !== 0) return "pan"
        if (!navigating) return ""
        if ((button & orbitButtons) !== 0) return "orbit"
        if ((button & panButtons) !== 0) return "pan"
        return ""
    }

    /*!
        \qmlmethod string OrbitInput3D::begin(real x, real y, int button, int modifiers)
        \brief Starts a navigation drag; returns the drag taken, \c "" if none.
    */
    function begin(x, y, button, modifiers) {
        const g = beginAs(wants(button, modifiers), x, y)
        // The pick is taken HERE, not at release: the same press pans, so by
        // the time the button comes up the ground under those pixels is no
        // longer the ground that was pressed on - and the object under them
        // may have driven off.
        if (picks && g === "pan" && (button & pickButtons) !== 0) {
            _s.pressX = x; _s.pressY = y; _s.moved = 0
            _s.pickAt = pickAt(x, y)
        }
        return g
    }

    /*!
        \qmlmethod var OrbitInput3D::pickAt(real x, real y)
        \brief What is under viewport pixel (\a x, \a y): a place \e and a thing.

        \c {{ point, object, x, y }}. \c point is where the ray meets the
        \l groundY plane, worked out analytically so it answers for every
        pixel of the plane including the ones no geometry covers; \c object is
        the scene node the same ray hits first, or null.

        Both, from one gesture, because instruments want different halves of
        it: a tape measure asks where, a voltmeter asks what. Reporting them
        together is what keeps adding an instrument from adding an input path.
        Null only when there is no view to ask.
    */
    function pickAt(x, y) {
        if (!view) return null
        var hit = null
        // guarded: the suites drive this with a fake view that has no picking,
        // and a scene may legitimately not want the cost
        if (pickObjects && typeof view.pick === "function") {
            const r = view.pick(x, y)
            if (r && r.objectHit) hit = r.objectHit
        }
        return { point: groundAt(x, y), object: hit, x: x, y: y }
    }

    /*!
        \qmlproperty bool OrbitInput3D::pickObjects
        \brief Ask the view what object a pick landed on, as well as where.

        On by default; a scene whose instruments only ever want the ground can
        turn the ray-cast off.
    */
    property bool pickObjects: true

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
        _s.pickAt = null; _s.moved = 0
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
        // distance FROM THE PRESS, not path length: a drag that wanders out
        // and comes back is still a drag, and a hand that trembles is not
        if (_s.pickAt !== null)
            _s.moved = Math.max(_s.moved, Math.hypot(x - _s.pressX, y - _s.pressY))
        _step(dx, dy)
        return true
    }

    /*!
        \qmlmethod void OrbitInput3D::end()
        \brief Ends the drag, coasting if it was a flick.

        Also where a click is decided: a press that never travelled further
        than \l clickSlop was not a pan at all, and comes out as \l picked
        instead - with no coast, since nothing was thrown.
    */
    function end() {
        if (_s.gesture === "") return
        if (_s.pickAt !== null && _s.moved <= clickSlop) {
            const p = _s.pickAt
            cancel()
            picked(p)
            return
        }
        _s.pickAt = null
        if (flick && Math.hypot(_s.vx, _s.vy) >= flickThreshold) _coast.start()
        else { _s.gesture = ""; _s.anchor = null }
    }

    /*! \qmlmethod void OrbitInput3D::cancel() \brief Ends the drag with no coast. */
    function cancel() {
        _coast.stop(); _s.gesture = ""; _s.anchor = null; _s.vx = 0; _s.vy = 0
        _s.pickAt = null; _s.moved = 0
    }

    /*!
        \qmlsignal OrbitInput3D::picked(var pick)
        \brief A click landed, while something was in the viewer's hand.

        \a pick is \l pickAt's \c {{ point, object, x, y }}. The one click this
        layer reports, and only while \l picks: everywhere else a single click
        belongs to the scene. Never emitted for a press that panned.

        \c {pick.point} is null where the ray missed the ground plane, which
        an instrument that measures places must check - the pick still
        arrives, because the object half may be exactly what was wanted.
    */
    signal picked(var pick)

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
            if (w) { rig.zoomToward(w, f); zoomedAt(w); return }
        }
        rig.zoomBy(f)
    }

    /*!
        \qmlsignal OrbitInput3D::zoomedAt(var point)
        \brief A cursor-anchored zoom just aimed at \a point (ground plane).

        What a marker listens to - the anchored orbit is readable from
        \l anchor and \l gesture, but a wheel tick is over in one call, so
        showing where it aimed needs this pulse.
    */
    signal zoomedAt(var point)

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
        // so the pivot moves opposite to the drag IN SCREEN SPACE. The two
        // axes need opposite signs because panBy's frame is (right, away)
        // while a pointer's dy grows downward: screen-opposite is -dx on the
        // right axis but +dy on the away axis. One minus too many here and
        // the ground follows the hand left-right yet fights it up-down.
        const wpp = rig.worldPerPixel(view ? view.height : root.height) * panSpeed
        rig.panBy(-dx * wpp, dy * wpp)
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
