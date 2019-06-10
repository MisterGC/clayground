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
        }
        onBeginGroup: {console.log("beginGroup");}
        onRectangle: {
            let cfg = JSON.parse(description);
            var comp = Qt.createComponent(cfg["component"]);
            var obj = comp.createObject(gameWorldP1.coordSys, {
                                            "xWu": xWu,
                                            "yWu": yWu,
                                            "widthWu": widthWu,
                                            "heightWu": heightWu,
                                            "color": "black"
                                        });
            obj.pixelPerUnit = Qt.binding(function() {return gameWorldP1.pixelPerUnit;});
            objs.push(obj);
            if (cfg["component"] === "Player.qml") {
                gameWorldP1.player = obj;
                gameWorldP1.viewPortCenterWuX = Qt.binding(function() {return gameWorldP1.screenXToWorld(player1.x);});
                gameWorldP1.viewPortCenterWuY = Qt.binding(function() {return gameWorldP1.screenYToWorld(player1.y);});
                gameWorldP1.player.maxXVelo = 5;
            }
        }
        onEnd: { }
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
    }
}
