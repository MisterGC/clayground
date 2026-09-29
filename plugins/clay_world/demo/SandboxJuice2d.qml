// (c) Clayground Contributors - MIT License, see "LICENSE" file

import QtQuick
import Clayground.World

// ScreenFx2d, camera shake/kick and hitStop on a lit dungeon. The HUD (health
// bar, key help) is a sibling of the canvas and stays still and ungraded.
// Keys: H hit, J parry, L low health, V vignette, T temperature, G grain,
// C posterise, A auto hits.
Item {
    id: sbx
    anchors.fill: parent
    focus: true

    property real health: 100
    property bool autoHits: true
    property alias fx: fx
    property alias cam: cam
    property alias world: dungeon

    function hit() {
        var a = Math.random() * Math.PI * 2;
        fx.flash("#ffffff", 90, 0.6);
        fx.pulse(0.5, 220);
        cam.addTrauma(0.45);
        cam.kick(0.35 * Math.cos(a), 0.35 * Math.sin(a));
        dungeon.hitStop(70, 0);
        health = Math.max(5, health - 12);
    }

    function parry() {
        fx.flash("#a0d8ff", 140, 0.4);
        fx.pulse(1.0, 300);
        cam.addTrauma(0.25);
        dungeon.hitStop(120, 0.2);
    }

    DemoDungeon2d {
        id: dungeon
        anchors.fill: parent
        pixelPerUnit: height / 20

        // The walker is not a physics body; pausing it while the hit stop
        // runs shows what hitStop does to physics-driven entities.
        walking: true
        Binding { target: dungeon; property: "walking"; value: false; when: dungeon.hitStopActive }

        camera: ClayWorld2dCamera {
            id: cam
            target: dungeon.walker
        }

        LightLayer2d {
            id: lighting
            world: dungeon
            ambient: "#20202e"
        }

        Repeater {
            model: dungeon.torches
            Light2d {
                xWu: modelData.x
                yWu: modelData.y
                radius: 11
                color: modelData.color
                flicker: 0.5
            }
        }

        Component.onCompleted: lighting.setOccluderGrid(
            dungeon.cols, dungeon.rows, dungeon.cellSize,
            (cx, cy) => dungeon.isWall(cx, cy))

        ScreenFx2d {
            id: fx
            world: dungeon
            vignette: 0.7
            lowHealth: sbx.health < 40 ? 1 - sbx.health / 40 : 0
        }

        // HUD: siblings of the canvas above the ScreenFx2d.
        Rectangle {
            z: 1000
            x: 12; y: 12
            width: 220; height: 22
            radius: 4
            color: "#333333"
            Rectangle {
                width: parent.width * sbx.health / 100
                height: parent.height
                radius: 4
                color: sbx.health < 40 ? "#cc3333" : "#44aa55"
            }
        }
        Text {
            z: 1000
            anchors.left: parent.left
            anchors.bottom: parent.bottom
            anchors.margins: 12
            color: "#e8e0d0"
            font.family: "Monospace"
            font.pixelSize: 14
            style: Text.Outline
            styleColor: "#000000"
            text: "[H]it [J]parry [L]ow health [V]ignette [T]emperature [G]rain"
                  + " [C]posterise [A]uto " + sbx.autoHits
                  + "   trauma " + cam.trauma.toFixed(2)
                  + (dungeon.hitStopActive ? "  HIT STOP" : "")
        }
    }

    Light2d {
        parent: dungeon.walker
        radius: 8
        color: "#fff0d0"
        intensity: 0.9
        flicker: 0.15
    }

    Timer {
        running: sbx.autoHits
        interval: 1600
        repeat: true
        property int n: 0
        onTriggered: { if (++n % 3 === 0) sbx.parry(); else sbx.hit(); }
    }

    // Slow regeneration, so auto hits swing between healthy and low.
    Timer {
        running: true
        interval: 250
        repeat: true
        onTriggered: sbx.health = Math.min(100, sbx.health + 0.5)
    }

    Keys.onPressed: (event) => {
        if (event.key === Qt.Key_H) hit();
        else if (event.key === Qt.Key_J) parry();
        else if (event.key === Qt.Key_L) health = health < 40 ? 100 : 15;
        else if (event.key === Qt.Key_V) fx.vignette = fx.vignette > 0 ? 0 : 0.7;
        else if (event.key === Qt.Key_T) fx.temperature = fx.temperature > 0 ? -0.6 : (fx.temperature < 0 ? 0 : 0.6);
        else if (event.key === Qt.Key_G) fx.grain = fx.grain > 0 ? 0 : 0.6;
        else if (event.key === Qt.Key_C) fx.colorLevels = fx.colorLevels > 0 ? 0 : 6;
        else if (event.key === Qt.Key_A) autoHits = !autoHits;
    }
}
