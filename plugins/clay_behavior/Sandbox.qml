// (c) serein.pfeiffer@gmail.com - zlib license, see "LICENSE" file

import QtQuick 2.12
import Box2D 2.0
import Clayground.Canvas 1.0 as Canv
import Clayground.GameController 1.0
import Clayground.Physics 1.0
import Clayground.World 1.0

ClayWorld
{
    id: theWorld

    map: "map.svg";
    anchors.fill: parent
    pixelPerUnit: height / theWorld.yWuMax
    gravity: Qt.point(0,0)
    loadMapAsync: false

    // Activate to see behavior visualization
    property bool behaviorDebug: true

    onMapLoaded: observedItem = player

    // Collision categories used by physics (see Box2D manual)
    QtObject{
        id: collCat
        readonly property int player: Box.Category3
        readonly property int door: Box.Category4
        readonly property int npc: Box.Category5
        readonly property int wall: Box.Category6
    }

    // How to put together keyboard controls with physics movement?
    RectBoxBody {
        id: player; color: "orange"; bodyType: Body.Dynamic; z:99
        xWu: 7; yWu: 7; widthWu: .9; heightWu: widthWu; radius: .25*width
        linearVelocity.x: ctrl.axisX * 10; linearVelocity.y: -ctrl.axisY * 10;
        Canv.Text{parent: player.parent;
            anchors.horizontalCenter: player.horizontalCenter;
            anchors.bottom: player.top;
            text: "Player";
            font.bold: true
            fontSizeWu: .5
        }
        categories: collCat.player
        collidesWith: collCat.door | collCat.wall
    }

    Keys.forwardTo: ctrl
    GameController {
        id: ctrl; anchors.fill: parent;
        Component.onCompleted: selectKeyboard(
                                   Qt.Key_Up, Qt.Key_Down, Qt.Key_Left, Qt.Key_Right,
                                   Qt.Key_J, Qt.Key_K);
    }

    // Move entities randomly arround within a limited area
    property var spawnArea: null
    Component{id: spawnAreaComp; RectBoxBody{z:-1; color: "#92dfbd"} }
    onMapEntityCreated: (obj, groupId, compName) => {if (compName==="SpawnArea") spawnArea = obj; }
    Repeater{
        model: spawnArea ? 5 : 0
        RectBoxBody {
            function rndSpawnAreaX(){return spawnArea.xWu + Math.random() * spawnArea.widthWu}
            function rndSpawnAreaY(){return spawnArea.yWu - Math.random() * spawnArea.heightWu}
            color: "#1b5e41"; z: 99
            border.color: Qt.darker(color, 1.3); border.width: 2;
            radius: width*.25
            xWu: rndSpawnAreaX(); yWu: rndSpawnAreaY(); widthWu: .7; heightWu: widthWu;
            bodyType: Body.Kinematic; sensor: true;
            MoveTo {
                desiredSpeed: 1.1
                world: theWorld; anchors.centerIn: parent;
                function updateDest() {destXWu = rndSpawnAreaX(); destYWu = rndSpawnAreaY()}
                Component.onCompleted: updateDest(); running: true; onArrived: updateDest()
                debug: theWorld.behaviorDebug; debugColor: parent.color
            }
        }
    }

    // One entity follows a path
    RectBoxBody {
        id: pathFollower
        parent: theWorld.room
        radius: height *.25
        color: "#de8787"
        xWu: 3.5; yWu: 9; widthWu: .9; heightWu: widthWu;
        bodyType: Body.Kinematic; sensor: true;
        categories: collCat.npc; collidesWith: collCat.door
        property alias openDoorAction: openDoor
        FollowPath{
            id: _followP; debug: theWorld.behaviorDebug; debugColor: parent.color ; world: theWorld;
            anchors.centerIn: parent; repeat: true; running: true; wpsWu: theWorld.path
        }
        SequentialAnimation{id: openDoor;
            ScriptAction{script: _followP.running = false;}
            PauseAnimation {duration: 1500;}
            ScriptAction{script: _followP.running = true;}
        }
    }

    // Loading the map
    components: new Map([ ['Wall', wallComp], ['SpawnArea', spawnAreaComp] ])
    Component {
        id: wallComp;
        RectBoxBody {color: "#333333"; categories: collCat.wall; collidesWith: collCat.player}
    }

    property var path: []
    onPolylineLoaded: (id, groupId, points, description) => { if (description === "PatrolPath") path = points; }

    // Encapsulate construction of door as it is made up
    // of multiple parts (door, switches and movement path)
    DoorBuilder{id: doorBuilder; world: theWorld }
}
