// (c) serein.pfeiffer@gmail.com - zlib license, see "LICENSE" file

import QtQuick 2.15
import Box2D 2.0
import Clayground.Common 1.0
import Clayground.GameController 1.0
import Clayground.Physics 1.0

Item {
    anchors.fill: parent

    component Wall: RectBoxBody {
        color: "#7084aa"
        bodyType: Body.Static; categories: Box.Category1
        collidesWith: Box.Category2 | Box.Category3
    }

    component WoodenBox:  RectBoxBody {
        color: Qt.hsla(.1, .8, Math.random() * .9, 1)
        xWu: randomIn(10, 50); yWu: randomIn(10, 90)
        widthWu: 2; heightWu: 2
        bodyType: Body.Dynamic;
        categories: Box.Category3; collidesWith: Box.Category1 | Box.Category2 | Box.Category3
        function randomIn(min, max){ return Math.round(min + Math.random() * (max-min)); }
    }

    ClayWorld {
        id: someWorld

        anchors.fill: parent
        pixelPerUnit: width / (someWorld.xWuMax - someWorld.xWuMin)
        gravity: Qt.point(0,0); timeStep: 1/60.0

        // Load a map using an svg file - Clayground supports setting properties via
        // JSON data in descriptions of SVG elements (supported by Inkscape for example)
        map: "map.svg"
        components: new Map([ ['WoodenBox', c1], ['Wall', c2] ])
        Component { id: c1; WoodenBox {} }
        Component { id: c2; Wall {} }

        // Don't set the parent -> it will only be automatically added to the space if
        // it's an instance of a known Clayground.Physics component
        Repeater {model: 10; WoodenBox{}}
        WoodenBox{color: "lightgreen"}
        // Explicitly set the parent and use whichever component is suitable, but be
        // aware that pixelPerUnit and physics world are modified if present
        RectBoxBody {parent: someWorld.room; xWu: 50; yWu: 50; widthWu: 8; heightWu: 8; color: "orange"}
    }

    Minimap {
        id: minimap
        color: "black"; opacity: 0.9
        world: someWorld
        width: parent.width * 0.2; height: width * (world.room.height / world.room.width)
        anchors.right: parent.right; anchors.rightMargin: width * 0.1
        anchors.bottom: parent.bottom; anchors.bottomMargin: anchors.rightMargin
        typeMapping: new Map([['Wall', mc1], ['WoodenBox', mc2]])
        Component {id: mc1; Rectangle {color: "#7084aa"}}
        Component {id: mc2; Rectangle {color: "orange"}}
    }
}
