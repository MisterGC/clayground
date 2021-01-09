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
    anchors.fill: parent
    pixelPerUnit: height / theWorld.yWuMax
    gravity: Qt.point(0,0)
    map: "map.svg"

    function rndCoord() {return Math.random() * 16 + 2;}

    onMapLoaded: observedItem = player
    readonly property int _collCatPlayer: Box.Category3
    readonly property int _collCatDoor: Box.Category4
    readonly property int _collCatNpc: Box.Category5
    readonly property int _collCatWall: Box.Category6

    // How to put together keyboard controls with physics movement?
    RectBoxBody {
        id: player; color: "orange"; bodyType: Body.Dynamic
        xWu: 10; yWu: 10; widthWu: .9; heightWu: widthWu
        linearVelocity.x: ctrl.axisX * 10; linearVelocity.y: -ctrl.axisY * 10;
        Canv.Text{parent: player.parent;
            anchors.horizontalCenter: player.horizontalCenter;
            anchors.bottom: player.top;
            text: "Player";
            font.bold: true
            fontSizeWu: .5
        }
        categories: theWorld._collCatPlayer
        collidesWith: theWorld._collCatDoor | theWorld._collCatWall
    }
    Keys.forwardTo: ctrl
    GameController {id: ctrl; anchors.fill: parent;
    Component.onCompleted: selectKeyboard(Qt.Key_W, Qt.Key_S, Qt.Key_A, Qt.Key_D, Qt.Key_J, Qt.Key_K); }

    // Move entities randomly arround within a limited area
    property var spawnArea: null
    Repeater{
        model: spawnArea ? 10 : 0
        RectBoxBody {
            color: "#92dfbd"
            xWu: theWorld.rndCoord(); yWu: theWorld.rndCoord(); widthWu: .9; heightWu: widthWu;
            bodyType: Body.Kinematic; sensor: true;
            MoveTo {
                world: theWorld; anchors.centerIn: parent;
                destXWu: theWorld.rndCoord(); destYWu: theWorld.rndCoord()
                running: true; onArrived: {destXWu = theWorld.rndCoord(); destYWu = theWorld.rndCoord();}
                debug: true; debugColor: parent.color
            }
        }
    }

    // One entity follows a path
    RectBoxBody {
        id: pathFollower
        radius: height *.25
        property alias path: _followP.wpsWu
        color: "#de8787"
        xWu: theWorld.rndCoord(); yWu: theWorld.rndCoord(); widthWu: .9; heightWu: widthWu;
        bodyType: Body.Kinematic; sensor: true;
        categories: theWorld._collCatNpc; collidesWith: theWorld._collCatDoor
        property alias openDoorAction: openDoor
        FollowPath{
            id: _followP; debug: true; debugColor: parent.color ; world: theWorld;
            anchors.centerIn: parent; repeat: true; running: true; wpsWu: theWorld.path
        }
        SequentialAnimation{id: openDoor;
            ScriptAction{script: _followP.running = false;}
            PauseAnimation {duration: 1500;}
            ScriptAction{script: _followP.running = true;}
        }
    }

    // Loading the map
    components: new Map([ ['Wall', c1], ['Door', c2], ['DoorOpener', c3] ])
    Component {id: c1; RectBoxBody { color: "#333333";

        categories: theWorld._collCatWall
        collidesWith: theWorld._collCatPlayer
        } }

    property var path: []
    onPolylineLoaded: {
        if (description === "PatrolPath") pathFollower.path = points;
        else if (_currentMapGroup.startsWith("door")) doorPath = points;
    }


    // Build a more complex object (automated door) based on groups in the map
    property string _currentMapGroup: ""
    property var doorPath: []
    property var door: null
    Component {id: c2; RectBoxBody {
            color: "#398bbf";
            z: -1
            property var path: []
            bodyType: Body.Kinematic;
            friction: 0
            categories: theWorld._collCatDoor; collidesWith: theWorld._collCatPlayer
            property int idx: 0;  onIdxChanged: {let p = path[idx]; _b.destXWu = p.x; _b.destYWu = p.y; _b.running = true}
            MoveTo {id: _b; world: theWorld; onArrived: running = false; anchors.centerIn: parent; running: false; debug: running; debugColor: parent.color}
        }}
    onGroupAboutToBeLoaded: {_currentMapGroup=id;}
    onMapEntityCreated: {
        if (!_currentMapGroup.startsWith("door")) return;
        door = obj;
    }
    onGroupLoaded: {
        if (_currentMapGroup.startsWith("door")){ door.path = doorPath; }
        _currentMapGroup = ""; }
    Component{ id: c3
    RectTrigger{
        visible: true; color: "#92c0df"
        categories: theWorld._collCatDoor; collidesWith: theWorld._collCatNpc
        onEntered: {door.idx = 1; closeTimer.restart(); entity.openDoorAction.start();}
        Timer{id: closeTimer; interval: 2500; onTriggered: door.idx = 0;}
    }
    }

}
