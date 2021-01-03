// (c) serein.pfeiffer@gmail.com - zlib license, see "LICENSE" file

import QtQuick 2.15
import QtQuick.Shapes 1.14
import Box2D 2.0
import Clayground.Physics 1.0
import Clayground.Canvas 1.0 as Canv
import Clayground.World 1.0
import "utils.js" as BUtils

Rectangle {
    id: behavior

    transformOrigin: Item.Center
    width: .1 * actor.width
    height: width

    required property ClayWorld world
    property var actor: parent
    visible: true

    property real destXWu: 0
    property real destYWu: 0

    property int desiredSpeed: 10
    property var _destWp: null
    property var _detector: null

    readonly property int collCatWpDetect: Box.Category15
    readonly property int collCatWp: Box.Category16

    signal arrived();

//    Connections{
//        target: world;
//        function onPixelPerUnitChanged(){start()}
//        function onXWuMinChanged(){start()}
//        function onXWuMaxChanged(){start()}
//        function onYWuMinChanged(){start()}
//        function onYWuMaxChanged(){start()}
//    }
    onDestXWuChanged: start()
    onDestYWuChanged: start()
    onActorChanged: {
        if (!actor) return;
        start();
    }

    property bool visualize: true
    Component{id: connector; Canv.Connector{color: "lightblue"; strokeWidth: 5}}

    Component {
        id: waypointComp
        RectTrigger {
            pixelPerUnit: behavior.world.pixelPerUnit
            transformOrigin: Item.Center
            categories: behavior.collCatWp
            collidesWith: behavior.collCatWpDetect
            visible: true; color: "black"
            onWidthChanged: console.log("w: " + width)
            onXChanged: console.log("x: " + x)
            onYChanged: console.log("y: " + y)
            onHeightChanged: console.log("h: " + height)
        }
    }

    Component {
        id: wpDetectComp
        Box {
            x: behavior.x; y: behavior.y
            width: behavior.width; height: behavior.height
            categories: behavior.collCatWpDetect
            collidesWith: behavior.collCatWp
            sensor: true
        }
    }

    Component.onCompleted: start()

    function start() {
        if (!world  || !world.room) return;

        if (!_destWp){
            behavior._destWp = waypointComp.createObject(behavior.world.room,
                                                {
                                                    xWu: Qt.binding(_ => {return behavior.destXWu + actor.widthWu * .5}),
                                                    yWu: Qt.binding(_ => {return behavior.destYWu + actor.heightWu * .5}),
                                                    width: Qt.binding(_ => {return behavior.width;}),
                                                    height: Qt.binding(_ => {return behavior.height;})
                                                }
                                                );
            _destWp.xWu = Qt.binding(_ => {return behavior.destXWu + actor.widthWu * .5});
            _destWp.yWu = Qt.binding(_ => {return behavior.destYWu + actor.heightWu * .5});
            _destWp.x = Qt.binding(_ => {return world.xToScreen(behavior._destWp.xWu)});
            _destWp.y = Qt.binding(_ => {return world.yToScreen(behavior._destWp.yWu)});
            connector.createObject(world.room, {from: actor, to: _destWp})
            BUtils.connectOnEntered(_destWp.body.fixtures[0], (wpDetect) => {
                                        if (wpDetect === actor) {
                                            actor.linearVelocity.x = 0;
                                            actor.linearVelocity.y = 0;
                                            arrived();
                                        }
                                    });
        }

        if (!_detector){
            _detector = wpDetectComp.createObject(actor,{});
            actor.body.addFixture(_detector);
        }
        _adaptVelocity();
    }

    Timer{interval: 100; repeat: true; running: true; onTriggered: _adaptVelocity() }

    function _adaptVelocity(){
        if (!_destWp) return;
        let bCoords = mapFromItem(parent, x, y)
        let wpCoords = mapFromItem(_destWp.parent, _destWp.x, _destWp.y)

        let dX = wpCoords.x  - bCoords.x;
        let dY = wpCoords.y - bCoords.y;
        let v = Qt.vector2d(dX, dY);
        let l = v.length();
        if (l > 1) {
            v = v.times(desiredSpeed/l);
            actor.linearVelocity.x = v.x;
            actor.linearVelocity.y = v.y;
        }
    }

}
