// (c) Clayground Contributors - MIT License, see "LICENSE" file

import QtQuick
import QtQuick.Controls

Rectangle {
    id: root
    color: "#CC1a1a2e"
    visible: false

    property string screenshotSource: ""

    signal confirmed(string annotation)
    signal cancelled()

    function activate(screenshotPath) {
        screenshotSource = "file://" + screenshotPath;
        annotationInput.text = "";
        visible = true;
        annotationInput.forceActiveFocus();
    }

    function deactivate() {
        visible = false;
        screenshotSource = "";
        annotationInput.text = "";
    }

    // Screenshot background
    Image {
        id: screenshot
        anchors.centerIn: parent
        width: Math.min(parent.width * 0.92, sourceSize.width)
        height: Math.min(parent.height * 0.92, sourceSize.height)
        fillMode: Image.PreserveAspectFit
        source: root.screenshotSource
        opacity: 0.6
    }

    // Viewfinder corner brackets
    Item {
        id: viewfinder
        anchors.fill: screenshot
        readonly property int len: Math.min(width, height) * 0.06
        readonly property int thick: 3
        readonly property color col: "#ffffff"

        // Top-left
        Rectangle { width: viewfinder.len; height: viewfinder.thick; color: viewfinder.col; anchors.top: parent.top; anchors.left: parent.left }
        Rectangle { width: viewfinder.thick; height: viewfinder.len; color: viewfinder.col; anchors.top: parent.top; anchors.left: parent.left }
        // Top-right
        Rectangle { width: viewfinder.len; height: viewfinder.thick; color: viewfinder.col; anchors.top: parent.top; anchors.right: parent.right }
        Rectangle { width: viewfinder.thick; height: viewfinder.len; color: viewfinder.col; anchors.top: parent.top; anchors.right: parent.right }
        // Bottom-left
        Rectangle { width: viewfinder.len; height: viewfinder.thick; color: viewfinder.col; anchors.bottom: parent.bottom; anchors.left: parent.left }
        Rectangle { width: viewfinder.thick; height: viewfinder.len; color: viewfinder.col; anchors.bottom: parent.bottom; anchors.left: parent.left }
        // Bottom-right
        Rectangle { width: viewfinder.len; height: viewfinder.thick; color: viewfinder.col; anchors.bottom: parent.bottom; anchors.right: parent.right }
        Rectangle { width: viewfinder.thick; height: viewfinder.len; color: viewfinder.col; anchors.bottom: parent.bottom; anchors.right: parent.right }
    }

    // Annotation text area
    ScrollView {
        id: annotationScroll
        anchors {
            top: screenshot.top
            left: screenshot.left
            right: screenshot.right
            bottom: hintRow.top
            margins: screenshot.width * 0.05
        }

        TextArea {
            id: annotationInput
            wrapMode: TextEdit.Wrap
            color: "#e0e0e0"
            font.family: "monospace"
            font.pixelSize: Math.max(14, screenshot.height * 0.05)
            placeholderText: "Describe what you see ..."
            placeholderTextColor: "#666666"
            background: Rectangle { color: "transparent" }

            Keys.onReturnPressed: function(event) {
                if (event.modifiers & Qt.ShiftModifier)
                    annotationInput.insert(annotationInput.cursorPosition, "\n");
                else
                    root.confirmed(annotationInput.text);
            }
            Keys.onEscapePressed: root.cancelled()
        }
    }

    // Hint row
    Row {
        id: hintRow
        anchors.horizontalCenter: screenshot.horizontalCenter
        anchors.bottom: screenshot.bottom
        anchors.bottomMargin: screenshot.height * 0.04
        spacing: 20

        Text {
            color: "#999999"
            font.family: "monospace"
            font.pixelSize: Math.max(11, screenshot.height * 0.028)
            text: "Return to confirm, Esc to cancel"
        }
    }
}
