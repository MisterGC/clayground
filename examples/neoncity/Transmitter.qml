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

    // Thin mast, drawn from the rooftop (-mastHeight) up to the tip (0).
    Model {
        source: "#Cylinder"
        scale: Qt.vector3d(0.018, tx.mastHeight / 100, 0.018)
        y: -tx.mastHeight / 2
        castsShadows: false
        receivesShadows: false
        materials: PrincipledMaterial {
            baseColor: "#ffd93d"
            metalness: 0.6
            roughness: 0.4
            emissiveFactor: Qt.vector3d(0.35, 0.30, 0.05)
        }
    }

    // Glowing beacon at the tip.
    Model {
        source: "#Sphere"
        scale: Qt.vector3d(0.06, 0.06, 0.06)
        castsShadows: false
        receivesShadows: false
        materials: PrincipledMaterial {
            lighting: PrincipledMaterial.NoLighting
            baseColor: "#ffd93d"
        }
    }
}
