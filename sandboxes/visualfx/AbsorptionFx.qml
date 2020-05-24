// (c) serein.pfeiffer@gmail.com - zlib license, see "LICENSE" file

import QtQuick 2.0
import QtQuick.Particles 2.0

Item {
    id: theVFX

    property alias timeToLive: destructor.interval
    Component.onCompleted: destructor.start()
    Timer {id: destructor; interval: 1500; onTriggered: theVFX.destroy()}

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
                magnitude: emitter.width
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
