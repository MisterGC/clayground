import QtQuick 2.12
import "qrc:/" as LivLd
import Box2D 2.0
import SvgUtils 1.0
import ScalingCanvas 1.0
import Clayground.GameController 1.0

CoordCanvas
{
    id: gameWorld
    anchors.fill: parent
    pixelPerUnit: width / gameWorld.worldXMax

    Component.onCompleted: {
        ReloadTrigger.observeFile("JnRPlayer.qml");
        ReloadTrigger.observeFile("Player.qml");
    }

    World {
        id: physicsWorld
        gravity: Qt.point(0,4*9.81)
        timeStep: 1/60.0
        pixelsPerMeter: pixelPerUnit
    }

//    DebugDraw {
//        anchors.fill: parent
//        parent: gameWorld.coordSys
//    }

    property var player: null
    Keys.forwardTo: gameCtrl
    GameController {
        id: gameCtrl
        showDebugOverlay: false
        anchors.fill: parent
        onButtonBPressedChanged: {
            if (buttonBPressed) player.jump();
        }

        Component.onCompleted: {
            //selectGamepad(0)
            selectKeyboard(Qt.Key_Up, Qt.Key_Down, Qt.Key_Left, Qt.Key_Right, Qt.Key_A, Qt.Key_S);
            player.desireX = Qt.binding(function() {return gameCtrl.axisX;});
        }
    }

    property int count: 0

    SvgInspector
    {
        id: theSvgInspector
        property var objs: []

        Component.onCompleted: theSvgInspector.setPathToFile("/home/mistergc/dev/clayground/sandboxes/jump_n_run/map.svg")
        onBegin: {
            player = null;
            while(objs.length > 0) {
                var obj = objs.pop();
                obj.destroy();
            }
            gameWorld.worldXMax = widthWu;
            gameWorld.worldYMax = heightWu;
        }
        onBeginGroup: {console.log("beginGroup");}
        onRectangle: {
            let cfg = JSON.parse(description);
            var comp = Qt.createComponent(cfg["component"]);
            var obj = comp.createObject(coordSys, {
                                            "xWu": xWu,
                                            "yWu": yWu,
                                            "widthWu": widthWu,
                                            "heightWu": heightWu,
                                            "color": "black"
                                            });
            obj.pixelPerUnit = Qt.binding(function() {return gameWorld.pixelPerUnit;});
            objs.push(obj);
            if (cfg["component"] === "Player.qml") {
                player = obj;
                gameWorld.viewPortCenterWuX = Qt.binding(function() {return gameWorld.screenXToWorld(player.x);});
                gameWorld.viewPortCenterWuY = Qt.binding(function() {return gameWorld.screenYToWorld(player.y);});
                player.maxXVelo = 5;
            }
        }
        onCircle: {
            console.log("onCircle");
            /* Add logic to process circles */ }
        onEnd: { }
    }
}
