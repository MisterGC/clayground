// (c) Clayground Contributors - MIT License, see "LICENSE" file

import QtQuick
import Clayground.Lab

/*!
    \qmltype CameraAnchorMark
    \inqmlmodule Clayground.Lab
    \brief Shows where the camera turns and zooms: a dotted ring on the anchor.

    The anchored orbit and the cursor zoom both act on a point the viewer
    chose implicitly - this makes that point visible. While a right-drag
    orbits, the ring sits pinned on the anchor; a wheel tick pulses it
    briefly where the zoom aimed.

    It is a SCREEN-SPACE overlay, not scene content: a first version drew a
    flat ring in the world, and close up it clipped into cars, houses and
    parts - real geometry legitimately occludes world content, and a camera
    affordance must never lose that fight. Drawn as 2D it cannot z-fight,
    holds its pixel size at any distance for free, and reads as UI. Declare
    it as a direct child of the View3D (an Item child renders above the
    scene) with the same coordinate space as the view.

    Example usage:
    \qml
    View3D {
        OrbitInput3D { id: nav; rig: rig; view: parent }
        CameraAnchorMark { pointer: nav }
    }
    \endqml

    \sa OrbitInput3D, LabStage3D
*/
Item {
    id: root

    /*! \qmlproperty var CameraAnchorMark::pointer \brief The OrbitInput3D to watch. */
    property var pointer: null
    /*! \qmlproperty color CameraAnchorMark::tone \brief Ring and dot colour. */
    property color tone: LabTheme.primary
    /*! \qmlproperty real CameraAnchorMark::radiusPx \brief Ring radius in pixels. */
    property real radiusPx: 26

    readonly property bool _orbiting: pointer && pointer.gesture === "orbit" && !!pointer.anchor
    readonly property bool _active: _orbiting || _pulseOn
    // The orbit anchor comes straight off the controller as a binding; only
    // the wheel pulse needs storage, because its moment is over in one call.
    property var _pulseAt: null
    readonly property var _at: _orbiting ? pointer.anchor : _pulseAt
    property bool _pulseOn: false

    // Projection with the camera's motion as EXPLICIT dependencies - the
    // documented WorldLabel trap: without scenePosition/sceneRotation reads
    // the mark freezes the moment the camera moves.
    readonly property var _screen: {
        if (!pointer || !pointer.view || !_at) return null
        const cam = pointer.view.camera
        if (!cam) return null
        void cam.scenePosition
        void cam.sceneRotation
        const p = pointer.view.mapFrom3DScene(Qt.vector3d(_at.x, _at.y || 0, _at.z))
        return p.z > 0 ? p : null
    }

    Connections {
        target: root.pointer
        function onZoomedAt(p) { root._pulseAt = p; root._pulseOn = true; _fade.restart() }
    }

    Timer { id: _fade; interval: 300; onTriggered: root._pulseOn = false }

    Canvas {
        id: _ring
        visible: root._active && root._screen !== null
        width: 2 * (root.radiusPx + 4)
        height: width
        x: (root._screen ? root._screen.x : 0) - width / 2
        y: (root._screen ? root._screen.y : 0) - height / 2
        onVisibleChanged: if (visible) requestPaint()
        onPaint: {
            const ctx = getContext("2d")
            const c = width / 2
            ctx.clearRect(0, 0, width, height)
            ctx.strokeStyle = root.tone
            ctx.lineWidth = 2
            ctx.setLineDash([3, 4])
            ctx.beginPath()
            ctx.arc(c, c, root.radiusPx, 0, 2 * Math.PI)
            ctx.stroke()
            ctx.setLineDash([])
            ctx.fillStyle = root.tone
            ctx.beginPath()
            ctx.arc(c, c, 2.5, 0, 2 * Math.PI)
            ctx.fill()
        }
        Connections {
            target: root
            function onToneChanged() { _ring.requestPaint() }
            function onRadiusPxChanged() { _ring.requestPaint() }
        }
    }
}
