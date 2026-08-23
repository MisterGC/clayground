// (c) Clayground Contributors - MIT License, see "LICENSE" file
import QtQuick

/*!
    \qmltype GazeAnim
    \inqmlmodule Clayground.Character3D
    \inherits QtObject
    \brief Where the eyes point inside a head that is aiming itself.

    \l GestureAnim already turns the head toward a look target. This is the
    other half: the eyes, which get there first and are still there when the
    head cannot follow all the way.

    The whole of "the eyes lead the head" falls out of one measurement rather
    than out of a second animator racing the first. The target is mapped into
    the head's OWN frame, so what comes back is the angle the head has not
    covered yet - large while the head is still easing round, large again
    when the target is past the head's 65 degree limit, and nothing once the
    head has arrived. Point the eyes at that residual and they lead on the
    way out and re-centre on arrival, for free.

    Everything it does is deterministic for a given \l seed. A blink or a
    glance on a wall clock would make two runs of the same sandbox render
    differently, and \c clayrender comparisons are worth more than the
    variety would be.

    \sa Head, GestureAnim, Character
*/
QtObject {
    id: root

    /*! The head node being looked out of. Needs \c eyeLine and the usual
        Node mapping - a \l Head is what this is for. */
    property var head: null

    /*! Off means the eyes sit dead centre, as they did before this existed. */
    property bool running: true

    /*! Scene position the eyes want. Null lets them wander, which is what a
        person does with nothing to look at. */
    property var target: null

    /*!
        While true the eyes leave the target and settle somewhere off-axis -
        what a person does while recalling something rather than reading it
        off the listener's face. Releasing it brings them back.
    */
    property bool averting: false

    /*! World degrees that map to a full eye deflection. Comfortable human
        travel is about thirty degrees horizontally and rather less up. */
    property real yawRange: 30
    property real pitchRange: 22

    /*! Same seed, same wander, every run. */
    property int seed: 1

    /*! Milliseconds between updates. An eye does not need more than 30 Hz,
        and a character small enough to be at Low detail needs less - this is
        per-character work on the main thread, and a crowd is where that
        stops being free. */
    property int interval: 33

    /*! Emitted when the eyes jump a long way. A blink rides along with a
        large saccade in a real face, and it is the cheapest thing that stops
        a gaze change from looking like a jump cut. */
    signal saccaded()

    /*! What to hand to \l Head::gaze. */
    readonly property vector2d gaze: Qt.vector2d(_s.x, _s.y)

    // --- the state ----------------------------------------------------------

    readonly property QtObject _s: QtObject {
        property real x: 0
        property real y: 0
        // Where the eyes are heading, before the ease.
        property real tx: 0
        property real ty: 0
        // Ticks left on the current wander dwell or aversion hold.
        property int hold: 0
        // Wander offsets, held for the length of a dwell.
        property real wx: 0
        property real wy: 0
        property int rng: Math.max(1, root.seed)
        property bool wasAverting: false
        // Which of the three offset regimes wx/wy currently hold a value for.
        // They mean very different sizes - a wander is a third of the eye's
        // travel, a micro-saccade a twentieth - so carrying one into the
        // other applies a wander-sized offset on top of a residual and the
        // eyes swing away from a target they have just acquired, for as long
        // as the old dwell had left to run.
        property string regime: ""
    }

    // 0..1, and the same sequence every run for a given seed.
    function _rand() {
        _s.rng = (_s.rng * 1664525 + 1013904223) >>> 0
        return _s.rng / 4294967296
    }

    function _clamp(v, lo, hi) { return v < lo ? lo : (v > hi ? hi : v) }

    function _isVec(v) {
        return v !== null && v !== undefined && v.x !== undefined && v.z !== undefined
    }

    // The angle the head has not covered, in the head's own frame. Positive x
    // is to the character's right, positive y is up - the same sense Head's
    // gaze property uses.
    function _residual() {
        const h = root.head
        if (!_isVec(root.target) || h === null || h === undefined)
            return null
        const local = h.mapPositionFromScene(root.target)
        if (local === undefined || local === null)
            return null
        // The eyes are not at the head node's origin, which sits on the neck.
        const dy = local.y - (h.eyeLine === undefined ? 0 : h.eyeLine)
        const len = Math.sqrt(local.x * local.x + dy * dy + local.z * local.z)
        if (len < 1e-4)
            return null
        const yaw = Math.atan2(local.x, local.z) * 180 / Math.PI
        const pitch = Math.asin(root._clamp(dy / len, -1, 1)) * 180 / Math.PI
        return Qt.vector2d(root._clamp(yaw / root.yawRange, -1, 1),
                           root._clamp(pitch / root.pitchRange, -1, 1))
    }

    // Switching regime always restarts the dwell, so an offset is never read
    // in a regime it was not sized for.
    function _enter(regime) {
        if (_s.regime === regime)
            return false
        _s.regime = regime
        _s.hold = 0
        return true
    }

    function _newWander() {
        // Biased horizontal: a person scans side to side far more than up and
        // down, and a wander with equal vertical travel reads as seasick.
        _s.wx = (root._rand() * 2 - 1) * 0.34
        _s.wy = (root._rand() * 2 - 1) * 0.13
        _s.hold = 24 + Math.floor(root._rand() * 52)   // 0.8 s .. 2.5 s
    }

    function _newAversion() {
        // Up and to one side. Down reads as shame rather than as thought,
        // which is a different sentence entirely.
        const side = root._rand() < 0.5 ? -1 : 1
        _s.wx = side * (0.45 + root._rand() * 0.3)
        _s.wy = 0.28 + root._rand() * 0.22
        _s.hold = 30 + Math.floor(root._rand() * 40)
    }

    readonly property Timer _tick: Timer {
        running: root.running
        interval: Math.max(16, root.interval)
        repeat: true
        onTriggered: {
            if (root.averting !== _s.wasAverting) {
                _s.wasAverting = root.averting
                if (root.averting) root._newAversion()
            }

            if (root.averting) {
                root._enter("avert")
                if (_s.hold-- <= 0) root._newAversion()
                _s.tx = _s.wx; _s.ty = _s.wy
            } else {
                const r = root._residual()
                if (r !== null) {
                    root._enter("track")
                    // Micro-saccades. A gaze held perfectly still is a stare,
                    // and the fix is smaller than the eye is wide.
                    if (_s.hold-- <= 0) {
                        _s.wx = (root._rand() * 2 - 1) * 0.045
                        _s.wy = (root._rand() * 2 - 1) * 0.03
                        _s.hold = 12 + Math.floor(root._rand() * 30)
                    }
                    _s.tx = root._clamp(r.x + _s.wx, -1, 1)
                    _s.ty = root._clamp(r.y + _s.wy, -1, 1)
                } else {
                    root._enter("wander")
                    if (_s.hold-- <= 0) root._newWander()
                    _s.tx = _s.wx; _s.ty = _s.wy
                }
            }

            // Eyes are ballistic where the head is eased - that difference IS
            // the lead. Roughly 70 ms to arrive.
            const a = 0.5
            const nx = _s.x + (_s.tx - _s.x) * a
            const ny = _s.y + (_s.ty - _s.y) * a
            if (Math.abs(nx - _s.x) + Math.abs(ny - _s.y) > 0.22)
                root.saccaded()
            _s.x = nx
            _s.y = ny
        }
    }
}
