import QtQuick 2.12
import "qrc:/" as LivLd
import Box2D 2.0
import GcPopulator 1.0

CoordCanvas
{
    id: theCanvas
    anchors.fill: parent

    Component {
        id: rectCreator
        VisualizedBoxBody {
            id: theBody
            parent: coordSys
            pixelPerUnit: theCanvas.pixelPerUnit
            xWu: 10; yWu: 10; widthWu: 1; heightWu: 0.6;
            Component.onCompleted: console.log("x: " + x +
                                               " y:" + y +
                                               " width:" + width +
                                               " height:" + height );
            MouseArea {
                anchors.fill: parent
                onPressed: {
                    theArea.pressedBody = theBody.body;
                    mouse.accepted = false;
                }
            }
        }
    }

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
            console.log("Position changed!")
            mouseJoint.target = Qt.point(mouseX, mouseY);
        }

        onReleased: {
            console.log("Released")
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

    property var player: null
    onKeyPressed: {
        if (player) {
            // Do key to control mapping
            console.log("Ready for Action!")
            if (event.key === Qt.Key_Up) player.moveUp();
            if (event.key === Qt.Key_Down) player.moveDown();
            if (event.key === Qt.Key_Left) player.moveLeft();
            if (event.key === Qt.Key_Right) player.moveRight();
        }
    }

    Populator
    {
        id: thePopulator
        property var objs: []

        Component.onCompleted: thePopulator.setPopulationModel("/home/mistergc/dev/qml_live_loader/plugins/populator/sample_level.svg")
        onAboutToPopulate: {
            console.log("World: " + widthWu + "x" + heightWu + " Px: " + widthPx + "x" + heightPx)
            player = null;
            while(objs.length > 0) {
                var obj = objs.pop();
                obj.destroy();
            }
            theCanvas.worldXMax = widthWu;
            theCanvas.worldYMax = heightWu;
            console.log("WuWidth: " + widthWu  +" Width: " + theCanvas.coordSys.width)
        }
        onCreateItemAt: {
            console.log("Create item: " + componentName + " x: " + xWu + " y: " + yWu);
            var comp = Qt.createComponent(componentName + ".qml");
            console.log("Comp: " + comp)
            var obj = comp.createObject(coordSys, {
                                            "xWu": xWu,
                                            "yWu": theCanvas.worldYMax - yWu,
                                            "widthWu": widthWu,
                                            "heightWu": heightWu
                                            });
            obj.pixelPerUnit = Qt.binding(function() {return theCanvas.pixelPerUnit;});
            objs.push(obj);
            if (componentName === "Player") player = obj;
        }
    }

}
