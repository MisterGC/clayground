// (c) serein.pfeiffer@gmail.com - zlib license, see "LICENSE" file

import QtQuick 2.12
import Box2D 2.0
import Clayground.Canvas 1.0 as Canv
import Clayground.GameController 1.0
import Clayground.Physics 1.0
import Clayground.World 1.0

ClayWorld
{
    id: theWorld
    anchors.fill: parent
    pixelPerUnit: height / theWorld.yWuMax
    gravity: Qt.point(0,0)
    map: "map.svg"

    function rndCoord() {return Math.random() * 16 + 2;}

    onMapLoaded: observedItem = player

    // How to put together keyboard controls with physics movement?
    RectBoxBody {
        id: player; color: "orange"; bodyType: Body.Dynamic
        xWu: 10; yWu: 10; widthWu: .9; heightWu: widthWu
        linearVelocity.x: ctrl.axisX * 10; linearVelocity.y: -ctrl.axisY * 10;
        Canv.Text{parent: player.parent;
            anchors.horizontalCenter: player.horizontalCenter;
            anchors.bottom: player.top;
            text: "Player";
            font.bold: true
            fontSizeWu: .5}
    }

    // Move entities randomly arround within a limited area
    Repeater{
        model: 1
        RectBoxBody {
            color: "#92dfbd"
            xWu: theWorld.rndCoord(); yWu: theWorld.rndCoord(); widthWu: .9; heightWu: widthWu;
            bodyType: Body.Kinematic; sensor: true;
            MoveTo {
                world: theWorld; anchors.centerIn: parent;
                destXWu: theWorld.rndCoord(); destYWu: theWorld.rndCoord()
                running: true; onArrived: {destXWu = theWorld.rndCoord(); destYWu = theWorld.rndCoord();}
                debug: true; debugColor: parent.color
            }
        }
    }

    // One entity follows a path
    RectBoxBody {
        id: pathFollower
        property alias path: _followP.wpsWu
        color: "#de8787"
        xWu: theWorld.rndCoord(); yWu: theWorld.rndCoord(); widthWu: .9; heightWu: widthWu;
        bodyType: Body.Kinematic; sensor: true;
        FollowPath{
            id: _followP; debug: true; debugColor: parent.color ; world: theWorld;
            anchors.centerIn: parent; repeat: true; running: true; wpsWu: theWorld.path
        }
    }

    components: new Map([ ['Wall', c1] ])
    Component {id: c1; RectBoxBody { color: "#333333";  } }
    property var path: []
    onPolylineLoaded: {console.log("points: " + points); if (description === "PatrolPath") pathFollower.path=points;}

    Keys.forwardTo: ctrl
    GameController {id: ctrl; anchors.fill: parent;
    Component.onCompleted: selectKeyboard(Qt.Key_W, Qt.Key_S, Qt.Key_A, Qt.Key_D, Qt.Key_J, Qt.Key_K); }
}
