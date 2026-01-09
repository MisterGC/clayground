import QtQuick

// Simple status badge component in subdirectory
Rectangle {
    id: root

    property string label: "Status"
    property bool success: false

    width: row.width + 20
    height: 28
    radius: 14
    color: success ? "#166534" : "#7f1d1d"

    Row {
        id: row
        anchors.centerIn: parent
        spacing: 6

        Text {
            text: success ? "✓" : "○"
            color: success ? "#4ade80" : "#fbbf24"
            font.pixelSize: 14
        }

        Text {
            text: root.label
            color: "white"
            font.pixelSize: 12
        }
    }
}
