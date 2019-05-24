import QtQuick 2.12
import "qrc:/" as LivLd
import Box2D 2.0
import SvgInspector 1.0
import ScalingCanvas 1.0

CoordCanvas
{
    id: gameWorld
    anchors.fill: parent
    pixelPerUnit: width / gameWorld.worldXMax

    World {
        id: physicsWorld
        gravity: Qt.point(0,3*9.81)
        timeStep: 1/60.0
        pixelsPerMeter: pixelPerUnit
    }

    DebugDraw {
        anchors.fill: parent
        parent: gameWorld.coordSys
    }

    property var player: null
    property int count: 0
    onKeyPressed: {
        console.log("Pressed: " + event.isAutoRepeat  + " " + (count++))
        if (player) {
            if (event.key === Qt.Key_Up && !event.isAutoRepeat) player.jump();
            if (event.key === Qt.Key_A && !event.isAutoRepeat) player.jump();
            if (event.key === Qt.Key_Left) player.moveLeft = true;
            if (event.key === Qt.Key_Right) player.moveRight = true;
        }
    }
    onKeyReleased: {
        console.log("Released: " + event.isAutoRepeat)
        if (player) {
            if (event.key === Qt.Key_Left) player.moveLeft = false;
            if (event.key === Qt.Key_Right) player.moveRight = false;
        }
    }

    Populator
    {
        id: thePopulator
        property var objs: []

        Component.onCompleted: thePopulator.setPathToFile("/home/mistergc/dev/qml_live_loader/sandboxes/jump_n_run/map.svg")
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
