import QtQuick 2.12
import "qrc:/" as LivLd
import Box2D 2.0
import SvgUtils 1.0
import ScalingCanvas 1.0
import ClayGamecontroller 1.0

Item {
    id: theScreenArea
    anchors.fill: parent
    Component.onCompleted: console.log("All: " + width + " , " + height)

    SvgInspector
    {
        id: theSvgInspector
        property var objs: []
        property var player1: gameWorldP1.player

        Component.onCompleted: theSvgInspector.setPathToFile("/home/mistergc/dev/clayground/sandboxes/splitscreen/map.svg")
        onBegin: {
            gameWorldP1.player = null;
            while(objs.length > 0) {
                var obj = objs.pop();
                obj.destroy();
            }
            gameWorldP1.worldXMax = widthWu;
            gameWorldP1.worldYMax = heightWu;
            gameWorldP2.worldXMax = widthWu;
            gameWorldP2.worldYMax = heightWu;
        }
        onBeginGroup: {console.log("beginGroup");}

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
                targetWorld.player = obj;
                targetWorld.player.maxXVelo = 5;
            }
        }

        onRectangle: {
            let cfg = JSON.parse(description);
            createRectObj(gameWorldP1, true, xWu, yWu, widthWu, heightWu, cfg);
            createRectObj(gameWorldP2, false, xWu, yWu, widthWu, heightWu, cfg);
        }
        onEnd: {
            gameWorldP2.player.x = Qt.binding(function() {return gameWorldP1.player.x;});
            gameWorldP2.player.y = Qt.binding(function() {return gameWorldP1.player.y;});
            gameWorldP2.player.faceRight = Qt.binding(function() {return gameWorldP1.player.faceRight;});
            gameWorldP1.player.onCurrentSpriteChanged.connect(function() {gameWorldP2.player.sprite.jumpTo(gameWorldP1.player.currentSprite);} );
        }
    }

    Row
    {
        CoordCanvas
        {
            id: gameWorldP1
            height: theScreenArea.height
            width: theScreenArea.width * .5
            pixelPerUnit: width / gameWorldP1.worldXMax

            property var player: null
            onPlayerChanged: {
                if (player) {
                    viewPortCenterWuX = Qt.binding(function() {return screenXToWorld(player.x);});
                    viewPortCenterWuY = Qt.binding(function() {return screenYToWorld(player.y);});
                }
            }

            Component.onCompleted: {
                ReloadTrigger.observeFile("Player.qml");
            }

            World {
                id: physicsWorld
                gravity: Qt.point(0,4*9.81)
                timeStep: 1/60.0
                pixelsPerMeter: gameWorldP1.pixelPerUnit
            }

            //    DebugDraw {
            //        anchors.fill: parent
            //        parent: gameWorldP1.coordSys
            //    }

            Keys.forwardTo: gameCtrl1
            GameController {
                id: gameCtrl1

                anchors.fill: parent
                showDebugOverlay: false

                property var player: gameWorldP1.player
                onButtonBPressedChanged: if (buttonBPressed) player.jump();

                Component.onCompleted: {
                    //selectGamepad(0)
                    selectKeyboard(Qt.Key_Up, Qt.Key_Down, Qt.Key_Left, Qt.Key_Right, Qt.Key_A, Qt.Key_S);
                }

                onPlayerChanged: {
                    if (player) {
                        player.desireX = Qt.binding(function() {return gameCtrl1.axisX;});
                    }
                }
            }

        }

        CoordCanvas
        {
            id: gameWorldP2
            height: theScreenArea.height
            width: theScreenArea.width * .5
            pixelPerUnit: width / gameWorldP2.worldXMax

            property var player: null
            onPlayerChanged: {
                if (player) {
                    viewPortCenterWuX = Qt.binding(function() {return screenXToWorld(player.x);});
                    viewPortCenterWuY = Qt.binding(function() {return screenYToWorld(player.y);});
                }
            }
        }
    }
}
