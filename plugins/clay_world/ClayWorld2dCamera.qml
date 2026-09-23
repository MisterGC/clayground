// (c) Clayground Contributors - MIT License, see "LICENSE" file

/*!
    \qmltype ClayWorld2dCamera
    \inqmlmodule Clayground.World
    \brief Camera component for ClayWorld2d with follow and look-ahead modes,
    screen shake and kicks.

    Provides configurable camera behavior for following a target PhysicsItem.
    In Follow mode the camera locks 1:1 to the target. In LookAhead mode it
    offsets slightly in the target's movement direction for better visibility.

    On top of either mode the camera shakes and kicks. Shake is trauma
    based: \l addTrauma() raises \l trauma (0..1), the offset is
    \c{trauma * trauma * maxShakeWu} along smooth noise, and trauma decays
    by \l traumaDecay per second - small hits stack into a big shake, a big
    hit settles quickly. \l kick() pushes the view in one direction and
    lets it spring back. Both move the viewport (what \l cameraX /
    \l cameraY report), so HUD items beside the canvas stay still and
    viewport overlays (LightLayer2d, AnchoredMask) move with the world. Near
    the world's edge the viewport is clamped, which also clamps the shake.
    At rest neither costs anything: they tick only while there is trauma or
    a kick left.

    Example usage:
    \qml
    ClayWorld2d {
        camera: ClayWorld2dCamera {
            id: theCamera
            target: player
            mode: ClayWorld2dCamera.LookAhead
            lookAheadFactor: 0.2
            smoothing: 3.0
        }
    }

    // on a hit
    theCamera.addTrauma(0.4)
    theCamera.kick(0.3 * dirX, 0.3 * dirY)
    \endqml

    \sa ClayWorld2d
*/
import QtQuick

