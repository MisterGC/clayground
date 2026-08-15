// (c) Clayground Contributors - MIT License, see "LICENSE" file

import QtQuick
import QtQuick3D

/*!
    \qmltype OrbitInput3D
    \inqmlmodule Clayground.Canvas3D
    \brief Turns drags, wheels and double-clicks into \l OrbitCamera3D moves,
    under one rule: the left button is never the camera's.

    The rig knows how to move; this knows what a gesture means. Split in two
    because the half that decides "right drag turns, middle drag pans" is the
    half a scene wants to configure - while the arithmetic that turns pixels
    into degrees and metres is the same everywhere and was being re-derived,
    with different constants, in every scene that had a camera.

    \section2 There are no modes

    There were, twice. First a mode per activity - one for turning the view,
    one for measuring with it - which fails the moment a third instrument is
    imagined: five modes for one camera. Then two modes, build and use, which
    held up better and was still wrong, and for a reason worth writing down:
    \b {a mode existed only because the camera wanted the left button}. LMB-drag
    panned, so a scene that needed LMB had to be able to take it back, and the
    thing that took it back was the mode. Every symptom followed from that -
    two keys negotiating over one pointer, a switch on a circuit board that
    could not be flipped because the camera swallowed the press, a measurement
    destroyed by looking around.

    An RTS has none of these problems, and not because it is cleverer: it
    never puts panning on the left button. So neither does this.

    \list
    \li \b LMB - \e always the scene's. This layer declines it, whatever is
        happening, so a tool can never be starved of it. A scene may spend it
        on the view deliberately (see \l panButtons) - one decision, made once,
        by a scene that has nothing to select.
    \li \b RMB - drag turns the view \e about the point under the cursor
        (\l {OrbitCamera3D::reanchor}{reanchor} at the press,
        \l {OrbitCamera3D::orbitAround}{orbitAround} for the turn itself). A
        right \e click - a press that travelled no further than \l clickSlop -
        is \l cancelled instead, which is the RTS "put it down".
    \li \b MMB, \b wheel, \b double-click - pan, zoom towards the cursor,
        focus. Always live, and now the guaranteed path rather than the
        leftovers.
    \li \b {\l springNav} - while it is held (the scene feeds it a key; the
        labs use Space) the left button pans too. Muscle memory, kept as a
        quasimode because a held key cannot be forgotten in the way a mode can.
    \endlist

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
            myTool.press(m.x, m.y)                    // the left button is yours
        }
        onPositionChanged: (m) => {
            if (nav.move(m.x, m.y)) return
            if (!pressed) nav.hoverAt(m.x, m.y)
            myTool.moveTo(m.x, m.y)
        }
        onReleased: { nav.end(); myTool.release() }
        onWheel: (w) => nav.wheel(w.angleDelta.y, w.x, w.y)
        onDoubleClicked: (m) => nav.recenterAt(m.x, m.y)
    }
    \endqml

    \l begin returns the drag it took (\c "orbit", \c "pan" or \c "" when it
    declined), so the scene's own gesture is simply the \c "" case - and with
    the default buttons an LMB press is \e always that case.

    \section2 What is under the cursor

    \l pickAt() answers "a place and a thing" for any pixel, and \l hovering
    keeps the same answer for wherever the cursor last was. Neither is a
    decision: this layer no longer has an opinion about what a click means,
    because the scene does. A tool asks when it wants to know.

    \sa OrbitCamera3D
*/
Item {
    id: root

    visible: false

    /*!
        \qmlproperty var OrbitInput3D::rig
        \brief The \l OrbitCamera3D to drive.
    */
    property var rig: null

    /*!
        \qmlproperty var OrbitInput3D::view
        \brief The \c View3D the gestures happen in.

        Supplies the viewport height that scales a pan, and the ray that turns
        a cursor position into a world point - which is what anchors an orbit
        and what the wheel zooms towards.
    */
    property var view: null

    /*!
        \qmlproperty real OrbitInput3D::groundY
        \brief Height of the plane \l groundAt() hits.
    */
    property real groundY: 0

    // --- the one quasimode --------------------------------------------------

    /*!
        \qmlproperty bool OrbitInput3D::springNav
        \brief Pan on the left button too, \e while this is true.

        The scene feeds it a held key (the labs use Space). It is the only
        state in this layer that changes what an input means, and it is a
        quasimode rather than a mode for the reason quasimodes exist: a key
        you are holding down cannot be forgotten about, so nothing else has to
        display it and no tool can be left starved by it.

        A key that gets stuck - focus lost mid-hold - is the scene's to clear,
        by writing false.
    */
    property bool springNav: false

    /*!
        \qmlproperty int OrbitInput3D::cursorShape
        \readonly
        \brief Closed hand while a drag runs, plain arrow otherwise.

        Deliberately almost nothing. With no modes there is no camera state
        left for a cursor to announce, and what a press \e will do is now the
        scene's business - it knows what is in the hand, and it owns the
        cursor while it matters. Bind a MouseArea to this and override it
        where the scene has something to say.
    */
    readonly property int cursorShape: active ? Qt.ClosedHandCursor
                                              : Qt.ArrowCursor

    // --- what a gesture means ----------------------------------------------

    /*!
        \qmlproperty int OrbitInput3D::universalPanButtons
        \brief Buttons that always drag the world.

        The middle button, which no two-button tool can claim.
    */
    property int universalPanButtons: Qt.MiddleButton

    /*!
        \qmlproperty int OrbitInput3D::orbitButtons
        \brief Buttons that turn the rig.
    */
    property int orbitButtons: Qt.RightButton

    /*!
        \qmlproperty int OrbitInput3D::panButtons
        \brief Buttons that drag the world.

        The middle button alone, and that default is the whole design: adding
        \c Qt.LeftButton here is how a scene \e deliberately spends the left
        button on the view. A scene with nothing to select (a scene that only
        looks at something) should - left-drag panning is the most natural
        gesture there is, and it costs that scene nothing. A scene with a tool
        must not, and this layer will not do it behind its back.
    */
    property int panButtons: Qt.MiddleButton

    /*!
        \qmlproperty int OrbitInput3D::panModifiers
        \brief Modifiers that make any button pan.

        Empty by default: the left button is the scene's, so a
        modifier-plus-drag would be exactly the kind of leftover this layer
        exists to abolish. Set it (to \c Qt.ShiftModifier, say) in a scene
        whose domain leaves that modifier free and that wants the escape hatch
        anyway.
    */
    property int panModifiers: Qt.NoModifier

    /*!
        \qmlproperty real OrbitInput3D::clickSlop
        \brief Pixels a press may travel and still count as a click.

        One button applies it here - the right one, which both turns the view
        and, unmoved, \l cancelled. Only the distance travelled tells the two
        apart. Scenes apply the same rule to their own gestures with the same
        default, so a click means the same thing everywhere.
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

    /*!
        \qmlproperty real OrbitInput3D::yawPerPixel
        \brief Degrees of yaw per pixel dragged.
    */
    property real yawPerPixel: 0.33

    /*!
        \qmlproperty real OrbitInput3D::pitchPerPixel
        \brief Degrees of pitch per pixel dragged.
    */
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

    /*!
        \qmlproperty real OrbitInput3D::zoomStep
        \brief Distance factor for one wheel notch inwards.
    */
    property real zoomStep: 0.88

    /*!
        \qmlproperty real OrbitInput3D::panSpeed
        \brief Multiplier on the grab-the-ground pan.
    */
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

    /*!
        \qmlproperty real OrbitInput3D::flickDecay
        \brief Velocity kept per frame while coasting.
    */
    property real flickDecay: 0.86

    /*!
        \qmlproperty real OrbitInput3D::flickThreshold
        \brief Pixels per frame a drag needs to coast at all.
    */
    property real flickThreshold: 2.0

    /*!
        \qmlproperty string OrbitInput3D::gesture
        \readonly
        \brief The drag in progress: \c "orbit", \c "pan" or \c "".

        The only state this layer keeps about the pointer, and it lasts
        exactly as long as a button is down (plus the coast out of a flick).
    */
    readonly property alias gesture: _s.gesture

    /*!
        \qmlproperty bool OrbitInput3D::active
        \readonly
        \brief A drag is in progress.
    */
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
        // the pending cancel: a right press is one until it travels
        property bool arming: false
        property real pressX: 0
        property real pressY: 0
        property real moved: 0
    }

    /*!
        \qmlmethod string OrbitInput3D::wants(int button, int modifiers)
        \brief What this press would do, without doing it.

        \c "orbit", \c "pan" or \c "" - the question a scene asks before it
        decides whether the press is its own. Nothing this layer holds can
        change the answer for the left button: with the default
        \l panButtons it is \c "", now and in every state, which is what makes
        "the left button is yours" a rule rather than a promise.

        The order is the rule, read top to bottom: the middle button always
        pans; \l panModifiers pan if a scene declared them; the right button
        turns; and the left pans only where a scene asked for it in
        \l panButtons, or while \l springNav is held.
    */
    function wants(button, modifiers) {
        const mods = modifiers === undefined ? 0 : modifiers
        if ((button & universalPanButtons) !== 0) return "pan"
        if (panModifiers !== Qt.NoModifier && (mods & panModifiers) !== 0) return "pan"
        if ((button & orbitButtons) !== 0) return "orbit"
        if ((button & panButtons) !== 0) return "pan"
        // Space held: the view is borrowed, and only for as long as it is.
        if (springNav && (button & Qt.LeftButton) !== 0) return "pan"
        return ""
    }

    /*!
        \qmlmethod string OrbitInput3D::begin(real x, real y, int button, int modifiers)
        \brief Starts a navigation drag; returns the drag taken, \c "" if none.

        A right press that this took is armed as a possible \l cancelled: it
        cannot be known which it is until the button comes up, so it starts as
        an orbit and \l end decides. That is the whole trick - the drag is
        identical either way.
    */
    function begin(x, y, button, modifiers) {
        const g = beginAs(wants(button, modifiers), x, y)
        if (g !== "" && (button & Qt.RightButton) !== 0) {
            _s.pressX = x; _s.pressY = y; _s.moved = 0; _s.arming = true
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

        A plain query, and nothing here calls it: this layer has no opinion
        about what a click means, so the scene asks when it wants to know -
        at a press it decided was its own, or on a move through \l hoverAt.
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
        \qmlproperty var OrbitInput3D::hovering
        \brief What was under the cursor at the last \l hoverAt, or null.

        The same \c {{ point, object, x, y }} a \l pickAt returns, which is
        the point of it: a tool's two jobs - "what would happen here" and
        "make it happen" - read the same payload, so a preview and the act it
        previews cannot disagree.
    */
    property var hovering: null

    /*!
        \qmlmethod var OrbitInput3D::hoverAt(real x, real y)
        \brief Recomputes \l hovering for viewport pixel (\a x, \a y).

        Does nothing while a gesture is running: mid-drag the cursor is
        driving the camera rather than pointing at anything, and a preview
        that chased it would flicker across the whole scene. The scene calls
        this from its move handler when no button is down.
    */
    function hoverAt(x, y) {
        if (_s.gesture !== "") return hovering
        hovering = pickAt(x, y)
        return hovering
    }

    /*!
        \qmlmethod void OrbitInput3D::clearHover()
        \brief Forgets \l hovering - the cursor left.
    */
    function clearHover() { hovering = null }

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
        // The hand has the pose now, so it must not glide: see
        // OrbitCamera3D::gripped. Taken before the first step, dropped when
        // the coast stops, so a thrown scene is direct all the way down.
        if (rig && rig.gripped !== undefined) rig.gripped = _s.gesture !== ""
        _s.lastX = x; _s.lastY = y
        _s.vx = 0; _s.vy = 0
        _s.anchor = null
        _s.arming = false; _s.moved = 0
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
        if (_s.arming)
            _s.moved = Math.max(_s.moved, Math.hypot(x - _s.pressX, y - _s.pressY))
        _step(dx, dy)
        return true
    }

    /*!
        \qmlmethod void OrbitInput3D::end()
        \brief Ends the drag, coasting if it was a flick.

        Also where a right click is decided: a right press that never
        travelled further than \l clickSlop was not a turn at all, and comes
        out as \l cancelled instead - with no coast, since nothing was thrown.
    */
    function end() {
        if (_s.gesture === "") return
        if (_s.arming && _s.moved <= clickSlop) {
            cancel()
            cancelled()
            return
        }
        _s.arming = false
        if (flick && Math.hypot(_s.vx, _s.vy) >= flickThreshold) _coast.start()
        else { _s.gesture = ""; _s.anchor = null; _release() }
    }

    /*!
        \qmlmethod void OrbitInput3D::cancel()
        \brief Ends the drag with no coast.
    */
    function cancel() {
        _coast.stop(); _s.gesture = ""; _s.anchor = null; _s.vx = 0; _s.vy = 0
        _s.arming = false; _s.moved = 0
        _release()
    }

    // The rig glides again once no hand is on it.
    function _release() {
        if (rig && rig.gripped !== undefined) rig.gripped = false
    }

    /*!
        \qmlsignal OrbitInput3D::cancelled()
        \brief A right click - "put it down".

        The one click this layer reports, and it reports no place and no
        thing, because it is not about either: it is the RTS cancel, and what
        it empties is the scene's to decide - the hand, a half-drawn wire, a
        selection. A right \e drag turns the view as ever and says nothing.
    */
    signal cancelled()

    /*!
        \qmlmethod void OrbitInput3D::wheel(real angleDelta, real x, real y)
        \brief One wheel event: zooms in on a positive \a angleDelta.

        Given the cursor position it zooms \e towards what is under it, which
        is how a wheel gets you somewhere instead of merely closer to the
        middle. Always live - see \l zoomToCursor.
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

        What a double-click on empty ground should do, and the one bit of
        click handling this layer offers: a single click belongs to the scene,
        which knows what is worth focusing - it calls \c rig.focusOn() itself.
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
                root._release()
                return
            }
            root._step(_s.vx, _s.vy)
        }
    }
}
