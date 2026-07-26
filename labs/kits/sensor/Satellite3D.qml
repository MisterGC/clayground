// (c) Clayground Contributors - MIT License, see "LICENSE" file

import QtQuick
import QtQuick3D
import Clayground.Canvas3D
import Clayground.Lab

// A satellite you recognise at a glance: a body, two solar wings and a dish
// aimed at whoever it is talking to. Deliberately schematic - it is the icon
// of a spacecraft, not a model of one - but the dish really does track the
// receiver, so "who is talking to whom" is readable from any angle.
Node {
    id: root

    // Nothing up here casts. A spacecraft tens of units above the scene would
    // otherwise drop a blot on the city, and - worse - the drifting
    // constellation re-fits the shadow volume every frame, which shows up as
    // the whole city's shadows flickering. The sky is lit, not lighting.

    /*! Whether the receiver currently has line of sight (drives the colour). */
    property bool linked: true
    /*! World point the dish points at. */
    property vector3d target: Qt.vector3d(0, 0, 0)
    /*! 0..1, briefly 1 when a fix is computed. */
    property real pulse: 0
    /*! Overall size multiplier. */
    property real size: 1.0

    readonly property color accent: linked ? LabTheme.primary : LabTheme.muted

    // body: a bright box with ink edges, so it reads against the paper sky
    Box3D {
        castsShadows: false
        width: 1.5 * root.size; height: 1.0 * root.size; depth: 1.0 * root.size
        y: -0.5 * root.size
        color: root.linked ? LabTheme.panel : LabTheme.paperDeep
        useToonShading: true
        edgeColorFactor: 0.5
    }

    // solar wings: the one detail that makes the silhouette unmistakable
    Repeater3D {
        model: [-1, 1]
        Box3D {
            castsShadows: false
            required property var modelData
            width: 2.0 * root.size; height: 0.08 * root.size; depth: 0.85 * root.size
            x: modelData * 1.85 * root.size
            y: -0.04 * root.size
            color: root.accent
            useToonShading: true
        }
    }
    // the boom each wing sits on
    Repeater3D {
        model: [-1, 1]
        Box3D {
            castsShadows: false
            required property var modelData
            width: 0.9 * root.size; height: 0.08 * root.size; depth: 0.08 * root.size
            x: modelData * 1.05 * root.size
            y: -0.04 * root.size
            color: LabTheme.inkFaint
            useToonShading: true
        }
    }

    // dish, on a short mast, aimed at the receiver
    Node {
        eulerRotation: {
            const dx = root.target.x - root.scenePosition.x
            const dy = root.target.y - root.scenePosition.y
            const dz = root.target.z - root.scenePosition.z
            const yaw = Math.atan2(dx, dz) * 180 / Math.PI
            const horiz = Math.sqrt(dx * dx + dz * dz)
            const pitch = Math.atan2(dy, horiz) * 180 / Math.PI
            return Qt.vector3d(pitch + 90, yaw, 0)
        }
        Model {   // mast
            castsShadows: false
            source: "#Cylinder"
            position: Qt.vector3d(0, -0.05 * root.size, 0)
            scale: Qt.vector3d(0.0012 * root.size, 0.006 * root.size, 0.0012 * root.size)
            materials: PrincipledMaterial {
                baseColor: LabTheme.inkFaint; lighting: PrincipledMaterial.NoLighting
            }
        }
        Model {   // dish
            castsShadows: false
            source: "#Cone"
            position: Qt.vector3d(0, -0.75 * root.size, 0)
            eulerRotation.x: 180
            scale: Qt.vector3d(0.009 * root.size, 0.005 * root.size, 0.009 * root.size)
            materials: PrincipledMaterial {
                lighting: PrincipledMaterial.NoLighting
                baseColor: root.accent
                emissiveFactor: root.linked
                    ? Qt.vector3d(0.35 * root.pulse, 0.5 * root.pulse, 0.8 * root.pulse)
                    : Qt.vector3d(0, 0, 0)
            }
        }
    }
}
