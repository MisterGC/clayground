// (c) Clayground Contributors - MIT License, see "LICENSE" file

import QtQuick
import QtQuick.Window

Window {
    id: root
    visible: true
    width: 600
    height: 500
    color: "#1a1a2e"
    title: "Clayground Playground"

    // Content is loaded dynamically via C++ loadQmlFromString()
    // The loaded QML item will be parented to contentItem

    // Show a welcome message until QML is loaded
    Text {
        id: welcomeText
        anchors.centerIn: parent
        text: "Clayground Playground\n\nEdit code on the left to begin"
        color: "#8892A0"
        font.pixelSize: 18
        horizontalAlignment: Text.AlignHCenter
        lineHeight: 1.5

        // Hide when content is loaded (contentItem gets children beyond this text)
        visible: root.contentItem.children.length <= 1
    }
}
