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
    pixelPerUnit: width / 20
    xWuMin: 0; xWuMax: 20
    yWuMin: 0; yWuMax: 20
    gravity: Qt.point(0,0)
    //running: true
    //physicsDebugging: true

    // Multi-sampe antialiasing
    // layer.enabled: true
    // layer.samples: 4

    function rndCoord() {return Math.random() * 16 + 2;}
    function rndPath(count) {
        let wps = [];
        for (let i=0; i<count; ++i)
            wps.push({x: rndCoord(), y:rndCoord()})
        return wps;
    }

    RectBoxBody {
        id: player; color: "orange"; bodyType: Body.Dynamic
        xWu: 10; yWu: 10; widthWu: 1; heightWu: 1
        linearVelocity.x: ctrl.axisX * 10; linearVelocity.y: -ctrl.axisY * 10;
        Canv.Text{parent: player.parent;
            anchors.horizontalCenter: player.horizontalCenter;
            anchors.bottom: player.top;
            text: "Hello ClayWorld!";
            font.bold: true
            fontSizeWu: .5}
    }

    Repeater{
        model: 10
        RectBoxBody {
            color: Qt.hsla(.3, .5, .1 + Math.random() * .7, 1)
            xWu: rndCoord(); yWu: rndCoord()
            widthWu: .5 + Math.random() * .5; heightWu: widthWu;
            bodyType: Body.Kinematic; sensor: true;
            MoveTo {
                world: theWorld; anchors.centerIn: parent;
                destXWu: theWorld.rndCoord(); destYWu: theWorld.rndCoord()
                running: true; onArrived: {destXWu = theWorld.rndCoord(); destYWu = theWorld.rndCoord();}
                debug: true; debugColor: parent.color
            }
        }
    }

    Repeater{
        model: 3
        RectBoxBody {
            color: Qt.hsla(.9, .2, .1 + Math.random() * .7, 1)
            function rndCoord() {return Math.random() * 16 + 2;}
            xWu: rndCoord(); yWu: rndCoord()
            widthWu: .5 + Math.random() * .5; heightWu: widthWu;
            bodyType: Body.Kinematic; sensor: true;
            FollowPath{debug: true; debugColor:parent.color ; world: theWorld; anchors.centerIn: parent; repeat: true; running: true; wpsWu: rndPath(4)}
        }
    }

    // Borders of the world
    RectBoxBody {color: "green"; xWu: 0; yWu: 20; widthWu: 1; heightWu: 20}
    RectBoxBody {color: "green"; xWu: 0; yWu: 20; widthWu: 20; heightWu: 1}
    RectBoxBody {color: "green"; xWu: 19; yWu: 20; widthWu: 1; heightWu: 20}
    RectBoxBody {color: "green"; xWu: 0; yWu: 1; widthWu: 20; heightWu: 1}

    Keys.forwardTo: ctrl
    GameController {id: ctrl; anchors.fill: parent;
    Component.onCompleted: selectKeyboard(Qt.Key_W, Qt.Key_S, Qt.Key_A, Qt.Key_D, Qt.Key_J, Qt.Key_K); }
}
