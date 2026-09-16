// Your game starts here - index.html loads this file.
//
// The loop: edit, save, reload the page in the browser. No build step.
// Files next to Main.qml (images, sounds, more QML) are fetched from your
// site by relative path.
//
// All Clayground modules are available, e.g.:
//   import Clayground.Canvas   // 2D drawing
//   import Clayground.World    // game world + physics
//   import QtQuick3D           // 3D scenes; balsam-converted models and their
//                              // QtQuick.Timeline clips, or RuntimeLoader (QtQuick3D.AssetUtils)
// Explore live examples: https://mistergc.github.io/clayground/webdojo/

import QtQuick

Rectangle {
    id: root
    anchors.fill: parent
    color: "#1a1a2e"

    Text {
        anchors.centerIn: parent
        anchors.verticalCenterOffset: -root.height * .08
        text: "It works!"
        color: "#00d9ff"
        font.pixelSize: Math.min(root.width, root.height) * .1
        font.bold: true
    }

    Text {
        anchors.centerIn: parent
        anchors.verticalCenterOffset: root.height * .03
        text: "Your game lives in Main.qml - edit it and reload."
        color: "#8892a0"
        font.pixelSize: Math.max(14, Math.min(root.width, root.height) * .025)
    }

    // A bouncing clay ball to prove things are alive
    Rectangle {
        id: ball
        width: Math.min(root.width, root.height) * .06
        height: width
        radius: width / 2
        color: "#ff3366"
        x: root.width * .12
        SequentialAnimation on y {
            loops: Animation.Infinite
            NumberAnimation { from: root.height * .78; to: root.height * .58; duration: 450; easing.type: Easing.OutQuad }
            NumberAnimation { to: root.height * .78; duration: 450; easing.type: Easing.InQuad }
        }
    }

    Rectangle {
        width: ball.width * 1.4; height: ball.width * .18
        radius: height / 2
        color: "#000000"; opacity: .35
        x: ball.x - ball.width * .2
        y: root.height * .78 + ball.width * 1.1
    }
}
