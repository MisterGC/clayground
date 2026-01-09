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

        // Test component from subdirectory (components/StatusBadge.qml)
        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 10

            Local.StatusBadge {
                label: "QML Component"
                success: logo.status === Image.Ready
            }

            Local.StatusBadge {
                label: "Image (subdir)"
                success: logo.status === Image.Ready
            }

            Local.StatusBadge {
                label: "Sound"
                success: testSound.loaded
            }
        }

        Button {
            text: "Play Sound"
            anchors.horizontalCenter: parent.horizontalCenter
            onClicked: testSound.play()
        }
    }
}
