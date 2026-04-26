// (c) Clayground Contributors - MIT License, see "LICENSE" file

/*!
    \qmltype ClayWorld2dCamera
    \inqmlmodule Clayground.World
    \brief Camera component for ClayWorld2d with follow and look-ahead modes.

    Provides configurable camera behavior for following a target PhysicsItem.
    In Follow mode the camera locks 1:1 to the target. In LookAhead mode it
    offsets slightly in the target's movement direction for better visibility.

    Example usage:
    \qml
    ClayWorld2d {
        camera: ClayWorld2dCamera {
            target: player
            mode: ClayWorld2dCamera.LookAhead
            lookAheadFactor: 0.2
            smoothing: 3.0
        }
    }
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
    readonly property alias cameraX: _internal.camX

    /*!
        \qmlproperty real ClayWorld2dCamera::cameraY
        \readonly
        \brief Current camera Y position in world units.
    */
    readonly property alias cameraY: _internal.camY

    QtObject {
        id: _internal
        property real camX: 0
        property real camY: 0
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
