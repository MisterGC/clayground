// (c) Clayground Contributors - MIT License, see "LICENSE" file
import QtQuick

Rectangle {
    id: root
    width: 320
    height: 240
    color: "#222222"

    // Custom properties of various primitive types
    property int score: 42
    property string currentLevel: "dungeon_3"
    property bool combatActive: true
    property real difficulty: 0.7

    // Private property (should be skipped by inspector)
    property int _internalCounter: 99

    function flagInfo() {
        return {
            playerX: player.x,
            playerY: player.y,
            enemyCount: enemyRepeater.count,
            seed: 12345
        };
    }

    Rectangle {
        id: player
        objectName: "player"
        x: 50
        y: 100
        width: 16
        height: 16
        color: "cyan"
    }

    Repeater {
        id: enemyRepeater
        model: 3
        Rectangle {
            objectName: "enemy_" + index
            x: 100 + index * 30
            y: 60
            width: 12
            height: 12
            color: "red"
        }
    }

    Text {
        objectName: "hud"
        text: "Score: " + root.score
        color: "white"
        x: 10
        y: 10
    }
}
