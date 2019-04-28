import QtQuick 2.12
import Box2D 2.0

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
                console.log("Contact with " + entity + " route: " + entity.route);
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
                    theAbsorbicer.linearVelocity.x = 0;
                    theAbsorbicer.linearVelocity.y = 0;
                }
            }
            onEndContact:   {
                var entity = other.getBody().target;
                console.log("Is it the player? " + entity);
                if (entity.isPlayer) {
                    console.log("Where are you?");
                    theAbsorbicer.walkToDestination();
                }

            }
        }
    ]
}

