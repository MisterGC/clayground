// (c) Clayground Contributors - MIT License, see "LICENSE" file

import QtQuick
import QtQuick3D

/*!
    \qmltype OrbitCamera3D
    \inqmlmodule Clayground.Canvas3D
    \brief An orbit camera on a leash: circles a pivot, never dives through the floor.

    The camera every 3D lab and demo ends up hand-rolling. It looks at \l pivot
    from a yaw/pitch/distance rig, clamps itself so the viewer cannot get lost,
    and can frame a set of world points so a scene arrives properly composed.

    The anti-clip rule is a \b {minimum height above the pivot plane}, not a
    minimum distance: a distance sphere wrongly blocks zooming onto a small
    focused object, while a height floor pushes the rig outward as the angle
    flattens and can never end up under the ground.

    Example usage:
    \qml
    import Clayground.Canvas3D

    View3D {
        camera: rig.camera
        OrbitCamera3D {
            id: rig
            pivot: Qt.vector3d(0, 0, 0)
            distance: 60
        }
    }
    MouseArea {
        anchors.fill: parent
        property point last
        onPressed: (m) => last = Qt.point(m.x, m.y)
        onPositionChanged: (m) => {
            rig.orbitBy((m.x - last.x) * 0.4, (m.y - last.y) * 0.3)
            last = Qt.point(m.x, m.y)
        }
        onWheel: (w) => rig.zoomBy(w.angleDelta.y > 0 ? 0.9 : 1.1)
    }
    \endqml

    \sa Label3D
*/
Node {
    id: root

    /*! \qmlproperty vector3d OrbitCamera3D::pivot \brief The point the camera looks at. */
    property vector3d pivot: Qt.vector3d(0, 0, 0)
    /*! \qmlproperty real OrbitCamera3D::yaw \brief Angle around the pivot, degrees. */
    property real yaw: 0
    /*! \qmlproperty real OrbitCamera3D::pitch \brief Angle above the pivot plane, degrees. */
    property real pitch: 45
    /*! \qmlproperty real OrbitCamera3D::distance \brief Distance to the pivot. */
    property real distance: 60

    /*! \qmlproperty real OrbitCamera3D::minPitch \brief Flattest allowed angle. */
    property real minPitch: 12
    /*! \qmlproperty real OrbitCamera3D::maxPitch \brief Steepest allowed angle (< 90). */
    property real maxPitch: 84
    /*! \qmlproperty real OrbitCamera3D::minDistance \brief Closest allowed approach. */
    property real minDistance: 8
    /*! \qmlproperty real OrbitCamera3D::maxDistance \brief Furthest allowed retreat. */
    property real maxDistance: 400
    /*!
        \qmlproperty real OrbitCamera3D::minHeight
        \brief Lowest the camera may sit above the pivot plane.

        The leash: flattening the angle backs the rig off instead of letting it
        sink through the ground.
    */
    property real minHeight: 4

    /*! \qmlproperty real OrbitCamera3D::fieldOfView \brief Vertical FOV of the camera. */
    property real fieldOfView: 60

    /*! \qmlproperty PerspectiveCamera OrbitCamera3D::camera \readonly */
    readonly property alias camera: _cam

    /*!
        \qmlmethod void OrbitCamera3D::orbitBy(real dYaw, real dPitch)
        \brief Turns the rig, then re-applies the leash.
    */
    function orbitBy(dYaw, dPitch) {
        yaw += dYaw
        pitch += dPitch
        clamp()
    }

    /*!
        \qmlmethod void OrbitCamera3D::zoomBy(real factor)
        \brief Multiplies the distance (0.9 zooms in, 1.1 out).
    */
    function zoomBy(factor) {
        distance *= factor
        clamp()
    }

    /*!
        \qmlmethod void OrbitCamera3D::clamp()
        \brief Applies the pitch/distance limits and the minimum-height rule.
    */
    function clamp() {
        pitch = Math.max(minPitch, Math.min(maxPitch, pitch))
        distance = Math.max(minDistance, Math.min(maxDistance, distance))
        if (minHeight > 0) {
            const sinP = Math.sin(pitch * Math.PI / 180)
            if (distance * sinP < minHeight)
                distance = Math.min(maxDistance, minHeight / Math.max(0.08, sinP))
        }
    }

    /*!
        \qmlmethod void OrbitCamera3D::frame(var points, real pad)
        \brief Centres on the given world points and backs off until they fit.

        \a points is an array of vector3d (or {x, y, z}); \a pad is a headroom
        factor (1.0 = tight, 1.3 = comfortable). Keeps the current yaw/pitch,
        so framing never disorients the viewer.
    */
    function frame(points, pad) {
        if (!points || points.length === 0) return
        var minX = Infinity, maxX = -Infinity, minY = Infinity
        var maxY = -Infinity, minZ = Infinity, maxZ = -Infinity
        for (var i = 0; i < points.length; ++i) {
            var p = points[i]
            minX = Math.min(minX, p.x); maxX = Math.max(maxX, p.x)
            minY = Math.min(minY, p.y); maxY = Math.max(maxY, p.y)
            minZ = Math.min(minZ, p.z); maxZ = Math.max(maxZ, p.z)
        }
        pivot = Qt.vector3d((minX + maxX) / 2, (minY + maxY) / 2, (minZ + maxZ) / 2)
        var radius = Math.max(maxX - minX, maxZ - minZ, maxY - minY) / 2
        var tanHalf = Math.tan(fieldOfView * 0.5 * Math.PI / 180)
        distance = Math.max(minDistance,
                            (radius / Math.max(0.05, tanHalf)) * (pad === undefined ? 1.3 : pad))
        clamp()
    }

    /*!
        \qmlmethod var OrbitCamera3D::state()
        \brief Pose as a JSON-serializable object, for the viewState convention.
    */
    function state() {
        return { yaw: yaw, pitch: pitch, distance: distance,
                 px: pivot.x, py: pivot.y, pz: pivot.z }
    }

    /*!
        \qmlmethod void OrbitCamera3D::applyState(var s)
        \brief Restores a pose produced by \l state().
    */
    function applyState(s) {
        if (!s) return
        if (s.px !== undefined) pivot = Qt.vector3d(s.px, s.py, s.pz)
        if (s.yaw !== undefined) yaw = s.yaw
        if (s.pitch !== undefined) pitch = s.pitch
        if (s.distance !== undefined) distance = s.distance
        clamp()
    }

    position: {
        const a = root.yaw * Math.PI / 180
        const b = root.pitch * Math.PI / 180
        return Qt.vector3d(root.pivot.x + root.distance * Math.cos(b) * Math.sin(a),
                           root.pivot.y + root.distance * Math.sin(b),
                           root.pivot.z + root.distance * Math.cos(b) * Math.cos(a))
    }
    eulerRotation: Qt.vector3d(-root.pitch, root.yaw, 0)

    PerspectiveCamera {
        id: _cam
        fieldOfView: root.fieldOfView
    }
}
