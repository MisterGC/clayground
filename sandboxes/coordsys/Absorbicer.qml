import QtQuick 2.12
import Box2D 2.0

PhysicsItem
{
    id: theAbsorbicer

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
        },
        Circle {
            id: theRadius
            x: -radius + theAbsorbicer.width/2
            y: -radius + theAbsorbicer.height/2
            radius: theAbsorbicer.width * 2
            collidesWith: Box.Category2
            sensor: true
            onBeginContact: { console.log("There you are!") }
            onEndContact:   { console.log("Hmm - nobody here...") }
        }
    ]
}

