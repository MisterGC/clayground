// (c) Clayground Contributors - MIT License, see "LICENSE" file

import QtQuick
import QtQuick.Controls

Rectangle {
    id: root
    anchors.fill: parent
    color: "#1a1a2e"

    property color accentColor: "#0f9d9a"
    property color surfaceColor: "#16213e"
    property color textColor: "#eaeaea"
    property color dimTextColor: "#8a8a8a"
    property string monoFont: Qt.platform.os === "osx" ? "Menlo" :
                              Qt.platform.os === "windows" ? "Consolas" : "monospace"

    property var effectComponent: null
    property var effectInstance: null
    onEffectComponentChanged: createEffect()

    Component {
        id: explosionComp
        ExplosionFx {
            numParts: 150
            width: root.width * .5
            height: width
            anchors.centerIn: parent
        }
    }

    Component {
        id: absorptionComp
        AbsorptionFx {
            id: aFx
            Component.onCompleted: destruct.start()
            msFromBoundaryToCenter: 800
            particlesPerSecond: 250
            width: root.width * .8
            height: width
            anchors.centerIn: parent
            Timer { id: destruct; interval: 2000; onTriggered: aFx.destroy() }
        }
    }

    function createEffect() {
        effectInstance = effectComponent.createObject(root);
    }

    Text {
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.margins: 15
        text: "Visual FX"
        font.family: root.monoFont
        font.pixelSize: 18
        font.bold: true
        color: root.accentColor
    }

    Row {
        anchors.bottom: parent.bottom
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottomMargin: 20
        spacing: 10

        Button {
            text: "Explosion"
            onClicked: effectComponent = explosionComp
            background: Rectangle {
                color: parent.pressed ? Qt.darker(root.accentColor, 1.2) : root.accentColor
                radius: 4
            }
            contentItem: Text {
                text: parent.text
                font.family: root.monoFont
                color: "white"
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
            }
        }

        Button {
            text: "Absorption"
            onClicked: effectComponent = absorptionComp
            background: Rectangle {
                color: parent.pressed ? Qt.darker(root.accentColor, 1.2) : root.accentColor
                radius: 4
            }
            contentItem: Text {
                text: parent.text
                font.family: root.monoFont
                color: "white"
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
            }
        }
    }
}
