// (c) serein.pfeiffer@gmail.com - zlib license, see "LICENSE" file

import QtQuick 2.15
import QtQuick.Shapes 1.14
import QtQuick.Controls 2.15
import Box2D 2.0
import Clayground.Physics 1.0
import Clayground.Canvas 1.0 as Canv
import Clayground.World 1.0

Rectangle {
    id: behavior

    transformOrigin: Item.Center
    width: 3
    height: width
    visible: debug

    required property ClayWorld world
    property var actor: parent
    property alias running: _veloAdaptor.running
    onRunningChanged: _adaptVelocity()

    property real destXWu: 0
    property real destYWu: 0

    property real desiredSpeed: 2
    property var _destWp: null
    property var _detector: null

    readonly property int _collCatWpDetect: Box.Category15
    readonly property int _collCatWp: Box.Category16

    signal arrived();

    WorldChangedConnections { world: behavior.world; callback: behavior._adaptConfiguration}

    onDestXWuChanged: _adaptConfiguration()
    onDestYWuChanged: _adaptConfiguration()
    onActorChanged: { if (!actor) return; _adaptConfiguration(); }

    property bool debug: false
    property color debugColor: "lightblue"
    Component{id: connector; Canv.Connector{parent: world.room; from: actor; to: _destWp; opacity: .8;  color: behavior.debugColor; strokeWidth: 5}}
    Loader {sourceComponent: debug ? connector : null}

    Component {
        id: waypointComp
        RectTrigger {
            z: 99
            pixelPerUnit: behavior.world.pixelPerUnit
            transformOrigin: Item.Center
            categories: behavior._collCatWp
            collidesWith: behavior._collCatWpDetect
            visible: behavior.debug; color: "transparent"
            Loader{id: wpDebug; anchors.centerIn: parent; sourceComponent: behavior.debug ? wpVisuComp : null}
            Component{ id: wpVisuComp;
            Rectangle{opacity: .75; radius: height * .5; anchors.centerIn: parent; width: 20; height: width; color: Qt.darker(behavior.debugColor, 1.5)
                Text{anchors.centerIn: parent; font.bold: true; color: Qt.lighter(behavior.debugColor, 5); font.pixelSize: parent.height * .9; text: behavior.running ? "x" : "!"}}
            }
        }
    }

    Component {
        id: wpDetectComp
        Box {
            x: behavior.x; y: behavior.y
            width: behavior.width; height: behavior.height
            categories: behavior._collCatWpDetect
            collidesWith: behavior._collCatWp
            sensor: true
        }
    }

    Component.onCompleted: {_adaptConfiguration()}

    function _adaptConfiguration() {
        if (!world  || !world.room  || !actor) return;

        if (waypointComp.status !== Component.Ready) return;
        if (!_detector){
            _detector = wpDetectComp.createObject(actor,{});
            actor.body.addFixture(_detector);
        }

        if (!_destWp){;
            _destWp = waypointComp.createObject(behavior.world.room);
            _destWp.xWu = Qt.binding(_ => {return behavior.destXWu - (width/pixelPerUnit) * .5});
            _destWp.yWu = Qt.binding(_ => {return behavior.destYWu +  (height/pixelPerUnit) * .5});
            _destWp.width= Qt.binding(_ => {return behavior.width;});
            _destWp.height= Qt.binding(_ => {return behavior.height;});

            ClayPhysics.connectOnEntered(_destWp.body.fixtures[0], (wpDetect) => {
                                        if (wpDetect === actor) {
                                            actor.linearVelocity.x = 0;
                                            actor.linearVelocity.y = 0;
                                            arrived();
                                        }
                                    });
        }

    }

    Timer{id: _veloAdaptor; interval: 100; repeat: true; onTriggered: _adaptVelocity() }

    function _adaptVelocity(){
        if (!behavior.running) {
            actor.linearVelocity.x = 0.;
            actor.linearVelocity.y = 0.;
            return;
        }
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
