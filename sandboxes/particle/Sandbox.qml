import QtQuick 2.5
import QtQuick.Particles 2.0

Item {
    id: root
    anchors.fill: parent
    Rectangle {
    color: "black"
    anchors.centerIn: parent
    width: 100
    height: 100
    ParticleSystem { id: particleSystem; running: true }
    Emitter {
        id: emitter
        width: 6*parent.width
        height: width
        anchors.centerIn: parent
        system: particleSystem
        emitRate: 80
        lifeSpan: 500
        lifeSpanVariation: 50
        velocity: TargetDirection { targetX: emitter.width/2; targetY: emitter.height/2; magnitude: 200;}
    }
    ItemParticle {
        system: particleSystem
        delegate: Rectangle {
            width: root.width/20 + Math.random() * root.width/20
            height: width
            color: "grey"
        }
    }
    }
}
