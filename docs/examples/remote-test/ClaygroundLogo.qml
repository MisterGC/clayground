import QtQuick

// Simple component that loads a relative image from subdirectory
Image {
    id: root
    source: "images/clayground_logo.png"
    fillMode: Image.PreserveAspectFit

    // Visual feedback if image fails to load
    Rectangle {
        anchors.fill: parent
        color: "#ff6b6b"
        visible: parent.status === Image.Error

        Text {
            anchors.centerIn: parent
            text: "Image failed to load"
            color: "white"
        }
    }
}
