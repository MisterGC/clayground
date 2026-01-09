// Remote QML App Reference
// -------------------------
// Self-contained apps can be hosted in any repo and run via Web Dojo's #url-demo mode.
//
// Requirements for remote loading:
// 1. qmldir file listing your types: "TypeName 1.0 path/to/File.qml"
// 2. Import with "as" clause: import "." as Local (required for network transparency)
// 3. Qualify types with namespace: Local.MyComponent { }
// 4. Assets (images, sounds) resolve relatively - no qmldir entry needed
//
// Run via: https://mistergc.github.io/clayground/webdojo/#url-demo=<raw-github-url>

import QtQuick
import QtQuick.Controls
import Clayground.Sound
import "." as Local

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
