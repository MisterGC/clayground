import QtQuick 2.12
import Box2D 2.0
import QtMultimedia 5.12
import QtQuick.Particles 2.0

PhysicsItem
{
    id: theAbsorbicer

    property string route: ""

    // Behavior
    property bool aiRunning: false
    property AiMap map: null
    property Waypoint destination: null
    property int wpIdx: -1
    property real maxVelo: 8
    onAiRunningChanged: {
        if (aiRunning)
            selectNextWp();
        else
            destination = null;
    }

    function selectNextWp() {
        console.log("I am thinking...")
        if (route.length > 0) {
            console.log("Go on route " + route + " map: " + map)
            let r = map.routes[route]
            wpIdx = r[wpIdx + 1] ? wpIdx + 1 : 0;
            destination = r[wpIdx];
        }
    }

    function walkToDestination() {
        if (destination) {
            let v = Qt.vector2d(destination.x - x, destination.y - y);
            let l = v.length();
            if (l > 1) {
                v = v.times(maxVelo/l);
                linearVelocity.x = v.x
                linearVelocity.y = v.y
            }
        }
        else {
            linearVelocity.x = 0;
            linearVelocity.y = 0;
        }

    }

    onDestinationChanged: walkToDestination()

    property var capturedPlayer: null
    property var absorbtionRate: 10
    Timer {
        running: capturedPlayer !== null && capturedPlayer.energy > 0
        interval: 50
        repeat: true
        onTriggered: {
            capturedPlayer.energy -= absorbtionRate;
        }
    }
    Item {
        id: absorptionEffect
        width: 2 * theRadius.radius
        height: width
        anchors.centerIn: parent
        z: 99
        visible: capturedPlayer !== null
        ParticleSystem { id: particleSystem; running: capturedPlayer !== null; }
        Emitter {
            id: emitter
            anchors.fill: parent
            system: particleSystem
            emitRate: 10
            lifeSpan: 500
            lifeSpanVariation: 50
            velocity: TargetDirection {
                targetX: emitter.width/2;
                targetY: emitter.height/2;
                magnitude: emitter.width;}
        }
        ItemParticle {
            system: particleSystem
            delegate: Rectangle {
                width: (0.5 + Math.random()) * 0.1 *absorptionEffect.width
                height: width
                color: "#3fa4c8"
            }
        }
    }
    onCapturedPlayerChanged: {
        if (capturedPlayer) absorbtionSound.play()
        else absorbtionSound.stop()
    }
    SoundEffect {
        id: absorbtionSound
        source: "energy_absorbtion.wav"
        loops: SoundEffect.Infinite
    }


    bodyType: Body.Dynamic
    Rectangle { color: "#dc3f4d"; opacity: 0.4; radius: theRadius.radius; x: theRadius.x; y: theRadius.y; width: 2*radius; height: 2*radius}
    Rectangle { color: "#dc3f4d"; anchors.fill: parent }

    Component.onCompleted: {
        //linearVelocity.y = -5
    }

    fixtures: [
        Box {
            width: theAbsorbicer.width
            height: theAbsorbicer.height
            categories: Box.Category3
            collidesWith: Box.Category1
            onBeginContact: {
                var entity = other.getBody().target;
                if (entity.route === theAbsorbicer.route) selectNextWp();
            }
        },
        Circle {
            id: theRadius
            x: -radius + theAbsorbicer.width/2
            y: -radius + theAbsorbicer.height/2
            radius: theAbsorbicer.width * 2
            collidesWith: Box.Category2
            sensor: true
            onBeginContact: {
                var entity = other.getBody().target;
                console.log("Is it the player? " + entity);
                if (entity.isPlayer) {
                    console.log("Got ya!");
                    capturedPlayer = entity;
                    theAbsorbicer.linearVelocity.x = 0;
                    theAbsorbicer.linearVelocity.y = 0;
                }
            }
            onEndContact:   {
                var entity = other.getBody().target;
                console.log("Is it the player? " + entity);
                if (entity.isPlayer) {
                    console.log("Where are you?");
                    capturedPlayer = null;
                    theAbsorbicer.walkToDestination();
                }

            }
        }
    ]
}

