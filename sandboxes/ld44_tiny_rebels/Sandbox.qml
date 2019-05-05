import QtQuick 2.12
import "qrc:/" as LivLd
import Box2D 2.0
import SvgInspector 1.0
import ScalingCanvas 1.0

CoordCanvas
{
    id: theCanvas
    anchors.fill: parent

    Body {
        id: anchor
        world: physicsWorld
    }

    MouseJoint {
        id: mouseJoint
        bodyA: anchor
        dampingRatio: 0.8
        maxForce: 100
    }

    MouseArea {
        id: theArea
        parent: coordSys
        property Body pressedBody: null
        anchors.fill: parent
        preventStealing: pressedBody !== null

        onPressed: {
            if (pressedBody != null) {
                console.log("There is a pressed body!")
                mouseJoint.maxForce = pressedBody.getMass() * 500;
                mouseJoint.target = Qt.point(mouseX, mouseY);
                mouseJoint.bodyB = pressedBody;
            }
        }

        onPositionChanged: {
            mouseJoint.target = Qt.point(mouseX, mouseY);
        }

        onReleased: {
            mouseJoint.bodyB = null;
            pressedBody = null;
        }
    }

    World {
        id: physicsWorld
        gravity: Qt.point(0,0)
        timeStep: 1/60.0
        pixelsPerMeter: pixelPerUnit
    }

//    DebugDraw {
//        anchors.fill: parent
//        parent: theCanvas.coordSys
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
            if (event.key === Qt.Key_Up) player.stopUp();
            if (event.key === Qt.Key_Down) player.stopDown();
            if (event.key === Qt.Key_Left) player.stopLeft();
            if (event.key === Qt.Key_Right) player.stopRight();
    }

    property bool aiRunning: false
    AiMap { id: aiMap }

    Populator
    {
        id: thePopulator
        property var objs: []

        Component.onCompleted: thePopulator.setPathToFile("/home/mistergc/dev/qml_live_loader/sandboxes/ld44_tiny_rebels/world.svg")
        onBegin: {
            console.log("World: " + widthWu + "x" + heightWu + " Px: " + widthPx + "x" + heightPx)
            player = null;
            theCanvas.aiRunning = false;
            aiMap.clear();
            while(objs.length > 0) {
                var obj = objs.pop();
                obj.destroy();
            }
            theCanvas.worldXMax = widthWu;
            theCanvas.worldYMax = heightWu;
            console.log("WuWidth: " + widthWu  +" Width: " + theCanvas.coordSys.width)
        }
        onRectangle: {
            console.log("Create item: " + componentName + " x: " + xWu + " y: " + yWu);
            var comp = Qt.createComponent(componentName + ".qml");
            console.log("Description: " + description)
            var obj = comp.createObject(coordSys, {
                                            "xWu": xWu,
                                            "yWu": yWu,
                                            "widthWu": widthWu,
                                            "heightWu": heightWu
                                            });
            obj.pixelPerUnit = Qt.binding(function() {return theCanvas.pixelPerUnit;});
            console.log("x: " + obj.x + " y: " + obj.y)

            objs.push(obj);
            if (componentName === "Player") {
                player = obj;
                player.x = 500
                theCanvas.viewPortCenterWuX = Qt.binding(function() {return theCanvas.screenXToWorld(player.x);});
                theCanvas.viewPortCenterWuY = Qt.binding(function() {return theCanvas.screenYToWorld(player.y);});
            }
            else if (componentName === "Absorbicer") {
                let hasCfg = (description.length >= 2);
                if (hasCfg) {
                    let cfg = JSON.parse(description)
                    if (cfg["route"])
                        obj.route = cfg["route"];
                }
                obj.map = aiMap
                obj.aiRunning = Qt.binding(function() {return theCanvas.aiRunning;});
            }
        }
        onCircle: {
            var comp = Qt.createComponent(componentName + ".qml");
            var obj = comp.createObject(coordSys, {
                                            "xWu": xWu,
                                            "yWu": yWu,
                                            "widthWu": 2*radiusWu,
                                            "heightWu": 2*radiusWu
                                            });
            obj.pixelPerUnit = Qt.binding(function() {return theCanvas.pixelPerUnit;});
            objs.push(obj);
            if (componentName == "Waypoint"){
                let splitInfo = description.split(":");
                let routeId = splitInfo[0];
                let wpIdx = splitInfo[1]
                if (!aiMap.routes[routeId]) {
                    console.log("Add route " + routeId)
                    aiMap.routes[routeId] = [];
                }
                let route = aiMap.routes[routeId];
                obj.route = routeId;
                route[wpIdx] = obj;
                console.log("Route len: " + route.length)
            }
        }
        onEnd: {
            theCanvas.aiRunning = true;
        }
    }

}
