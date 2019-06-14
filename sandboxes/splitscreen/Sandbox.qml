import QtQuick 2.12
import "qrc:/" as LivLd
import Box2D 2.0
import Clayground.SvgUtils 1.0
import Clayground.ScalingCanvas 1.0
import Clayground.GameController 1.0

Item {
    id: theScreenArea
    anchors.fill: parent

    Component.onCompleted: {
        ReloadTrigger.observeFile("Player.qml");
    }

    SvgInspector
    {
        id: theSvgInspector
        Component.onCompleted: theSvgInspector.setPathToFile("/home/mistergc/dev/clayground/sandboxes/splitscreen/map.svg")

        property var objs: []

        onBegin: {
            gameWorldP1.observedItem = null;
            gameWorldP2.observedItem = null;
            while(objs.length > 0) {
                var obj = objs.pop();
                obj.destroy();
            }
            gameWorldP1.worldXMax = widthWu;
            gameWorldP1.worldYMax = heightWu;
            gameWorldP2.worldXMax = widthWu;
            gameWorldP2.worldYMax = heightWu;
        }
        onBeginGroup: { }

        function createRectObj(targetWorld, withPhys, xWu, yWu, widthWu, heightWu, cfg) {
            var comp = Qt.createComponent(cfg["component"]);
            var obj = comp.createObject(targetWorld.coordSys, {
                                            "xWu": xWu,
                                            "yWu": yWu,
                                            "widthWu": widthWu,
                                            "heightWu": heightWu,
                                            "color": "black",
                                            "active": withPhys
                                        });
            obj.pixelPerUnit = Qt.binding(function() {return targetWorld.pixelPerUnit;});
            objs.push(obj);
            if (cfg["component"] === "Player.qml") {
                obj.maxXVelo = 5;
                if (cfg["controller"] === 1) {
                    if (!gameWorldP1.observedItem) gameWorldP1.observedItem = obj;
                    obj.spriteSheet = "player1.png"
                }
                else {
                    if (!gameWorldP2.observedItem) gameWorldP2.observedItem = obj;
                    obj.spriteSheet = "player2.png"
                }
            }
            return obj;
        }

        onRectangle: {
            let cfg = JSON.parse(description);
            let objW1 = createRectObj(gameWorldP1, true, xWu, yWu, widthWu, heightWu, cfg);
            let objW2 = createRectObj(gameWorldP2, false, xWu, yWu, widthWu, heightWu, cfg);
            if (objW1.isPlayer) bindPlayer(objW1, objW2);
        }

        function bindPlayer(playerW1, playerW2) {
            playerW2.x = Qt.binding(function() {return playerW1.x;});
            playerW2.y = Qt.binding(function() {return playerW1.y;});
            playerW2.faceRight = Qt.binding(function() {return playerW1.faceRight;});
            playerW1.onCurrentSpriteChanged.connect(function() {playerW2.sprite.jumpTo(playerW1.currentSprite);} );
        }

        onEnd: { }
    }

    Row
    {
        id: theRow

        CoordCanvas
        {
            id: gameWorldP1
            height: theScreenArea.height
            width: (theScreenArea.width - theDevider.width) * .5
            pixelPerUnit: width * 2 / gameWorldP1.worldXMax

            World {
                id: physicsWorld
                gravity: Qt.point(0,4*9.81)
                timeStep: 1/60.0
                pixelsPerMeter: gameWorldP1.pixelPerUnit
            }

            Keys.forwardTo: [gameCtrl1, gameCtrl2]
            JnRGameController {
                id: gameCtrl1
                Component.onCompleted: selectKeyboard(Qt.Key_Up, Qt.Key_Down, Qt.Key_Left, Qt.Key_Right, Qt.Key_A, Qt.Key_S);
                player: gameWorldP1.observedItem
            }

            JnRGameController {
                id: gameCtrl2
                Component.onCompleted: selectKeyboard(Qt.Key_I, Qt.Key_K, Qt.Key_J, Qt.Key_L, Qt.Key_F, Qt.Key_G);
                player: gameWorldP2.observedItem
            }
        }

        Rectangle {
            id: theDevider
            height: theScreenArea.height
            width: theScreenArea.width * 0.02
            color: "darkred"
        }

        CoordCanvas
        {
            id: gameWorldP2
            height: gameWorldP1.height
            width: gameWorldP1.width
            pixelPerUnit: gameWorldP1.pixelPerUnit
        }
    }
}