Item {
    id: cam

    /*!
        \qmlproperty enumeration ClayWorld2dCamera::Mode
        \brief Available camera modes.
        \value Follow Direct 1:1 lock to target position (default).
        \value LookAhead Offsets camera ahead in target's movement direction.
    */
    enum Mode { Follow, LookAhead }

    /*!
        \qmlproperty var ClayWorld2dCamera::target
        \brief The PhysicsItem the camera follows.
    */
    property var target: null

    /*!
        \qmlproperty int ClayWorld2dCamera::mode
        \brief Active camera mode.
    */
    property int mode: ClayWorld2dCamera.Follow

    /*!
        \qmlproperty real ClayWorld2dCamera::smoothing
        \brief Camera catch-up speed for LookAhead mode. Higher = faster.
    */
    property real smoothing: 5.0

    /*!
        \qmlproperty real ClayWorld2dCamera::lookAheadFactor
        \brief Velocity multiplier for look-ahead offset.
    */
    property real lookAheadFactor: 0.3

    /*!
        \qmlproperty real ClayWorld2dCamera::cameraX
        \readonly
        \brief Current camera X position in world units.
    */
    readonly property real cameraX: _internal.camX + _internal.shakeX + _internal.kickX

    /*!
        \qmlproperty real ClayWorld2dCamera::cameraY
        \readonly
        \brief Current camera Y position in world units.
    */
    readonly property real cameraY: _internal.camY + _internal.shakeY + _internal.kickY

    /*!
        \qmlproperty real ClayWorld2dCamera::trauma
        \brief Current shake trauma in 0..1. Usually raised with
        \l addTrauma(); assigning it directly works too.
    */
    property real trauma: 0

    /*!
        \qmlproperty real ClayWorld2dCamera::maxShakeWu
        \brief Shake offset at trauma 1, in world units.
    */
    property real maxShakeWu: 0.6

    /*!
        \qmlproperty real ClayWorld2dCamera::traumaDecay
        \brief Trauma lost per second; 1.5 settles a full shake in 0.67 s.
    */
    property real traumaDecay: 1.5

    /*!
        \qmlproperty real ClayWorld2dCamera::shakeFrequency
        \brief How fast the shake moves, in noise cycles per second.
    */
    property real shakeFrequency: 18

    /*!
        \qmlproperty real ClayWorld2dCamera::kickStiffness
        \brief Spring stiffness that pulls a kick back, in 1/s^2. Higher
        returns faster.
    */
    property real kickStiffness: 260

    /*!
        \qmlproperty real ClayWorld2dCamera::kickDamping
        \brief Damping ratio of the kick spring; 1 returns without
        overshoot, below 1 overshoots a little.
    */
    property real kickDamping: 0.6

    /*!
        \qmlproperty real ClayWorld2dCamera::shakeXWu
        \readonly
        \brief Current shake offset on X, in world units.
    */
    readonly property alias shakeXWu: _internal.shakeX

    /*!
        \qmlproperty real ClayWorld2dCamera::shakeYWu
        \readonly
        \brief Current shake offset on Y, in world units.
    */
    readonly property alias shakeYWu: _internal.shakeY

    /*!
        \qmlproperty real ClayWorld2dCamera::kickXWu
        \readonly
        \brief Current kick offset on X, in world units.
    */
    readonly property alias kickXWu: _internal.kickX

    /*!
        \qmlproperty real ClayWorld2dCamera::kickYWu
        \readonly
        \brief Current kick offset on Y, in world units.
    */
    readonly property alias kickYWu: _internal.kickY

    /*!
        \qmlmethod void ClayWorld2dCamera::addTrauma(real amount)
        \brief Adds \a amount (0..1) to \l trauma, capped at 1.
    */
    function addTrauma(amount) {
        trauma = Math.max(0, Math.min(1, trauma + amount));
    }

    /*!
        \qmlmethod void ClayWorld2dCamera::kick(real dxWu, real dyWu)
        \brief Pushes the view by \a dxWu / \a dyWu world units at once and
        lets it spring back - a recoil, or the jolt of a hit from one side.
        Kicks add up.
    */
    function kick(dxWu, dyWu) {
        _internal.kickX += dxWu;
        _internal.kickY += dyWu;
    }

    /*!
        \qmlmethod void ClayWorld2dCamera::resetShake()
        \brief Ends shake and kick at once.
    */
    function resetShake() {
        trauma = 0;
        _internal.shakeX = 0;
        _internal.shakeY = 0;
        _internal.kickX = 0;
        _internal.kickY = 0;
        _internal.kickVx = 0;
        _internal.kickVy = 0;
    }

    QtObject {
        id: _internal
        property real camX: 0
        property real camY: 0
        property real shakeX: 0
        property real shakeY: 0
        property real kickX: 0
        property real kickY: 0
        property real kickVx: 0
        property real kickVy: 0
        property real noiseT: 0
        readonly property bool juicing: cam.trauma > 0 || shakeX !== 0 || shakeY !== 0
            || kickX !== 0 || kickY !== 0 || kickVx !== 0 || kickVy !== 0
    }

    // Wall-clock driven, not physics driven: a shake keeps going through a
    // hit stop, which is when it sells the impact most.
    FrameAnimation {
        running: _internal.juicing
        onTriggered: cam._advanceJuice(Math.min(frameTime, 0.1))
    }

    // Smooth 1D gradient noise in about -1..1: neighbouring samples are
    // close, so the shake wobbles instead of jittering like white noise.
    function _grad(i) {
        var h = Math.sin(i * 127.1 + 311.7) * 43758.5453;
        return (h - Math.floor(h)) * 2 - 1;
    }
    function _noise(x) {
        var i = Math.floor(x);
        var f = x - i;
        var u = f * f * (3 - 2 * f);
        var a = _grad(i) * f;
        var b = _grad(i + 1) * (f - 1);
        return 2 * (a + (b - a) * u);
    }

    // Advances shake and kick by dt seconds. Called per frame while there is
    // something to move; tests call it directly to step deterministically.
    function _advanceJuice(dt) {
        if (dt <= 0) return;
        trauma = Math.max(0, trauma - traumaDecay * dt);
        _internal.noiseT += dt * shakeFrequency;
        var s = trauma * trauma * maxShakeWu;
        if (s > 0) {
            _internal.shakeX = s * _noise(_internal.noiseT);
            _internal.shakeY = s * _noise(_internal.noiseT + 57.3);
        } else {
            _internal.shakeX = 0;
            _internal.shakeY = 0;
        }

        // Damped spring back to zero, in small substeps so a stiff spring
        // stays stable at a low frame rate.
        var k = kickStiffness;
        var c = 2 * kickDamping * Math.sqrt(k);
        var x = _internal.kickX, y = _internal.kickY;
        var vx = _internal.kickVx, vy = _internal.kickVy;
        var steps = Math.max(1, Math.ceil(dt / (1 / 240)));
        var h = dt / steps;
        for (var i = 0; i < steps; ++i) {
            vx += (-k * x - c * vx) * h;
            vy += (-k * y - c * vy) * h;
            x += vx * h;
            y += vy * h;
        }
        if (Math.abs(x) < 1e-4 && Math.abs(vx) < 1e-3) { x = 0; vx = 0; }
        if (Math.abs(y) < 1e-4 && Math.abs(vy) < 1e-3) { y = 0; vy = 0; }
        _internal.kickX = x;
        _internal.kickY = y;
        _internal.kickVx = vx;
        _internal.kickVy = vy;
    }

    onTargetChanged: _snapToTarget()

    function _snapToTarget() {
        if (!target) return
        _internal.camX = target.xWu
        _internal.camY = target.yWu
    }

    // React to target position changes (frame-synced via physics step)
    Connections {
        target: cam.target
        function onXWuChanged() { cam._update() }
        function onYWuChanged() { cam._update() }
    }

    property real _lastTime: 0

    /*!
        \qmlmethod object ClayWorld2dCamera::clayInspect()
        \brief Reports mode, target and current framing as plain JSON, for
               tooling.

        Pull-only and side-effect free: the offsets are recomputed from the
        live target on demand, nothing is cached, observed or written back
        into the camera state.
    */
    function clayInspect() {
        var modeNames = ["Follow", "LookAhead"];
        var hasTarget = target !== null && target !== undefined;
        // The offset the camera actually sits at right now (shake and kick
        // included), and - in LookAhead
        // - the offset it is currently steering towards. In Follow the two are
        // the same by definition, so the desired one is left out.
        var offset = null;
        var lookAhead = null;
        if (hasTarget) {
            offset = [cameraX - target.xWu, cameraY - target.yWu];
            if (mode === ClayWorld2dCamera.LookAhead && target.linearVelocity)
                lookAhead = [target.linearVelocity.x * lookAheadFactor,
                             -target.linearVelocity.y * lookAheadFactor];
        }
        return {
            "type": "ClayWorld2dCamera",
            "mode": modeNames[mode] !== undefined ? modeNames[mode] : mode,
            "target": (hasTarget && target.objectName) ? target.objectName : null,
            "hasTarget": hasTarget,
            "targetWu": hasTarget ? [target.xWu, target.yWu] : null,
            "centerWu": [cameraX, cameraY],
            // Where the camera would be without shake and kick - centerWu
            // minus shakeWu and kickWu.
            "baseCenterWu": [_internal.camX, _internal.camY],
            "offsetWu": offset,
            "lookAheadWu": lookAhead,
            "lookAheadFactor": lookAheadFactor,
            "smoothing": smoothing,
            "shake": {
                "trauma": trauma,
                "offsetWu": [_internal.shakeX, _internal.shakeY],
                "maxShakeWu": maxShakeWu,
                "traumaDecay": traumaDecay,
                "shakeFrequency": shakeFrequency
            },
            "kickWu": [_internal.kickX, _internal.kickY]
        };
    }

    function _update() {
        if (!target) return

        let tx = target.xWu
        let ty = target.yWu

        if (mode === ClayWorld2dCamera.Follow) {
            _internal.camX = tx
            _internal.camY = ty
            return
        }

        // LookAhead
        let now = Date.now()
        let dt = _lastTime > 0 ? Math.min((now - _lastTime) / 1000.0, 0.05) : 0.016
        _lastTime = now

        let vx = 0
        let vy = 0
        if (target.linearVelocity) {
            vx = target.linearVelocity.x * lookAheadFactor
            vy = -target.linearVelocity.y * lookAheadFactor
        }

        let desiredX = tx + vx
        let desiredY = ty + vy
        let t = Math.min(1.0, smoothing * dt)
        _internal.camX += (desiredX - _internal.camX) * t
        _internal.camY += (desiredY - _internal.camY) * t
    }
}
