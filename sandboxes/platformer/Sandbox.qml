import QtQuick 2.12
import Box2D 2.0
import Clayground.SvgUtils 1.0
import Clayground.ScalingCanvas 1.0
import Clayground.GameController 1.0
import Clayground.Physics 1.0

CoordCanvas
{
    id: world
    anchors.fill: parent
    pixelPerUnit: width / world.worldXMax
    
    property bool standaloneApp: false
    readonly property string map: (standaloneApp ? ":/" : ClayLiveLoader.sandboxDir)
                         + "/map.svg"
    readonly property string resPrefix: world.standaloneApp ? "qrc:/" : ""


    World {
        id: physicsWorld
        gravity: Qt.point(0,15*9.81)
        timeStep: 1/60.0
        pixelsPerMeter: pixelPerUnit
    }

    property var player: null

    Keys.forwardTo: gameCtrl
    GameController {
        id: gameCtrl
        anchors.fill: parent
        onButtonBPressedChanged:  if (buttonBPressed) player.jump();
        Component.onCompleted: {
            selectKeyboard(Qt.Key_Up, Qt.Key_Down, Qt.Key_Left, Qt.Key_Right, Qt.Key_A, Qt.Key_S);
            player.desireX = Qt.binding(function() {return gameCtrl.axisX;});
        }
    }

    SvgInspector
    {
        id: theSvgInspector
        property var objs: []

        Component.onCompleted: setSource(world.map)

        onBegin: {
            world.viewPortCenterWuX = 0;
            world.viewPortCenterWuY = 0;
            world.worldXMax = widthWu;
            world.worldYMax = heightWu;
            player = null;
            for (let obj of objs) obj.destroy();
            objs = [];
        }

        onRectangle: {
            let cfg = JSON.parse(description);
            let compStr = world.resPrefix + cfg["component"];
            let comp = Qt.createComponent(compStr);
            let obj = comp.createObject(coordSys, {world: physicsWorld, xWu: x, yWu: y, widthWu: width, heightWu: height, color: "black"});
            obj.pixelPerUnit = Qt.binding( _ => {return world.pixelPerUnit;} );
            objs.push(obj);
            if (compStr === (world.resPrefix + "Player.qml")) {
                player = obj;
                world.observedItem = player;
                player.spriteSource = world.resPrefix + "player_animated.png"
            }
        }
    }
}
