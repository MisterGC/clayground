// (c) Clayground Contributors - MIT License, see "LICENSE" file

// Crew Gym — deterministic verification sandbox for the inspector protocol.
// Exercised by run_gym.py (CI) and by attended acceptance runs; every entity
// is placed deterministically so traces and single-stepping are reproducible.

import QtQuick
import Box2D
import Clayground.Common
import Clayground.GameController
import Clayground.Physics
import Clayground.World

ClayWorld2d {
    id: gym

    anchors.fill: parent
    pixelPerUnit: height / gym.yWuMax
    gravity: Qt.point(0, 0)
    components: new Map([])

    property int score: 0

    // The user's viewpoint (camera + zoom). It has nothing to do with the
    // scenario state, so it must survive reloads via viewState/applyViewState.
    property real camX: 1
    property real camY: 2
    property real zoom: 1

    function viewState() {
        return { camX: gym.camX, camY: gym.camY, zoom: gym.zoom }
    }

    function applyViewState(s) {
        gym.camX = s.camX;
        gym.camY = s.camY;
        gym.zoom = s.zoom;
    }

    function flagInfo() {
        return {
            player: { x: player.xWu, y: player.yWu },
            enemyX: enemy.xWu,
            score: gym.score
        }
    }

    function scenarios() {
        return ["start", "near-coin", "error-probe"]
    }

    function applyScenario(name) {
        if (name === "start") {
            gym.score = 0;
            coin.collected = false;
            player.xWu = 5; player.yWu = 10;
            enemy.xWu = 15; enemy.yWu = 15;
            coin.xWu = 12; coin.yWu = 10;
        }
        else if (name === "near-coin") {
            gym.score = 0;
            coin.collected = false;
            player.xWu = 10; player.yWu = 10;
            enemy.xWu = 15; enemy.yWu = 15;
            coin.xWu = 12; coin.yWu = 10;
        }
        else if (name === "error-probe") {
            _errorProbe.start();
        }
        else {
            console.error("gym: unknown scenario '" + name + "'");
        }
    }

    // Deliberately raises a genuine QML runtime error (TypeError) shortly
    // after activation so the auto-flag path can be verified end to end.
    Timer {
        id: _errorProbe
        interval: 50
        onTriggered: gym._thisFunctionDoesNotExist()
    }

    Keys.forwardTo: ctrl
    GameController {
        id: ctrl
        anchors.fill: parent
        Component.onCompleted: selectKeyboard(
            Qt.Key_Up, Qt.Key_Down, Qt.Key_Left, Qt.Key_Right,
            Qt.Key_J, Qt.Key_K);
    }

    // Entities are plain direct children — ClayWorld2d's auto-migration
    // wires parent/world/pixelPerUnit (including for entities that declare
    // custom properties; see #135).
    RectBoxBody {
        id: player
        objectName: "player"
        color: "#00d9ff"
        xWu: 5; yWu: 10; widthWu: 1; heightWu: 1
        bodyType: Body.Dynamic
        linearVelocity.x: ctrl.axisX * 8
        linearVelocity.y: -ctrl.axisY * 8
    }

    // Patrols between xWu 15 and 25 at a constant 2 Wu/s — with the fixed
    // 1/60 timestep every physics step advances it exactly 2/60 Wu, which is
    // what makes the single-step assertions exact.
    RectBoxBody {
        id: enemy
        objectName: "enemy"
        color: "#ff3366"
        xWu: 15; yWu: 15; widthWu: 1; heightWu: 1
        bodyType: Body.Kinematic; sensor: true
        property real dir: 1
        linearVelocity.x: dir * 2
        onXWuChanged: {
            if (xWu >= 25) dir = -1;
            else if (xWu <= 15) dir = 1;
        }
    }

    RectBoxBody {
        id: coin
        objectName: "coin"
        color: "#ffd93d"
        visible: !collected
        xWu: 12; yWu: 10; widthWu: 1; heightWu: 1
        bodyType: Body.Static; sensor: true
        property bool collected: false
        // Raw counter helps diagnosing contact plumbing independent of the
        // scoring guard.
        property int rawContacts: 0
        CollisionTracker {
            fixture: coin.fixture
            onBeginContact: (entity) => {
                coin.rawContacts++;
                if (!coin.collected && entity === player) {
                    coin.collected = true;
                    gym.score++;
                }
            }
        }
    }

    // Deterministic initial state (also normalizes any NaN coordinates from
    // the pre-layout phase).
    Component.onCompleted: applyScenario("start")
}
