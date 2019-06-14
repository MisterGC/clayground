import QtQuick 2.12
import "qrc:/" as LivLd
import Box2D 2.0
import SvgUtils 1.0
import Clayground.ScalingCanvas 1.0

CoordCanvas
{
    id: gameWorld
    anchors.fill: parent
    pixelPerUnit: 50

    World {
        id: physicsWorld
        gravity: Qt.point(0,0)
        timeStep: 1/60.0
        pixelsPerMeter: pixelPerUnit
    }

//    DebugDraw {
//        anchors.fill: parent
//        parent: gameWorld.coordSys
//    }

    property var player: null
    onKeyPressed: {
        if (player) {
            if (event.key === Qt.Key_Up) player.moveUp();
            if (event.key === Qt.Key_Down) player.moveDown();
            if (event.key === Qt.Key_Left) player.moveLeft();
            if (event.key === Qt.Key_Right) player.moveRight();
        }
    }
    onKeyReleased: {
        if (player) {
            if (event.key === Qt.Key_Up) player.stopUp();
            if (event.key === Qt.Key_Down) player.stopDown();
            if (event.key === Qt.Key_Left) player.stopLeft();
            if (event.key === Qt.Key_Right) player.stopRight();
        }
    }

    SvgInspector
    {
        id: theSvgInspector
        property var objs: []

        Component.onCompleted: theSvgInspector.setPathToFile("/home/mistergc/dev/clayground/sandboxes/game_template/map.svg")
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
            console.log("onRectangle");
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
                player.text = "Hi you!";
                gameWorld.viewPortCenterWuX = Qt.binding(function() {return gameWorld.screenXToWorld(player.x);});
                gameWorld.viewPortCenterWuY = Qt.binding(function() {return gameWorld.screenYToWorld(player.y);});
            }
        }
        onCircle: {
            console.log("onCircle");
            /* Add logic to process circles */ }
        onEnd: { }
    }
}
