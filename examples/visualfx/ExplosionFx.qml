// (c) Clayground Contributors - zlib license, see "LICENSE" file

import QtQuick
import QtQuick.Particles

Item {
    id: theVFX

    // In how many parts does the thing break apart?
    property int numParts: 100
    property real partBaseSize: width / Math.sqrt(numParts)

    signal finished()

    ParticleSystem {
        anchors.centerIn: parent

        Component.onCompleted: emitter.burst(theVFX.numParts)
        Emitter {
            id: emitter
            enabled: false
            anchors.centerIn: parent
            lifeSpan: 600
            velocity: AngleDirection{
                magnitude: theVFX.width * 5
                magnitudeVariation: magnitude * .3
                angleVariation: 360
            }
        }
        ItemParticle {
            delegate: Rectangle {
                width: theVFX.partBaseSize +
                       Math.random() * (theVFX.partBaseSize * .25)
                height: width
                readonly property real r: 0.3 + Math.random() * .7
                color: Qt.rgba(r, .5 * r, 0, 1)
                rotation: Math.random() * 360
            }
        }
    }

    Image {
        id: smoke

        opacity: 0.75
        source: "explosion.png"
        anchors.centerIn: parent
        width: parent.width * .1
        height: width

        readonly property real time: emitter.lifeSpan * .45

        SequentialAnimation {
            running: true
            ParallelAnimation {
                NumberAnimation { target: smoke; property: "width"; duration: smoke.time; to: theVFX.width ;}
                NumberAnimation { target: smoke; property: "height"; duration: smoke.time; to: theVFX.height;}
                NumberAnimation { target: smoke; property: "opacity"; duration: smoke.time; to: 0.5; }
            }
            NumberAnimation { target: smoke; property: "opacity"; duration: smoke.time * 3; to: 0; }
            onRunningChanged: if (!running) theVFX.finished()
        }
    }
}
