// (c) Clayground Contributors - MIT License, see "LICENSE" file

import QtQuick
import QtQuick.Shapes
import QtQuick.Controls
import Box2D
import Clayground.Physics
import Clayground.Canvas as Canv
import Clayground.World

/*!
    \qmltype MoveTo
    \inqmlmodule Clayground.Behavior
    \brief Moves an actor entity to a specified destination using physics.

    MoveTo provides physics-based movement of an entity toward a target
    position. It uses velocity adjustments to smoothly move the actor
    and detects arrival using collision sensors.

    Example usage:
    \qml
    import Clayground.Behavior

    RectBoxBody {
        id: enemy

        MoveTo {
            world: theWorld
            destXWu: player.xWu
            destYWu: player.yWu
            running: true
            desiredSpeed: 3
            onArrived: console.log("Reached target!")
        }
    }
    \endqml
*/
Rectangle {
    id: behavior

    transformOrigin: Item.Center
    width: 3
    height: width
    visible: debug

    /*!
        \qmlproperty ClayWorld2d MoveTo::world
        \brief The world context (required).
    */
    required property ClayWorld2d world

    /*!
        \qmlproperty var MoveTo::actor
        \brief The entity to move (defaults to parent).
    */
    property var actor: parent

    /*!
        \qmlproperty bool MoveTo::running
        \brief Whether movement is active.
    */
    property alias running: _veloAdaptor.running
    onRunningChanged: _adaptVelocity()

    /*!
        \qmlproperty real MoveTo::destXWu
        \brief Destination X coordinate in world units.
    */
    property real destXWu: 0

    /*!
        \qmlproperty real MoveTo::destYWu
        \brief Destination Y coordinate in world units.
    */
    property real destYWu: 0

    /*!
        \qmlproperty real MoveTo::desiredSpeed
        \brief Movement speed in world units per second (default: 2).
    */
    property real desiredSpeed: 2
    property var _destWp: null
    property var _detector: null

    readonly property int _collCatWpDetect: Box.Category15
    readonly property int _collCatWp: Box.Category16

    /*!
        \qmlsignal MoveTo::arrived()
        \brief Emitted when the actor reaches the destination.
    */
    signal arrived();

    WorldChangedConnections { world: behavior.world; callback: behavior._adaptConfiguration}

    onDestXWuChanged: _adaptConfiguration()
    onDestYWuChanged: _adaptConfiguration()
    onActorChanged: { if (!actor) return; _adaptConfiguration(); }

    /*!
        \qmlproperty bool MoveTo::debug
        \brief Show debug visualization of destination.
    */
    property bool debug: false

    /*!
        \qmlproperty color MoveTo::debugColor
        \brief Color for debug visualization (default: "lightblue").
    */
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

    function _adaptConfiguration() {
        if (!world  || !world.room  || !actor) return;

        if (waypointComp.status !== Component.Ready) return;
        if (!_detector){
            _detector = wpDetectComp.createObject(actor,{});
            actor.body.addFixture(_detector);
        }

        if (!_destWp){
            _destWp = true;
            _destWp = waypointComp.createObject(behavior.world.room);

            PhysicsUtils.connectOnEntered(_destWp.body.fixtures[0], (wpDetect) => {
                                        if (wpDetect === actor) {
                                            actor.linearVelocity.x = 0;
                                            actor.linearVelocity.y = 0;
                                            arrived();
                                        }
                                    });
        }

        _destWp.xWu = behavior.destXWu;
        _destWp.yWu = behavior.destYWu;
        _destWp.width = behavior.width;
        _destWp.height = behavior.height;
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
        if (l > 4) {
            v = v.times(desiredSpeed/l);
            actor.linearVelocity.x = v.x;
            actor.linearVelocity.y = v.y;
        }
    }

}
