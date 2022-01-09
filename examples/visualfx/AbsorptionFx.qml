// (c) Clayground Contributors - zlib license, see "LICENSE" file

import QtQuick
import QtQuick.Particles

Item {
    id: theVFX

    // Time a particle needs from out boundary to absorption center
    property alias msFromBoundaryToCenter: emitter.lifeSpan
    property alias particlesPerSecond: emitter.emitRate

    ParticleSystem {
        anchors.fill: parent
        Emitter {
            id: emitter
            width: parent.width
            height: width
            anchors.centerIn: parent
            emitRate: 100
            lifeSpan: 500
            velocity: TargetDirection {
                targetX: emitter.width * .5
                targetY: emitter.height * .5
                magnitude: 1000.0 / emitter.lifeSpan
                proportionalMagnitude: true
            }
        }
        ItemParticle {
            delegate: Rectangle {
                width: theVFX.width/30 + Math.random() * theVFX.width/20
                height: width
                color: Qt.rgba(Math.random() * 0.5,
                               0.85,
                               1.0,
                               .4 + .3 *Math.random())
            }
        }
    }

}
