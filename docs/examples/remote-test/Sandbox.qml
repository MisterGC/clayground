import QtQuick
import QtQuick.Controls
import Clayground.Sound
import "." as Local  // Network-transparent import requires "as" clause

Rectangle {
    anchors.fill: parent
    color: "#1a1a2e"

    // Test relative QML component import (must use namespace for remote)
    Local.ClaygroundLogo {
        id: logo
        anchors.centerIn: parent
        width: 200
        height: 200
    }

    // Test relative sound loading
    Sound {
        id: testSound
        source: "test_sound.mp3"
        onStatusChanged: console.log("Sound status:", status)
        onErrorOccurred: (msg) => console.log("Sound error:", msg)
    }

    Column {
        anchors.bottom: parent.bottom
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottomMargin: 40
        spacing: 10

        Text {
            text: "Remote Resource Test"
            color: "white"
            font.pixelSize: 24
            anchors.horizontalCenter: parent.horizontalCenter
        }

        Text {
            text: "QML Component: " + (logo.status === Image.Ready ? "✓ Loaded" : logo.status === Image.Error ? "✗ Error" : "Loading...")
            color: logo.status === Image.Ready ? "#4ade80" : logo.status === Image.Error ? "#f87171" : "#fbbf24"
            font.pixelSize: 14
            anchors.horizontalCenter: parent.horizontalCenter
        }

        Text {
            text: "Sound: " + (testSound.loaded ? "✓ Loaded" : testSound.status === Sound.Error ? "✗ Error" : "Loading...")
            color: testSound.loaded ? "#4ade80" : testSound.status === Sound.Error ? "#f87171" : "#fbbf24"
            font.pixelSize: 14
            anchors.horizontalCenter: parent.horizontalCenter
        }

        Button {
            text: "Play Sound"
            anchors.horizontalCenter: parent.horizontalCenter
            onClicked: testSound.play()
        }
    }
}
