import QtQuick 2.12
import Box2D 2.0
import Clayground.SvgUtils 1.0
import Clayground.ScalingCanvas 1.0
import Clayground.GameController 1.0

CoordCanvas {
    id: gameWorld
    anchors.fill: parent
    pixelPerUnit: 50
    World {
        id: physicsWorld
        gravity: Qt.point(0,0)
        timeStep: 1/60.0
        pixelsPerMeter: pixelPerUnit
    }

    property var player: null

    Keys.forwardTo: gameCtrl
    GameController {
        id: gameCtrl
        anchors.fill: parent
        Component.onCompleted: {
            selectKeyboard(Qt.Key_Up, Qt.Key_Down, Qt.Key_Left, Qt.Key_Right, Qt.Key_A, Qt.Key_S);
        }

        onAxisXChanged: {
            if (axisX > 0) player.moveRight();
            else if (axisX < 0) player.moveLeft();
            else { player.stopLeft(); player.stopRight();}
        }
        onAxisYChanged: {
            if (axisY > 0) player.moveUp();
            else if (axisY < 0) player.moveDown();
            else { player.stopUp(); player.stopDown();}
        }
    }

    SvgInspector
    {
        id: theSvgInspector
        property var objs: []

        Component.onCompleted: setSource(ClayLiveLoader.sandboxDir + "/map.svg")

        onBegin: {
            gameWorld.viewPortCenterWuX = 0;
            gameWorld.viewPortCenterWuY = 0;
            gameWorld.worldXMax = widthWu;
            gameWorld.worldYMax = heightWu;
            player = null;
            for (let obj of objs) obj.destroy();
            objs = [];
        }

        onRectangle: {
            let cfg = JSON.parse(description);
            let compStr = cfg["component"];
            let comp = Qt.createComponent(compStr);
            var obj = comp.createObject(coordSys, {world: physicsWorld, xWu: x, yWu: y, widthWu: width, heightWu: height, color: "black"});
            obj.pixelPerUnit = Qt.binding(function() {return gameWorld.pixelPerUnit;});
            objs.push(obj);
            if (compStr === "Player.qml") {
                gameWorld.player = obj;
                gameWorld.viewPortCenterWuX = Qt.binding( _ => {return gameWorld.screenXToWorld(gameWorld.player.x);} );
                gameWorld.viewPortCenterWuY = Qt.binding( _ => {return gameWorld.screenYToWorld(gameWorld.player.y);} );
            }
        }

    }
}
