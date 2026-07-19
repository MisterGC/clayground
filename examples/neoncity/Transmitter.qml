// (c) Clayground Contributors - MIT License, see "LICENSE" file
//
// A gold antenna mast planted on a landmark / tall building. The Node itself
// sits at the mast TIP (world position), so a Connector3D linking a car to a
// transmitter draws to the glowing tip. The mast + beacon extend downward from
// the tip to the rooftop.

import QtQuick
import QtQuick3D

Node {
    id: tx

    // Distance from the rooftop up to the tip (world units).
    property real mastHeight: 44

    // Thin galvanised mast, drawn from the rooftop (-mastHeight) up to the tip.
    Model {
        source: "#Cylinder"
        scale: Qt.vector3d(0.018, tx.mastHeight / 100, 0.018)
        y: -tx.mastHeight / 2
        castsShadows: false
        receivesShadows: false
        materials: PrincipledMaterial {
            baseColor: "#8b8f95"
            metalness: 0.6
            roughness: 0.4
        }
    }

    // Aviation-style warning beacon at the tip: a small red marker with a mild
    // glow so it still reads as a link target, without the daylight-dominant
    // neon-yellow ball.
    Model {
        source: "#Sphere"
        scale: Qt.vector3d(0.05, 0.05, 0.05)
        castsShadows: false
        receivesShadows: false
        materials: PrincipledMaterial {
            baseColor: "#e0574a"
            roughness: 0.5
            emissiveFactor: Qt.vector3d(0.35, 0.06, 0.04)
        }
    }
}
