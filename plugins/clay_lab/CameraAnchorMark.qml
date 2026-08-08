// (c) Clayground Contributors - MIT License, see "LICENSE" file

import QtQuick
import QtQuick3D
import Clayground.Canvas3D
import Clayground.Lab

/*!
    \qmltype CameraAnchorMark
    \inqmlmodule Clayground.Lab
    \brief Shows where the camera turns and zooms: a flat ring on the anchor.

    The anchored orbit and the cursor zoom both act on a point the viewer
    chose implicitly - this makes that point visible. While a right-drag
    orbits, the ring sits pinned on the anchor; a wheel tick pulses it
    briefly where the zoom aimed. Paper-and-ink flat: a thin accent ring
    with a center dot, sized in screen pixels so it reads the same at any
    distance. It rides ABOVE the stage's overlay budget (roads, paint,
    markings all stay under overlayMaxY 0.12) - a camera affordance must
    never lose the depth fight against scene content, and primary ink is
    the one tone no lab draws its world in.

    The ring's points are absolute world coordinates (the LineBatch3D idiom),
    so the mark works from anywhere in the scene - do not reposition the
    node itself.

    Example usage:
    \qml
    View3D {
        OrbitInput3D { id: nav; rig: rig; view: parent }
        CameraAnchorMark { pointer: nav }
    }
    \endqml

    \sa OrbitInput3D, LabStage3D
*/
Node {
    id: root

    /*! \qmlproperty var CameraAnchorMark::pointer \brief The OrbitInput3D to watch. */
    property var pointer: null
    /*! \qmlproperty color CameraAnchorMark::tone \brief Ring and dot colour. */
    property color tone: LabTheme.primary
    /*! \qmlproperty real CameraAnchorMark::radiusPx \brief Ring radius in screen pixels. */
    property real radiusPx: 26
    /*! \qmlproperty real CameraAnchorMark::liftY \brief Height above the anchor plane. */
    property real liftY: 0.14

    readonly property bool _orbiting: pointer && pointer.gesture === "orbit" && !!pointer.anchor
    readonly property bool _active: _orbiting || _pulseOn
    // The orbit anchor comes straight off the controller as a binding; only
    // the wheel pulse needs storage, because its moment is over in one call.
    property var _pulseAt: null
    readonly property var _at: _orbiting ? pointer.anchor : _pulseAt
    property bool _pulseOn: false

    // Pixels-to-world at the pivot's depth; the rig's distance is read so the
    // ring keeps its screen size while a zoom changes the world scale.
    readonly property real _wpp: {
        if (!pointer || !pointer.rig || !pointer.view) return 0.08
        void pointer.rig.distance
        return pointer.rig.worldPerPixel(pointer.view.height)
    }

    Connections {
        target: root.pointer
        function onZoomedAt(p) { root._pulseAt = p; root._pulseOn = true; _fade.restart() }
    }

    Timer { id: _fade; interval: 300; onTriggered: root._pulseOn = false }

    LineBatch3D {
        orientation: LineBatch3D.Flat
        depthBias: 8
        lines: {
            if (!root._active || !root._at) return []
            const r = root.radiusPx * root._wpp
            const y = (root._at.y || 0) + root.liftY
            const pts = []
            for (let i = 0; i <= 48; ++i) {
                const a = i / 48 * 2 * Math.PI
                pts.push(Qt.vector3d(root._at.x + r * Math.cos(a), y,
                                     root._at.z + r * Math.sin(a)))
            }
            return [{ points: pts, color: root.tone,
                      width: 2.6 * root._wpp, styleId: 0 }]
        }
    }

    Model {
        source: "#Sphere"
        visible: root._active && !!root._at
        position: root._at ? Qt.vector3d(root._at.x, (root._at.y || 0) + root.liftY,
                                         root._at.z)
                           : Qt.vector3d(0, -1e5, 0)
        readonly property real _r: 2.6 * root._wpp
        scale: Qt.vector3d(_r / 50, _r / 50, _r / 50)
        castsShadows: false
        materials: PrincipledMaterial {
            lighting: PrincipledMaterial.NoLighting
            baseColor: root.tone
        }
    }
}
