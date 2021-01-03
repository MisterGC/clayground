// (c) serein.pfeiffer@gmail.com - zlib license, see "LICENSE" file

import QtQuick 2.15
import QtQuick.Shapes 1.14
import Box2D 2.0
import Clayground.Physics 1.0
import Clayground.Canvas 1.0
import "utils.js" as BUtils

RectBoxBody {
    id: behavior

    transformOrigin: Item.Center
    parent: actor.parent
    required property var actor
    widthWu: .1 * actor.widthWu
    heightWu: widthWu
    property real destXWu: 0
    property real destYWu: 0

    property int desiredSpeed: 2
    property var _destWp: null

    categories: Box.Category15
    collidesWith: Box.Category16
    bodyType: Body.Dynamic
    bullet: true

    signal arrived();

    onDestXWuChanged: start()
    onDestYWuChanged: start()
    onActorChanged: {
        if (!actor) return;
        if ("world" in actor) world = Qt.binding(_ => {return actor.world;})
        if ("pixelPerUnit" in actor) pixelPerUnit = Qt.binding(_ => {return actor.pixelPerUnit;})
        start();
    }

    property bool visualize: true
    Component{id: connector; Connector{
            z:-1; color: "red"; opacity: .75; style: ShapePath.DashLine; strokeWidth: 5
            from: behavior; to: parent}}

    Component {
        id: waypointComp
        RectTrigger {
            transformOrigin: Item.Cente; bullet: true;
            categories: behavior.collidesWith; collidesWith: behavior.categories;
        }
    }
    Component.onDestruction: if (_destWp) _destWp.destroy();

    function start() {
        if (!actor) return;
        if (_destWp) _destWp.destroy();
        let p = actor.parent;
        _destWp = waypointComp.createObject(p,
                                            {xWu: behavior.destXWu + actor.widthWu * .5,
                                             yWu: behavior.destYWu + actor.heightWu * .5,
                                             widthWu: behavior.widthWu,
                                             heightWu: behavior.heightWu
                                            });
        BUtils.connectOnEntered(_destWp.body.fixtures[0], (wpDetect) => {
                                    if (wpDetect === behavior) {
                                        actor.linearVelocity.x = 0;
                                        actor.linearVelocity.y = 0;
                                        _destWp.destroy();
                                        _destWp = null;
                                        arrived();
                                    }
                                });
        connector.createObject(p, {from: behavior, to: _destWp})
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
