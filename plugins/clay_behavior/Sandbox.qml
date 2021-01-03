// (c) serein.pfeiffer@gmail.com - zlib license, see "LICENSE" file

import QtQuick 2.12
import Box2D 2.0
import Clayground.Canvas 1.0 as Canv
import Clayground.GameController 1.0
import Clayground.Physics 1.0
import Clayground.World 1.0


ClayWorld
{
    id: world
    pixelPerUnit: width / 20
    xWuMin: 0; xWuMax: 20
    yWuMin: 0; yWuMax: 20
    gravity: Qt.point(0,0)

    RectBoxBody {
        id: player; color: "orange"; bodyType: Body.Dynamic
        xWu: 10; yWu: 10; widthWu: 1; heightWu: 1
        linearVelocity.x: ctrl.axisX * 10; linearVelocity.y: -ctrl.axisY * 10; }


    RectBoxBody {
        id: enemy
        color: "transparent"; sensor:true;
        xWu: 5; yWu: 5;
        widthWu: 1; heightWu: 1;
        bodyType: Body.Kinematic
    MoveTo {actor: enemy;  anchors.centerIn: actor; destXWu: 12; destYWu: 12
    onArrived: {destXWu = Math.random() * 2  + 1; destYWu = Math.random() * 2 + 1;}}
    }


    // Borders of the world
    RectBoxBody {color: "green"; xWu: 0; yWu: 20; widthWu: 1; heightWu: 20}
    RectBoxBody {color: "green"; xWu: 0; yWu: 20; widthWu: 20; heightWu: 1}
    RectBoxBody {color: "green"; xWu: 19; yWu: 20; widthWu: 1; heightWu: 20}
    RectBoxBody {color: "green"; xWu: 0; yWu: 1; widthWu: 20; heightWu: 1}
    Canv.Text{parent: player.parent;
        anchors.horizontalCenter: player.horizontalCenter;
        anchors.bottom: player.top;
        text: "Hi";
        fontSizeWu: .5}
    physicsDebugging: true


    Keys.forwardTo: ctrl
    GameController {id: ctrl; anchors.fill: parent; Component.onCompleted: selectKeyboard(Qt.Key_W, Qt.Key_S, Qt.Key_A, Qt.Key_D, Qt.Key_J, Qt.Key_K); }
}
