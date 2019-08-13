import QtQuick 2.12
import Box2D 2.0
import Clayground.SvgUtils 1.0
import Clayground.ScalingCanvas 1.0

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

    onKeyPressed:
    {
        if (!player) return;
        switch (event.key)
        {
        case Qt.Key_Up: player.moveUp(); break;
        case Qt.Key_Down: player.moveDown(); break;
        case Qt.Key_Left: player.moveLeft(); break;
        case Qt.Key_Right: player.moveRight(); break;
        }
    }

    onKeyReleased:
    {
        if (!player) return;
        switch (event.key)
        {
        case Qt.Key_Up: player.stopUp(); break;
        case Qt.Key_Down: player.stopDown(); break;
        case Qt.Key_Left: player.stopLeft(); break;
        case Qt.Key_Right: player.stopRight(); break;
        }
    }

    SvgInspector
    {
        id: theSvgInspector
        property var objs: []

        Component.onCompleted: setSource(ReloadTrigger.observedPath() + "/map.svg")

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
            var obj = comp.createObject(coordSys, {xWu: x, yWu: y, widthWu: width, heightWu: height, color: "black"});
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
