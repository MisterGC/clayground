// (c) Clayground Contributors - MIT License, see "LICENSE" file

import QtQuick
import Clayground.World

// LightLayer2d + Light2d: wall torches with their own flicker, a lantern
// carried by the walker, and walls from the dungeon grid casting shadows.
// Keys: B bands, D dither, S shadows, R half resolution, A ambient (dungeon /
// dusk / off), P pause the walker.
Item {
    id: sbx
    anchors.fill: parent
    focus: true

    // Knobs, also for clayrender --set.
    property int bands: 0
    property real dither: 0
    property bool shadows: true
    property real resolutionScale: 1
    property int ambientMode: 0
    readonly property var ambients: ["#0b0a12", "#5a5a7a", "#ffffff"]
    readonly property var ambientNames: ["dungeon", "dusk", "off"]
    property alias walkT: dungeon.walkT
    property alias walking: dungeon.walking
    property alias lights: lighting

    DemoDungeon2d {
        id: dungeon
        anchors.fill: parent
        pixelPerUnit: Math.min(width / xWuMax, height / yWuMax)

        LightLayer2d {
            id: lighting
            world: dungeon
            ambient: sbx.ambients[sbx.ambientMode]
            bands: sbx.bands
            dither: sbx.dither
            resolutionScale: sbx.resolutionScale
        }

        Repeater {
            model: dungeon.torches
            Light2d {
                xWu: modelData.x
                yWu: modelData.y
                radius: 11
                color: modelData.color
                intensity: 1.1
                flicker: 0.5
                castsShadows: sbx.shadows
            }
        }

        Component.onCompleted: lighting.setOccluderGrid(
            dungeon.cols, dungeon.rows, dungeon.cellSize,
            (cx, cy) => dungeon.isWall(cx, cy))
    }

    // The walker's lantern, declared inside the walker so it follows it.
    Light2d {
        parent: dungeon.walker
        radius: 9
        color: "#fff0d0"
        intensity: 0.9
        flicker: 0.15
        castsShadows: sbx.shadows
    }

    Text {
        anchors.left: parent.left
        anchors.bottom: parent.bottom
        anchors.margins: 12
        z: 1000
        color: "#e8e0d0"
        font.family: "Monospace"
        font.pixelSize: 14
        style: Text.Outline
        styleColor: "#000000"
        text: "lights " + lighting.lightCount
              + "  [A]mbient " + sbx.ambientNames[sbx.ambientMode]
              + "  [B]ands " + sbx.bands
              + "  [D]ither " + sbx.dither
              + "  [S]hadows " + sbx.shadows
              + "  [R]es " + sbx.resolutionScale
    }

    Keys.onPressed: (event) => {
        if (event.key === Qt.Key_B) bands = bands === 0 ? 4 : (bands === 4 ? 6 : 0);
        else if (event.key === Qt.Key_D) dither = dither > 0 ? 0 : 1;
        else if (event.key === Qt.Key_S) shadows = !shadows;
        else if (event.key === Qt.Key_R) resolutionScale = resolutionScale < 1 ? 1 : 0.5;
        else if (event.key === Qt.Key_A) ambientMode = (ambientMode + 1) % ambients.length;
        else if (event.key === Qt.Key_P) walking = !walking;
    }
}
