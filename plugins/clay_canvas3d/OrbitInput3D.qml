// (c) Clayground Contributors - MIT License, see "LICENSE" file

import QtQuick
import QtQuick3D

/*!
    \qmltype OrbitInput3D
    \inqmlmodule Clayground.Canvas3D
    \brief Turns drags, wheels and double-clicks into \l OrbitCamera3D moves.

    The rig knows how to move; this knows what a gesture means. Split in two
    because the half that decides "left drag orbits, right drag pans" is the
    half a scene wants to override - an editor gives the left button to its
    tool, a viewer keeps it for the camera - while the arithmetic that turns
    pixels into degrees and metres is the same everywhere and was being
    re-derived, with different constants, in every scene that had a camera.

    \b {Non-visual, and deliberately not a MouseArea.} A scene that also picks,
    draws or drags objects already owns the pointer; it keeps its own
    \c MouseArea and hands over only the gestures it does not want:

    \qml
    OrbitInput3D { id: nav; rig: rig; view: view3d }

    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onPressed: (m) => {
            if (myTool.wantsPress(m)) return          // the scene's own gesture
            nav.begin(m.x, m.y, m.button, m.modifiers)
        }
        onPositionChanged: (m) => { if (!nav.move(m.x, m.y)) myTool.moveTo(m.x, m.y) }
        onReleased: nav.end()
        onWheel: (w) => nav.wheel(w.angleDelta.y)
        onDoubleClicked: (m) => nav.recenterAt(m.x, m.y)
    }
    \endqml

    \l begin returns the mode it took (\c "orbit", \c "pan" or \c "" when it
    declined), so a scene can offer the gesture and take it back if the
    navigation had no use for it.

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
        a double-click into a ground point.
    */
    property var view: null

    /*! \qmlproperty real OrbitInput3D::groundY \brief Height of the plane \l groundAt() hits. */
    property real groundY: 0

    // --- what a gesture means ----------------------------------------------

    /*! \qmlproperty int OrbitInput3D::orbitButtons \brief Buttons that turn the rig. */
    property int orbitButtons: Qt.LeftButton

    /*! \qmlproperty int OrbitInput3D::panButtons \brief Buttons that slide the pivot. */
    property int panButtons: Qt.RightButton | Qt.MiddleButton

    /*!
        \qmlproperty int OrbitInput3D::panModifiers
        \brief Modifiers that turn an orbit drag into a pan.

        Shift by default, so a scene that has given the right button to a
        context action still has a pan.
    */
    property int panModifiers: Qt.ShiftModifier

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
        \qmlproperty string OrbitInput3D::mode
        \readonly
        \brief The gesture in progress: \c "orbit", \c "pan" or \c "".
    */
    readonly property alias mode: _s.mode

    /*! \qmlproperty bool OrbitInput3D::active \readonly \brief A drag is in progress. */
    readonly property bool active: _s.mode !== ""

    QtObject {
        id: _s
        property string mode: ""
        property real lastX: 0
        property real lastY: 0
        property real vx: 0
        property real vy: 0
    }

    /*!
        \qmlmethod string OrbitInput3D::wants(int button, int modifiers)
        \brief What this press would do, without doing it.

        \c "orbit", \c "pan" or \c "" - the question a scene asks before it
        decides whether the press is its own.
    */
    function wants(button, modifiers) {
        const mods = modifiers === undefined ? 0 : modifiers
        if ((button & panButtons) !== 0) return "pan"
        if ((button & orbitButtons) !== 0)
            return (panModifiers !== 0 && (mods & panModifiers) !== 0) ? "pan" : "orbit"
        return ""
    }

    /*!
        \qmlmethod string OrbitInput3D::begin(real x, real y, int button, int modifiers)
        \brief Starts a navigation drag; returns the mode taken, \c "" if none.
    */
    function begin(x, y, button, modifiers) {
        _coast.stop()
        const m = wants(button, modifiers)
        _s.mode = m
        _s.lastX = x; _s.lastY = y
        _s.vx = 0; _s.vy = 0
        return m
    }

    /*!
        \qmlmethod string OrbitInput3D::beginAs(string m, real x, real y)
        \brief Starts a drag in a mode the scene has chosen itself.

        For a scene whose own rule decides ("an empty patch of ground orbits,
        an object drags"), so it does not have to fake a button to say so.
    */
    function beginAs(m, x, y) {
        _coast.stop()
        _s.mode = (m === "orbit" || m === "pan") ? m : ""
        _s.lastX = x; _s.lastY = y
        _s.vx = 0; _s.vy = 0
        return _s.mode
    }

    /*!
        \qmlmethod bool OrbitInput3D::move(real x, real y)
        \brief Continues the drag; false when no navigation gesture is running.
    */
    function move(x, y) {
        if (_s.mode === "" || !rig) return false
        const dx = x - _s.lastX, dy = y - _s.lastY
        _s.lastX = x; _s.lastY = y
        _s.vx = dx; _s.vy = dy
        _step(dx, dy)
        return true
    }

    /*! \qmlmethod void OrbitInput3D::end() \brief Ends the drag, coasting if it was a flick. */
    function end() {
        if (_s.mode === "") return
        if (flick && Math.hypot(_s.vx, _s.vy) >= flickThreshold) _coast.start()
        else _s.mode = ""
    }

    /*! \qmlmethod void OrbitInput3D::cancel() \brief Ends the drag with no coast. */
    function cancel() { _coast.stop(); _s.mode = ""; _s.vx = 0; _s.vy = 0 }

    /*!
        \qmlmethod void OrbitInput3D::wheel(real angleDelta)
        \brief One wheel event: zooms in on a positive \a angleDelta.
    */
    function wheel(angleDelta) {
        if (!rig) return
        rig.zoomBy(angleDelta > 0 ? zoomStep : 1 / zoomStep)
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
        if (_s.mode === "orbit") {
            rig.orbitBy(dx * yawPerPixel,
                        (invertPitch ? dy : -dy) * pitchPerPixel)
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
                stop(); _s.mode = ""; _s.vx = 0; _s.vy = 0
                return
            }
            root._step(_s.vx, _s.vy)
        }
    }
}
