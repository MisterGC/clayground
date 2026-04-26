// (c) Clayground Contributors - MIT License, see "LICENSE" file

import QtQuick
import Box2D
import Clayground.Algorithm
import Clayground.Behavior
import Clayground.Canvas as Canv
import Clayground.GameController
import Clayground.Physics
import Clayground.World

ClayWorld2d
{
    id: theWorld

    anchors.fill: parent
    pixelPerUnit: height / theWorld.yWuMax
    gravity: Qt.point(0,0)
    loadMapAsync: false

    // Activate to see behavior visualization
    property bool behaviorDebug: true

    Component.onCompleted: scene = "map.svg"

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
        Canv.Text{
            z: player.z
            parent: player.parent;
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
    onMapEntityCreated: (obj, groupId, compName) => {
        if (compName === "SpawnArea") spawnArea = obj;
        if (compName === "Wall") _walls.push(obj);
    }
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
    onPolylineLoaded: (id, groupId, points, fillColor, strokeColor, description) => {
                          if (description === "PatrolPath") path = points;
                      }

    // Encapsulate construction of door as it is made up
    // of multiple parts (door, switches and movement path)
    DoorBuilder{id: doorBuilder; world: theWorld }

    // Pathfinding grid for NavigateTo demo
    property real navCellSize: 0.5
    property var _walls: []
    GridPathfinder {
        id: levelPathfinder
        columns: Math.ceil(theWorld.xWuMax / navCellSize)
        rows: Math.ceil(theWorld.yWuMax / navCellSize)
        diagonal: true
    }

    onMapLoaded: {
        observedItem = player;
        _buildNavGrid();
        // Defer position setup: pixelPerUnit bidirectional bindings
        // need a settled coordinate system before positions are reliable
        _initTimer.restart();
    }
    Timer {
        id: _initTimer; interval: 50; onTriggered: {
            player.xWu = 7; player.yWu = 7;
            enemy.xWu = 5; enemy.yWu = 18;
            enemyNav.running = true;
        }
    }

    function _buildNavGrid() {
        let cs = navCellSize;
        let c = levelPathfinder.columns;
        let r = levelPathfinder.rows;
        let g = new Array(c * r).fill(0);
        for (let i = 0; i < _walls.length; ++i) {
            let w = _walls[i];
            let x0 = Math.floor(w.xWu / cs);
            let y0 = Math.floor((w.yWu - w.heightWu) / cs);
            let x1 = Math.ceil((w.xWu + w.widthWu) / cs);
            let y1 = Math.ceil(w.yWu / cs);
            for (let gy = y0; gy < y1; ++gy) {
                for (let gx = x0; gx < x1; ++gx) {
                    if (gx >= 0 && gx < c && gy >= 0 && gy < r)
                        g[gy * c + gx] = 1;
                }
            }
        }
        levelPathfinder.walkableData = g;
    }

    // NPC that chases the player using NavigateTo
    RectBoxBody {
        id: enemy
        objectName: "enemy"
        color: "#c0392b"
        border.color: Qt.darker(color, 1.3); border.width: 2
        radius: width * .25
        xWu: 5; yWu: 18; widthWu: .9; heightWu: widthWu
        bodyType: Body.Kinematic; sensor: true; z: 99
        categories: collCat.npc
        collidesWith: collCat.wall
        Canv.Text {
            z: enemy.z
            parent: enemy.parent
            anchors.horizontalCenter: enemy.horizontalCenter
            anchors.bottom: enemy.top
            text: "Enemy"
            font.bold: true
            fontSizeWu: .5
        }
        NavigateTo {
            id: enemyNav
            world: theWorld
            pathfinder: levelPathfinder
            destXWu: player.xWu
            destYWu: player.yWu
            cellSize: theWorld.navCellSize
            running: false
            desiredSpeed: 3
            recalcInterval: 500
            debug: theWorld.behaviorDebug
            debugColor: enemy.color
            onArrived: console.log("Enemy reached the player!")
        }
    }
}
